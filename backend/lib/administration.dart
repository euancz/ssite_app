part of 'server.dart';

const rosterTitles = [
  'Adviser',
  'Student Adviser',
  'President',
  'Vice President (Internal)',
  'Vice President (External)',
  'Secretary',
  'Treasurer',
  'Auditor',
  'Public Information Officer',
  'Business Manager',
  'Social Media Manager',
  'Social Media Manager (Creative)',
  'Social Media Manager (Documentation)',
  'IT Representative I',
  'IT Representative II',
];
List<String> roles(Row u, Row t) {
  if (u['id'] == t['id'] || t['role'] == 'admin') return [];
  if (u['role'] == 'adviser' && ['officer', 'student'].contains(t['role']))
    return ['student', 'officer'];
  if (u['role'] == 'admin')
    return t['role'] == 'adviser' ? ['student'] : ['adviser'];
  return [];
}

extension Administration on MobileServer {
  Future<Row> adminPage(
    Row u,
    List<String> path,
    Row b,
    bool post,
    Map<String, String> q,
  ) async {
    final k = path.first, op = path.last;
    if (k == 'post' && !post && path.length == 3) {
      final m = path[1];
      module(m);
      final id = int.tryParse(path[2]) ?? -1;
      final p = await one(db, 'select * from $m where id=?1', [id]);
      require(
        p != null && (live(p) || editable(u, m, p)),
        404,
        'Post unavailable.',
      );
      return screen(p!['title'], [
        {'title': p['approval_status'], 'detail': p[modules[m]![1]] ?? ''},
        if (p[pdf(m) ? 'file_path' : 'image'] != null)
          {
            'title': 'Open attachment',
            'file': '$api/attachment/$m/$id',
            'pdf': pdf(m),
          },
        if (editable(u, m, p)) item('Manage post', 'content/$m/$id'),
      ]);
    }
    if (k == 'profile') {
      if (!post)
        return screen('Profile', [
          {
            'title': u['name'],
            'detail': '${u['email']}\n${u['role']}',
            'image': photo(u['profile_picture']),
          },
          action('Update profile picture', 'profile/photo', [
            input('attachment', null, 'image'),
          ]),
          if (u['profile_picture'] != null)
            action('Remove profile picture', 'profile/remove'),
        ]);
      require(['photo', 'remove'].contains(op), 404, 'Unknown profile action.');
      final f = op == 'photo'
          ? await storeUpload(b, 'profile-pictures', 'public')
          : null;
      final String? old;
      try {
        old = await tx((s) async {
          final previous = await one(
            s,
            'select profile_picture from users where id=?1 for update',
            [u['id']],
          );
          await rows(
            s,
            'update users set profile_picture=?1,updated_at=now() where id=?2',
            [f?['path'], u['id']],
          );
          return previous?['profile_picture'] as String?;
        });
      } catch (_) {
        if (f != null) await object('DELETE', 'public', f['path']);
        rethrow;
      }
      await retirePublicPhoto('profile-pictures', old);
      return {'back': 'profile'};
    }
    if (k == 'notifications') {
      const scope = 'notifiable_type=?1 and notifiable_id=?2';
      final args = [r'App\Models\User', u['id']];
      if (!post) {
        final list = await rows(
          db,
          'select id,data,read_at from notifications where $scope order by created_at desc',
          args,
        );
        Row notice(Row n) {
          final d = jsonDecode(n['data']) as Row;
          final m = modules.entries
              .where((e) => e.value.first == d['post_type'])
              .firstOrNull
              ?.key;
          return {
            'title': d['message'] ?? 'Notification',
            'detail': d['title'] ?? '',
            if (m != null && d['post_id'] != null)
              'path': 'post/$m/${d['post_id']}',
          };
        }

        return screen('Notifications', [
          if (list.any((r) => r['read_at'] == null))
            action('Mark all as read', 'notifications/read-all'),
          for (final n in list) ...[
            notice(n),
            if (n['read_at'] == null)
              action('Mark read', 'notifications/${n['id']}/read'),
            action('Delete notification', 'notifications/${n['id']}/delete'),
          ],
        ]);
      }
      if (op == 'read-all') {
        await rows(
          db,
          'update notifications set read_at=now(),updated_at=now() where read_at is null and $scope',
          args,
        );
      } else {
        require(
          path.length == 3 && ['read', 'delete'].contains(op),
          404,
          'Unknown action.',
        );
        final sql = op == 'read'
            ? 'update notifications set read_at=now(),updated_at=now()'
            : 'delete from notifications';
        await rows(db, '$sql where $scope and id=?3', [...args, path[1]]);
      }
      return {'back': 'notifications'};
    }
    if (k == 'users') {
      require(['adviser', 'admin'].contains(u['role']), 403, 'No access.');
      if (path.length == 1 && !post) {
        final list = await rows(
          db,
          "select id,name,email,role from users where id<>?2 and role=any(?3::text[]) and concat_ws(' ',name,email,role) ilike ?1 order by name,id",
          [
            '%${q['q'] ?? ''}%',
            u['id'],
            u['role'] == 'admin'
                ? ['student', 'officer', 'adviser']
                : ['student', 'officer'],
          ],
        );
        return screen('User accounts', [
          for (final t in list)
            item(
              t['name'],
              'users/${t['id']}',
              detail: '${t['email']} · ${t['role']}',
            ),
        ]);
      }
      final id = int.parse(path[1]);
      if (!post) {
        final t = await one(
          db,
          'select id,name,email,role,officer_position from users where id=?1',
          [id],
        );
        require(t != null, 404, 'User unavailable.');
        final choices = roles(u, t!);
        require(choices.isNotEmpty, 403, 'Account details unavailable.');
        return screen(t['name'], [
          {
            'title': t['email'],
            'detail': '${t['role']} · ${t['officer_position'] ?? ''}',
          },
          if (choices.isNotEmpty)
            action('Update role', 'users/$id', [
              input(
                'role',
                choices.contains(t['role']) ? t['role'] : choices.first,
                'select',
                choices,
              ),
              if (choices.contains('officer'))
                input('position', t['officer_position'], 'select', [
                  '',
                  ...positions.keys,
                ]),
            ]),
        ]);
      }
      await tx((s) async {
        final all = await rows(
          s,
          'select id,role,officer_position from users order by id for update',
        );
        final actor = all.firstWhere((v) => v['id'] == u['id']),
            t = all.where((v) => v['id'] == id).firstOrNull;
        final role = b['role'],
            position = role == 'officer' ? b['position'] : null;
        require(
          t != null && roles(actor, t).contains(role),
          403,
          'Role change unavailable.',
        );
        require(
          role != 'officer' || positions.containsKey(position),
          422,
          'Choose an officer position.',
        );
        if (position == 'President')
          require(
            !all.any((v) => v['id'] != id && president(v)),
            409,
            'President already assigned.',
          );
        await rows(
          s,
          'update users set role=?1,officer_position=?2,updated_at=now() where id=?3',
          [role, position, id],
        );
        await rows(
          s,
          'insert into role_changes(user_id,changed_by_user_id,old_role,new_role,old_officer_position,new_officer_position,created_at,updated_at) values(?1,?2,?3,?4,?5,?6,now(),now())',
          [id, u['id'], t!['role'], role, t['officer_position'], position],
        );
      });
      return {'back': 'users'};
    }
    require(['roster', 'sponsors'].contains(k), 404, 'Unknown page.');
    require(president(u), 403, 'President required.');
    final roster = k == 'roster',
        table = roster ? 'officer_terms' : 'sponsors',
        title = roster ? 'Officer roster' : 'Sponsors';
    if (!post && path.length == 1) {
      final list = await rows(
        db,
        'select * from $table order by ${roster ? 'academic_year desc,' : ''}sort_order,name',
      );
      return screen(title, [
        item('Add entry', '$k/new'),
        if (roster)
          action('Copy previous year', 'roster/copy', [
            input('academic_year', currentYear),
          ]),
        for (final r in list)
          item(
            r['name'],
            '$k/${r['id']}',
            detail: roster
                ? '${r['position']} · ${r['academic_year']}'
                : r['description'],
          ),
      ]);
    }
    if (roster && post && op == 'copy') {
      final year = str(b, 'academic_year', 9, required: true);
      require(yearOK(year), 422, 'Invalid academic year.');
      final y = int.parse(year.substring(0, 4));
      await tx((s) async {
        require(president(await lockedUser(s, u)), 403, 'President required.');
        await s.execute('lock table officer_terms in share row exclusive mode');
        await rows(
          s,
          'insert into officer_terms(academic_year,name,position,user_id,photo,sort_order,created_at,updated_at) select ?1,x.name,x.position,x.user_id,x.photo,x.sort_order,now(),now() from officer_terms x where x.academic_year=?2 and not exists(select 1 from officer_terms t where t.academic_year=?1 and (t.user_id=x.user_id or (x.user_id is null and t.user_id is null and t.name=x.name and t.position=x.position)))',
          [year, '${y - 1}-$y'],
        );
      });
      return {'back': k};
    }
    final id = path[1] == 'new' ? null : int.parse(path[1]);
    final r = id == null
        ? <String, dynamic>{}
        : await one(db, 'select * from $table where id=?1', [id]);
    require(r != null, 404, 'Record unavailable.');
    if (!post) {
      return screen(r!['name'] ?? 'Add entry', [
        action('Save', '$k/${id ?? 'new'}', [
          input('name', r['name']),
          if (roster) ...[
            input(
              'position',
              r['position'] ?? rosterTitles.first,
              'select',
              rosterTitles,
            ),
            input('academic_year', r['academic_year'] ?? currentYear),
            input('user_id', r['user_id'], 'select', [
              '',
              for (final user in await rows(
                db,
                "select id,name,email from users where role in ('student','officer') order by name",
              ))
                '${user['id']}|${user['name']} · ${user['email']}',
            ]),
          ] else ...[
            input('description', r['description'], 'long'),
            input('website_url', r['website_url']),
            input('is_active', r['is_active'] ?? true, 'select', [
              'true',
              'false',
            ]),
          ],
          if (!roster && r['logo_path'] != null)
            input('remove_logo', false, 'check'),
          input('sort_order', r['sort_order'] ?? 0),
          input('attachment', null, 'image'),
        ]),
        if (id != null) action('Delete entry', '$k/$id/delete'),
      ]);
    }
    Row? uploaded;
    String? priorPhoto;
    try {
      await tx((s) async {
        require(president(await lockedUser(s, u)), 403, 'President required.');
        final current = id == null
            ? null
            : await one(s, 'select * from $table where id=?1 for update', [id]);
        require(id == null || current != null, 404, 'Entry unavailable.');
        final photoKey = roster ? 'photo' : 'logo_path';
        priorPhoto = current?[photoKey] as String?;
        if (op == 'delete') {
          await rows(s, 'delete from $table where id=?1', [id]);
          return;
        }
        final v = <String, dynamic>{
          'name': str(b, 'name', roster ? 100 : 255, required: true),
          'sort_order': int.tryParse(str(b, 'sort_order', 6)),
        };
        require(
          v['sort_order'] is int &&
              v['sort_order'] >= 0 &&
              v['sort_order'] <= (roster ? 255 : 65535),
          422,
          'Invalid sort order.',
        );
        if (roster) {
          final year = str(b, 'academic_year', 9), position = b['position'];
          require(
            yearOK(year) && rosterTitles.contains(position),
            422,
            'Check position and academic year.',
          );
          final member = str(b, 'user_id', 20);
          v.addAll({
            'academic_year': year,
            'position': position,
            'user_id': member.isEmpty ? null : int.parse(member),
          });
          if (member.isNotEmpty) {
            final link = await one(
              s,
              "select profile_picture from users where id=?1 and role in ('student','officer')",
              [int.parse(member)],
            );
            require(link != null, 422, 'Invalid linked member.');
            if (current?['photo'] == null ||
                current?['user_id'] != v['user_id'])
              v['photo'] = link!['profile_picture'];
          }
        } else {
          final url = str(b, 'website_url', 2048), uri = Uri.tryParse(url);
          require(
            url.isEmpty ||
                uri != null &&
                    ['http', 'https'].contains(uri.scheme) &&
                    uri.host.isNotEmpty,
            422,
            'Enter an HTTP or HTTPS URL.',
          );
          v.addAll({
            'description': str(b, 'description', 2000, required: true),
            'website_url': url.isEmpty ? null : url,
            'is_active': b['is_active'] == 'true',
            if (b['remove_logo'] == true) 'logo_path': null,
          });
        }
        if (b['attachment'] != null) {
          uploaded = await storeUpload(
            b,
            roster ? 'officer-photos' : 'sponsor-logos',
            'public',
          );
          v[roster ? 'photo' : 'logo_path'] = uploaded!['path'];
        }
        await writeRecord(s, table, v, id);
      });
    } catch (_) {
      if (uploaded != null) await object('DELETE', 'public', uploaded!['path']);
      rethrow;
    }
    await retirePublicPhoto(
      roster ? 'officer-photos' : 'sponsor-logos',
      priorPhoto,
    );
    return {'back': k};
  }
}
