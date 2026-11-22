library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dotenv/dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:postgres/postgres.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:image/image.dart' as image;
import 'package:aws_common/aws_common.dart';
import 'package:aws_signature_v4/aws_signature_v4.dart';
part 'auth.dart';
part 'feed.dart';
part 'workspace.dart';
part 'administration.dart';
part 'media.dart';

typedef Row = Map<String, dynamic>;
typedef Config = Map<String, String>;
Config configuration() {
  final f = Platform.environment['SSITE_CONFIG_FILE'] ?? '.env';
  final parsed = DotEnv(includePlatformEnvironment: false);
  if (File(f).existsSync()) parsed.load([f]);
  return {
    for (final line
        in File(f).existsSync() ? File(f).readAsLinesSync() : <String>[])
      if (RegExp(r'^([A-Z_][A-Z0-9_]*)=').firstMatch(line) case final match?)
        match[1]!: parsed[match[1]!] ?? '',
    ...Platform.environment,
  };
}

Pool database(Config cfg) => Pool.withEndpoints(
  [
    Endpoint(
      host: cfg['DB_HOST']!,
      port: int.parse(cfg['DB_PORT'] ?? '5432'),
      database: cfg['DB_DATABASE']!,
      username: cfg['DB_USERNAME'],
      password: cfg['DB_PASSWORD'],
    ),
  ],
  settings: PoolSettings(
    maxConnectionCount: 6,
    sslMode: switch (cfg['DB_SSLMODE']) {
      'disable' => SslMode.disable,
      'require' => SslMode.require,
      _ => SslMode.verifyFull,
    },
    connectTimeout: const Duration(seconds: 12),
  ),
);

class Problem implements Exception {
  final int status;
  final String message;
  Problem(this.status, this.message);
}

void require(bool ok, int code, String message) {
  if (!ok) throw Problem(code, message);
}

String token([int n = 32]) => List.generate(
  n,
  (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();
String digest(String s) => sha256.convert(utf8.encode(s)).toString();
Future<List<Row>> rows(
  Session db,
  String sql, [
  List<dynamic> args = const [],
]) async => (await db.execute(
  Sql.indexed(sql, substitution: '?'),
  parameters: args,
)).map((r) => r.toColumnMap()).toList();
Future<Row?> one(
  Session db,
  String sql, [
  List<dynamic> args = const [],
]) async => (await rows(db, sql, args)).firstOrNull;
String encode(Object? value) => jsonEncode(
  value,
  toEncodable: (v) => v is DateTime ? v.toIso8601String() : v.toString(),
);
String str(Row b, String k, int max, {bool required = false}) {
  final v = b[k];
  require(v == null || v is String, 422, 'Invalid $k.');
  final text = (v ?? '').toString().trim();
  require(
    (!required || text.isNotEmpty) && text.length <= max,
    422,
    'Check $k.',
  );
  return text;
}

const modules = {
  'articles': ['article', 'content', 'category'],
  'activities': [
    'activity',
    'description',
    'category',
    'activity_date',
    'location',
  ],
  'achievements': [
    'achievement',
    'description',
    'category',
    'achievement_date',
    'awardee',
  ],
  'documents': [
    'document',
    'description',
    'category',
    'academic_year',
    'semester',
  ],
  'liquidations': [
    'liquidation',
    'description',
    'amount',
    'report_date',
    'semester',
  ],
};
const positions = {
  'President': [
    'articles',
    'activities',
    'achievements',
    'documents',
    'liquidations',
  ],
  'Secretary': ['documents'],
  'Auditor': ['liquidations'],
  'Social Media Manager': ['articles', 'activities', 'achievements'],
};
List<String> allowed(Row u) => u['role'] == 'officer'
    ? positions.entries
              .where(
                (e) =>
                    e.key.toLowerCase() ==
                    u['officer_position'].toString().trim().toLowerCase(),
              )
              .firstOrNull
              ?.value ??
          []
    : [];
bool president(Row u) =>
    u['role'] == 'officer' &&
    u['officer_position'].toString().trim().toLowerCase() == 'president';
bool staff(Row u) =>
    allowed(u).isNotEmpty || ['adviser', 'admin'].contains(u['role']);
void module(String m) =>
    require(modules.containsKey(m), 404, 'Unknown module.');
bool pdf(String m) => m == 'documents' || m == 'liquidations';
bool editable(Row u, String m, Row p) =>
    allowed(u).contains(m) &&
    (president(u) || p['created_by_user_id'] == u['id']);
bool live(Row p) =>
    p['content_status'] == 'active' && p['approval_status'] == 'approved';
bool yearOK(String v) =>
    RegExp(r'^\d{4}-\d{4}$').hasMatch(v) &&
    int.parse(v.substring(5)) == int.parse(v.substring(0, 4)) + 1;
Row item(String title, String path, {String? detail}) => {
  'title': title,
  'path': path,
  'detail': ?detail,
};
Row input(
  String key, [
  dynamic value,
  String type = 'text',
  List<String>? choices,
]) => {
  'key': key,
  'value': type == 'date' && value is DateTime
      ? value.toIso8601String().substring(0, 10)
      : value?.toString() ?? '',
  'type': type,
  'choices': ?choices,
};
Row action(String title, String path, [List<Row> fields = const []]) => {
  'title': title,
  'submit': path,
  'fields': fields,
};
Row screen(String title, List<Row> items) => {'title': title, 'items': items};

class MobileServer {
  final Config cfg;
  final Session db;
  MobileServer(this.cfg, this.db);
  String get origin =>
      Uri.parse(cfg['MOBILE_ORIGIN'] ?? 'http://localhost:8001').origin;
  String get api => '/api/mobile/v1';
  final _limits = <String, (int, int)>{};
  bool limited(String key, int max) {
    final minute = DateTime.now().millisecondsSinceEpoch ~/ 60000;
    _limits.removeWhere((_, v) => v.$1 != minute);
    final count = (_limits[key]?.$2 ?? 0) + 1;
    _limits[key] = (minute, count);
    return count > max;
  }

  Future<String> issue(String kind, Row data, int seconds) async {
    final t = token();
    await rows(
      db,
      'insert into cache(key,value,expiration) values(?1,?2,extract(epoch from now())::bigint+?3)',
      ['ssiteapp:$kind:${digest(t)}', encode(data), seconds],
    );
    return t;
  }

  Future<Row?> lookup(String kind, String? t, {bool consume = false}) async {
    if (t == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch(t)) return null;
    const where = ' where key=?1 and expiration>extract(epoch from now())';
    final r = await one(
      db,
      consume
          ? 'delete from cache$where returning value'
          : 'select value from cache$where',
      ['ssiteapp:$kind:${digest(t)}'],
    );
    return r == null ? null : jsonDecode(r['value']) as Row;
  }

  Future<void> handle(HttpRequest req) async {
    final res = req.response;
    res.headers.set('Cache-Control', 'private, no-store');
    res.headers.set('Referrer-Policy', 'no-referrer');
    res.headers.set('X-Content-Type-Options', 'nosniff');
    try {
      final originHeader = req.headers.value('origin');
      if (originHeader != null &&
          (cfg['SSITE_WEB_ORIGINS'] ?? '')
              .split(',')
              .map((s) => s.trim())
              .contains(originHeader)) {
        res.headers.set('Access-Control-Allow-Origin', originHeader);
        res.headers.set('Vary', 'Origin');
        res.headers.set(
          'Access-Control-Allow-Headers',
          'Authorization, Content-Type',
        );
        res.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
        if (req.method == 'OPTIONS') {
          res.statusCode = 204;
          return;
        }
      }
      final path = req.uri.path;
      if (req.method == 'GET' && path.startsWith('$api/photos/')) {
        final key = path.substring('$api/photos/'.length);
        require(
          RegExp(
            r'^(profile-pictures|officer-photos|sponsor-logos)/[A-Za-z0-9_-]+\.(png|jpe?g|webp)$',
            caseSensitive: false,
          ).hasMatch(key),
          404,
          'Unknown photo.',
        );
        await serveObject(req, 'public', key);
        return;
      }
      if (path == '/up') {
        await db.execute('select 1');
        json(res, {'service': 'ssiteapp-dart', 'status': 'ok'});
        return;
      }
      if (path.startsWith('/auth/microsoft/')) {
        await microsoft(req);
        return;
      }
      if (path == '/policies') {
        res.headers.contentType = ContentType.text;
        res.write(policyText);
        return;
      }
      require(path.startsWith('$api/'), 404, 'Unknown endpoint.');
      final parts = path.substring(api.length + 1).split('/'),
          q = req.uri.queryParameters;
      final post = req.method == 'POST';
      require(post || req.method == 'GET', 405, 'Unsupported method.');
      if (post)
        require(
          !limited('${req.connectionInfo?.remoteAddress.address}:write', 120),
          429,
          'Try again in a minute.',
        );
      Row b = {};
      if (post) {
        final bytes = BytesBuilder(copy: false);
        await for (final chunk in req) {
          require(
            bytes.length + chunk.length <= 15 * 1024 * 1024,
            413,
            'Attachment too large.',
          );
          bytes.add(chunk);
        }
        if (bytes.length > 0) {
          final decoded = jsonDecode(utf8.decode(bytes.takeBytes()));
          require(
            decoded is Map<String, dynamic>,
            400,
            'Expected a JSON object.',
          );
          b = decoded;
        }
      }
      if (parts.join('/') == 'auth/exchange' && post) {
        final flow = await lookup('code', b['code'], consume: true);
        require(
          flow != null &&
              digest(str(b, 'code_verifier', 64)) == flow['challenge'],
          401,
          'Expired sign-in.',
        );
        json(res, {
          'token': await issue('access', flow!['identity'], 30 * 86400),
        });
        return;
      }
      final bearer = req.headers
          .value('authorization')
          ?.replaceFirst(RegExp(r'^Bearer '), '');
      final session = await lookup('access', bearer);
      require(session != null, 401, 'Please sign in.');
      if (parts.join('/') == 'auth/logout' && post) {
        await lookup('access', bearer, consume: true);
        json(res, {'ok': true});
        return;
      }
      var u = await one(
        db,
        'select id,name,email,role,officer_position,profile_picture,profile_completed_at from users where microsoft_id=?1',
        [session!['mid']],
      );
      if (parts.join('/') == 'auth/me' && !post) {
        json(res, {
          'user': {
            ...?(u == null
                ? null
                : {
                    'name': u['name'],
                    'email': u['email'],
                    'role': u['role'],
                    'position': u['officer_position'],
                    'avatar_url': photo(u['profile_picture']),
                    'can_access_workspace': staff(u),
                  }),
            'profile_complete': u?['profile_completed_at'] != null,
          },
        });
        return;
      }
      if (parts.join('/') == 'profile/complete' && post) {
        await completeProfile(session, b);
        json(res, {'ok': true});
        return;
      }
      require(
        u?['profile_completed_at'] != null,
        403,
        'Complete your profile.',
      );
      if (parts.first == 'tools') {
        json(res, await toolsPage(u!, parts.skip(1).toList(), b, post, q));
        return;
      }
      await feed(req, parts, u!, post, b);
    } on Problem catch (e) {
      res.statusCode = e.status;
      json(res, {'message': e.message});
    } on FormatException {
      res.statusCode = 400;
      json(res, {'message': 'Invalid input.'});
    } on ServerException catch (e) {
      final conflict = ['23505', '40001', '40P01'].contains(e.code);
      res.statusCode = conflict ? 409 : 500;
      stderr.writeln('Database request failed (${e.code})');
      json(res, {
        'message': conflict
            ? 'Record changed. Refresh and try again.'
            : 'Database request failed.',
      });
    } catch (e) {
      stderr.writeln('Request failed (${e.runtimeType})');
      res.statusCode = 500;
      json(res, {'message': 'Request could not be completed.'});
    } finally {
      try {
        await res.close();
      } on SocketException {
        /* Client disconnected. */
      }
    }
  }

  void json(HttpResponse res, Object? data) {
    res.headers.contentType = ContentType.json;
    res.write(encode(data));
  }
}
