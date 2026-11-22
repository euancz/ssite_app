part of 'server.dart';

const policyText =
    'SSITE provides organization updates, activities and resources for the MCC community. Use materials for their intended school purposes and respect authorship and document restrictions. Publishing and administrative tools are limited to assigned roles. Keep your account secure and sign out on shared devices.\n\nSSITE uses your name, school email and Microsoft identifier to identify you. Microsoft handles your password. SSITE creates your account and saves your photo after you accept the terms and privacy policy. You can manage your photo in profile settings. Contact ssite@gmail.com about content, account access, corrections or removal.';

extension Auth on MobileServer {
  Future<void> microsoft(HttpRequest req) async {
    require(req.method == 'GET', 405, 'Unsupported method.');
    require(
      !limited('auth:${req.connectionInfo?.remoteAddress.address}', 30),
      429,
      'Try again in a minute.',
    );
    final q = req.uri.queryParameters,
        res = req.response,
        callback = '$origin/auth/microsoft/callback';
    final provider =
        'https://login.microsoftonline.com/${Uri.encodeComponent(cfg['MICROSOFT_TENANT_ID'] ?? 'organizations')}/oauth2/v2.0';
    if (req.uri.path == '/auth/microsoft/mobile') {
      final challenge = q['code_challenge'] ?? '';
      require(
        RegExp(r'^[a-f0-9]{64}$').hasMatch(challenge),
        400,
        'Invalid app challenge.',
      );
      final back = q['return_url'];
      if (back != null) {
        final uri = Uri.parse(back);
        require(
          uri.hasAuthority &&
              uri.userInfo.isEmpty &&
              (cfg['SSITE_WEB_ORIGINS'] ?? '')
                  .split(',')
                  .map((s) => s.trim())
                  .contains(uri.origin),
          400,
          'Unknown app origin.',
        );
      }
      final state = await issue('oauth', {
        'challenge': challenge,
        'back': back,
      }, 600);
      res.cookies.add(
        Cookie('ssite_mobile_oauth', state)
          ..path = '/auth/microsoft'
          ..secure = origin.startsWith('https:')
          ..httpOnly = true
          ..sameSite = SameSite.lax
          ..maxAge = 600,
      );
      res.statusCode = 302;
      res.headers.set(
        'location',
        Uri.parse('$provider/authorize')
            .replace(
              queryParameters: {
                'client_id': cfg['MICROSOFT_CLIENT_ID']!,
                'response_type': 'code',
                'redirect_uri': callback,
                'scope': 'User.Read',
                'state': state,
              },
            )
            .toString(),
      );
      return;
    }
    require(req.uri.path == '/auth/microsoft/callback', 404, 'Unknown route.');
    final state = q['state'];
    require(
      state != null &&
          req.cookies.any(
            (c) => c.name == 'ssite_mobile_oauth' && c.value == state,
          ),
      403,
      'Restart sign-in.',
    );
    final flow = await lookup('oauth', state, consume: true);
    require(
      flow != null && q['code'] != null,
      401,
      'Sign-in expired or cancelled.',
    );
    final r = await http
        .post(
          Uri.parse('$provider/token'),
          body: {
            'client_id': cfg['MICROSOFT_CLIENT_ID']!,
            'client_secret': cfg['MICROSOFT_CLIENT_SECRET']!,
            'code': q['code']!,
            'redirect_uri': callback,
            'grant_type': 'authorization_code',
          },
        )
        .timeout(const Duration(seconds: 20));
    require(r.statusCode == 200, 401, 'Microsoft sign-in failed.');
    final graph = await http
        .get(
          Uri.https('graph.microsoft.com', '/v1.0/me'),
          headers: {
            'Authorization': 'Bearer ${jsonDecode(r.body)['access_token']}',
          },
        )
        .timeout(const Duration(seconds: 20));
    require(graph.statusCode == 200, 401, 'Microsoft identity unavailable.');
    final p = jsonDecode(graph.body),
        mid = p['id'] as String,
        email = (p['mail'] ?? p['userPrincipalName'] ?? '')
            .toString()
            .toLowerCase();
    final domain = cfg['SCHOOL_MICROSOFT_EMAIL_DOMAIN'] ?? 'mcc.edu.ph';
    require(
      email.split('@').length == 2 &&
          (domain.isEmpty || email.split('@').last == domain.toLowerCase()),
      403,
      'Use your school Microsoft account.',
    );
    await tx((s) async {
      final existing = await rows(
        s,
        'select id,microsoft_id,profile_completed_at from users where microsoft_id=?1 or lower(email)=?2 order by id for update',
        [mid, email],
      );
      require(
        existing.length <= 1 &&
            (existing.firstOrNull?['microsoft_id'] == null ||
                existing.first['microsoft_id'] == mid),
        403,
        'This account is linked to another identity.',
      );
      if (existing.firstOrNull?['profile_completed_at'] != null)
        await rows(
          s,
          'update users set microsoft_id=?1 where id=?2 and microsoft_id is null',
          [mid, existing.first['id']],
        );
    });
    final code = await issue('code', {
      'challenge': flow!['challenge'],
      'identity': {
        'mid': mid,
        'email': email,
        'name': p['displayName'] ?? 'Member',
      },
    }, 90);
    res.statusCode = 302;
    res.headers.set(
      'location',
      flow['back'] == null
          ? 'ssiteapp://auth/callback?code=$code'
          : Uri.parse(
              flow['back'],
            ).replace(fragment: 'ssite_code=$code').toString(),
    );
  }

  Future<void> completeProfile(Row identity, Row b) async {
    require(b['accept'] == true, 422, 'Accept the terms and privacy policy.');
    final f = await storeUpload(b, 'profile-pictures', 'public');
    try {
      await tx((s) async {
        final p = await rows(
          s,
          'select id,microsoft_id,profile_completed_at from users where microsoft_id=?1 or lower(email)=?2 order by id for update',
          [identity['mid'], identity['email']],
        );
        require(
          p.length <= 1 &&
              (p.firstOrNull?['microsoft_id'] == null ||
                  p.first['microsoft_id'] == identity['mid']),
          403,
          'Identity mismatch.',
        );
        require(
          p.firstOrNull?['profile_completed_at'] == null,
          409,
          'Profile already complete.',
        );
        if (p.isEmpty) {
          await rows(
            s,
            "insert into users(microsoft_id,email,name,password,role,profile_picture,profile_completed_at,profile_policies_accepted_at,created_at,updated_at) values(?1,?2,?3,?4,'student',?5,now(),now(),now(),now())",
            [
              identity['mid'],
              identity['email'],
              identity['name'],
              digest(token()),
              f['path'],
            ],
          );
        } else {
          await rows(
            s,
            'update users set microsoft_id=?1,profile_picture=?2,profile_completed_at=now(),profile_policies_accepted_at=now(),updated_at=now() where id=?3',
            [identity['mid'], f['path'], p.first['id']],
          );
        }
      });
    } catch (_) {
      await object('DELETE', 'public', f['path']);
      rethrow;
    }
  }
}
