part of 'server.dart';

extension Workspace on MobileServer {
  Future<T> tx<T>(Future<T> Function(TxSession) work) =>
      (db as SessionExecutor).runTx(work);
  Future<Row> toolsPage(
    Row u,
    List<String> path,
    Row b,
    bool post,
    Map<String, String> q,
  ) async {
    require(path.isNotEmpty, 404, 'Unknown page.');
    final k = path[0];
    if (k == 'workspace' && !post) {
      require(staff(u), 403, 'No workspace access.');
      final summary = <Row>[];
      final assignment = ['admin', 'adviser'].contains(u['role']);
      for (final m in assignment ? modules.keys : allowed(u)) {
        final totals = await rows(
          db,
          'select approval_status,content_status,count(*) as count from $m where (?1 or created_by_user_id=?2) group by approval_status,content_status',
          [assignment || president(u), u['id']],
        );
        int sum(bool Function(Row) include) =>
            totals.where(include).fold(0, (n, r) => n + (r['count'] as int));
        final pending = sum((r) => r['approval_status'] == 'pending');
        if (assignment) {
          summary.add({'title': m, 'detail': '$pending pending review'});
        } else {
          summary.add(
            item(
              'Manage $m',
              'content/$m',
              detail:
                  '$pending pending ? ${sum(live)} published ? ${sum((r) => r['content_status'] == 'archived')} archived',
            ),
          );
        }
      }
      if (assignment) {
        final counts = await rows(
          db,
          'select role,count(*) as n from users group by role',
        );
        summary.add({
          'title': 'Members',
          'detail': counts.map((r) => "${r['role']}: ${r['n']}").join(' ? '),
        });
        final leaders = await rows(
          db,
          "select name,role from users where (role='officer' and lower(officer_position)='president') or (?1 and role='adviser') order by name",
          [u['role'] == 'admin'],
        );
        summary.add({
          'title': 'President',
          'detail':
              leaders
                  .where((r) => r['role'] == 'officer')
                  .firstOrNull?['name'] ??
              'Unassigned',
        });
        if (u['role'] == 'admin')
          summary.add({
            'title': 'Advisers',
            'detail': leaders
                .where((r) => r['role'] == 'adviser')
                .map((r) => r['name'])
                .join(', '),
          });
      }
      return screen('Workspace', [
        ...summary,
        if (allowed(u).isNotEmpty) item('Content activity', 'history'),
        if (president(u)) ...[
          item('Review submissions', 'reviews'),
          item('Officer roster', 'roster'),
          item('Sponsors', 'sponsors'),
        ],
        if (['adviser', 'admin'].contains(u['role']))
          item('User accounts', 'users'),
      ]);
    }
    if (k == 'history' || k == 'reviews') {
      require(
        !post && allowed(u).isNotEmpty && (k != 'reviews' || president(u)),
        403,
        'No access.',
      );
      final records = <Row>[], summary = <Row>[];
      final days = q['days'] == '30' ? 30 : 7, search = '%${q['q'] ?? ''}%';
      final status = q['status'] ?? (k == 'reviews' ? 'pending' : '');
      require(
        ['', 'pending', 'approved', 'rejected'].contains(status),
        422,
        'Unknown status.',
      );
      final daily = <String, List<int>>{};
      for (final m in allowed(
        u,
      ).where((m) => (q['module'] ?? '').isEmpty || q['module'] == m)) {
        if (k == 'reviews') {
          final found = await rows(
            db,
            "select id,title,approval_status,updated_at from $m where (?1='' or approval_status=?1) and title ilike ?2 order by updated_at desc",
            [status, search],
          );
          for (final p in found) {
            records.add({
              ...item(
                p['title'],
                'content/$m/${p['id']}',
                detail: "$m ? ${p['approval_status']}",
              ),
              'time': stamp(p),
            });
          }
        } else {
          final events = await rows(
            db,
            "select e.* from content_review_events e where e.post_type=?1 and exists(select 1 from $m p where p.id=e.post_id and (?2 or p.created_by_user_id=?3)) and e.post_title ilike ?4 and (?5='' or e.decision=?5) order by e.created_at desc",
            [modules[m]!.first, president(u), u['id'], search, status],
          );
          for (final e in events) {
            records.add({
              'title': e['post_title'],
              'detail':
                  "${e['decision']} ? ${e['reviewer_name']} ? ${e['created_at']}\n${e['reason'] ?? ''}",
              'time': e['created_at'].toString(),
            });
          }
          final counts = await rows(
            db,
            "select created_at::date::text as day,count(*) as n from $m where (?1 or created_by_user_id=?2) and created_at>=current_date-(?3::int-1) group by 1",
            [president(u), u['id'], days],
          );
          for (final c in counts) {
            (daily[c['day']] ??= [0, 0, 0])[0] += c['n'] as int;
          }
          final recent = await rows(
            db,
            "select e.created_at::date::text as day,e.decision,count(*) as n from content_review_events e where e.post_type=?1 and exists(select 1 from $m p where p.id=e.post_id and (?2 or p.created_by_user_id=?3)) and e.created_at>=current_date-(?4::int-1) group by 1,2",
            [modules[m]!.first, president(u), u['id'], days],
          );
          for (final c in recent) {
            (daily[c['day']] ??= [
              0,
              0,
              0,
            ])[c['decision'] == 'approved' ? 1 : 2] += c['n'] as int;
          }
        }
      }
      if (k == 'history') {
        final dates = daily.keys.toList()..sort();
        summary.add({
          'title': 'Activity over $days days',
          'detail': dates.isEmpty
              ? 'No activity'
              : dates
                    .map(
                      (d) =>
                          "$d ? ${daily[d]![0]} submitted ? ${daily[d]![1]} approved ? ${daily[d]![2]} rejected",
                    )
                    .join('\n'),
        });
      }
      records.sort(
        (a, b) => b['time'].toString().compareTo(a['time'].toString()),
      );
      return {
        ...screen(k == 'reviews' ? 'Reviews' : 'Content activity', [
          ...summary,
          ...records,
        ]),
        'filters': [
          input('module', q['module'] ?? '', 'select', ['', ...allowed(u)]),
          input('status', status, 'select', [
            '',
            if (k == 'reviews') 'pending',
            'approved',
            'rejected',
          ]),
          if (k == 'history') input('days', days, 'select', ['7', '30']),
        ],
      };
    }
    if (k != 'content') return adminPage(u, path, b, post, q);
    require(path.length >= 2, 404, 'Unknown module.');
    final m = path[1];
    module(m);
    require(allowed(u).contains(m), 403, 'No access to this module.');
    final base = 'content/$m';
    if (!post && path.length == 2) {
      final result = await rows(
        db,
        'select id,title,approval_status,content_status from $m where (?1 or created_by_user_id=?2) order by updated_at desc,id desc',
        [president(u), u['id']],
      );
      final drafts = await rows(
        db,
        'select id,payload from content_drafts where module=?1 and created_by_user_id=?2 order by updated_at desc',
        [m, u['id']],
      );
      final status = q['status'] ?? '', query = (q['q'] ?? '').toLowerCase();
      return {
        ...screen('Manage $m', [
          item('Create post', '$base/new'),
          for (final d in drafts.where(
            (d) =>
                (status.isEmpty || status == 'draft') &&
                (d['payload']['title'] ?? '').toString().toLowerCase().contains(
                  query,
                ),
          ))
            item(
              d['payload']['title'] ?? 'Untitled draft',
              '$base/draft/${d['id']}',
              detail: 'Draft',
            ),
          for (final p in result.where(
            (p) =>
                (status.isEmpty ||
                    p['content_status'] == status ||
                    p['approval_status'] == status) &&
                p['title'].toString().toLowerCase().contains(query),
          ))
            item(
              p['title'],
              '$base/${p['id']}',
              detail: '${p['approval_status']} · ${p['content_status']}',
            ),
          if (president(u))
            action('Bulk archive', '$base/bulk', [
              input(
                'post_ids',
                '',
                'ids',
                result.map((e) => '${e['id']}|${e['title']}').toList(),
              ),
            ]),
        ]),
        'filters': [
          input('status', status, 'select', [
            '',
            'draft',
            'pending',
            'approved',
            'rejected',
            'archived',
          ]),
        ],
      };
    }
    if (post && path.last == 'bulk') {
      require(president(u), 403, 'President required.');
      final ids = str(
        b,
        'post_ids',
        1500,
        required: true,
      ).split(',').map(int.parse).toSet().toList();
      require(ids.length <= 100, 422, 'Select up to 100 posts.');
      await tx((s) async {
        final actor = await lockedUser(s, u);
        require(president(actor), 403, 'President required.');
        final found = await rows(
          s,
          'select id from $m where id=any(?1::int[]) for update',
          [ids],
        );
        require(found.length == ids.length, 422, 'Unknown post.');
        await rows(
          s,
          "update $m set content_status='archived',updated_at=now() where id=any(?1::int[])",
          [ids],
        );
      });
      return {'back': base};
    }
    if (post && path.last == 'save') return savePost(u, m, b);
    if (post) return transition(u, m, path, b);
    final draft = path.length == 4 && path[2] == 'draft',
        fresh = path.length == 3 && path[2] == 'new';
    Row p = {};
    if (draft) {
      p =
          await one(
            db,
            'select * from content_drafts where id=?1 and module=?2 and created_by_user_id=?3',
            [path[3], m, u['id']],
          ) ??
          (throw Problem(404, 'Draft unavailable.'));
    } else if (!fresh) {
      p =
          await one(db, 'select * from $m where id=?1', [
            int.tryParse(path.last) ?? -1,
          ]) ??
          (throw Problem(404, 'Post unavailable.'));
      require(editable(u, m, p), 403, 'No access.');
    }
    final record = draft ? p['payload'] as Row : p,
        fields = <Row>[
          input('title', record['title']),
          for (final key in modules[m]!.skip(1))
            input(
              key,
              record[key],
              ['content', 'description'].contains(key)
                  ? 'long'
                  : key == 'semester'
                  ? 'select'
                  : key.endsWith('_date')
                  ? 'date'
                  : 'text',
              key == 'semester' ? ['', '1', '2'] : null,
            ),
          if (!pdf(m))
            input(
              'content_format',
              record['content_format'] ?? 'plain',
              'select',
              ['plain', 'markdown'],
            ),
          input('attachment', null, pdf(m) ? 'pdf' : 'image'),
          if (draft) ...[
            input('draft_id', p['id'], 'hidden'),
            input('version', p['lock_version'], 'hidden'),
          ],
          if (!draft && !fresh) ...[
            input('id', p['id'], 'hidden'),
            input('updated', stamp(p), 'hidden'),
          ],
        ];
    final items = <Row>[
      if (!draft && !fresh)
        {
          'title': p['approval_status'],
          'detail': '${p['content_status']} ${p['rejection_reason'] ?? ''}',
        },
      if (!draft && !fresh && p[pdf(m) ? 'file_path' : 'image'] != null)
        {
          'title': 'Open attachment',
          'file': '$api/attachment/$m/${p['id']}',
          'pdf': pdf(m),
        },
      {
        ...action(
          fresh || draft ? 'Submit post' : 'Save changes',
          '$base/save',
          fields,
        ),
        if (draft || fresh) 'draft': true,
        if (!pdf(m)) 'preview': true,
      },
    ];
    if (draft)
      items.add(action('Delete draft', '$base/draft/${p['id']}/delete'));
    if (!draft && !fresh) {
      final id = p['id'];
      for (final op in [
        p['content_status'] == 'archived' ? 'restore' : 'archive',
        if (president(u) && p['approval_status'] == 'pending') ...[
          'approve',
          'reject',
        ],
        if (president(u) && p['content_status'] == 'archived') 'delete',
      ]) {
        items.add(
          action(op, '$base/$id/$op', [
            input('updated', stamp(p), 'hidden'),
            if (op == 'reject') input('reason'),
          ]),
        );
      }
      for (final version in await rows(
        db,
        'select editor_name,kind,snapshot,created_at from content_versions where post_id=?1 and post_type=?2 order by id desc',
        [id, modules[m]!.first],
      )) {
        items.add({
          'title': '${version['kind']} · ${version['editor_name'] ?? ''}',
          'detail': (version['snapshot'] as Map).entries
              .map((e) => '${e.key}: ${e.value ?? ''}')
              .join('\n'),
        });
      }
    }
    return screen(
      fresh ? 'New post' : (record['title'] ?? 'Edit draft').toString(),
      items,
    );
  }

  String stamp(Row p) => p['updated_at'] is DateTime
      ? (p['updated_at'] as DateTime).toIso8601String()
      : p['updated_at'].toString();
  Future<Row> lockedUser(Session s, Row u) async =>
      (await one(
        s,
        'select id,name,role,officer_position from users where id=?1 and profile_completed_at is not null for share',
        [u['id']],
      )) ??
      (throw Problem(403, 'Account unavailable.'));
  Future<Row> writeRecord(
    Session s,
    String table,
    Row values,
    dynamic id,
  ) async {
    final names = values.keys.toList(),
        args = values.values.toList(),
        params = List.generate(names.length, (i) => '?${i + 1}');
    final sql = id == null
        ? 'insert into $table(${names.join(',')},created_at,updated_at) values(${params.join(',')},now(),now())'
        : 'update $table set ${List.generate(names.length, (i) => '${names[i]}=${params[i]}').join(',')},updated_at=now() where id=?${args.length + 1}';
    return (await one(s, '$sql returning *', [...args, if (id != null) id])) ??
        (throw Problem(404, 'Record unavailable.'));
  }

  Future<void> notify(
    Session s,
    String m,
    Row p,
    Row u,
    String type, [
    String? reason,
  ]) async {
    const classes = {
      'approved': 'PostApproved',
      'rejected': 'PostRejected',
      'submitted': 'PostSubmittedForReview',
      'published': 'PostPublished',
      'liked': 'PostLiked',
    };
    final msg = {
      'approved': 'Your request was approved.',
      'rejected': 'Your post was rejected.',
      'published': 'A new post was published.',
      'liked': '${u['name']} liked your post.',
      'submitted': 'A post is awaiting review.',
    }[type];
    final data = {
      'post_type': modules[m]!.first,
      'post_id': p['id'],
      'title': p['title'],
      'actor_id': u['id'],
      'actor_name': u['name'],
      'message': msg,
      'reason': reason,
      'type': type,
      'url': "${cfg['APP_URL'] ?? ''}/$m/${p['id']}",
    };
    final args = <dynamic>[
      'App\\Notifications\\${classes[type]}',
      r'App\Models\User',
      encode(data),
    ];
    final where = switch (type) {
      'submitted' => "role='officer' and lower(officer_position)='president'",
      'published' => 'id<>?4 and id<>?5',
      _ => 'id=?4',
    };
    if (type == 'published') {
      args.addAll([u['id'], p['created_by_user_id'] ?? 0]);
    } else if (type != 'submitted') {
      args.add(p['created_by_user_id']);
    }
    await rows(
      s,
      'insert into notifications(id,type,notifiable_type,notifiable_id,data,created_at,updated_at) select gen_random_uuid(),?1,?2,id,?3,now(),now() from users where $where',
      args,
    );
  }

  Future<Row> savePost(Row u, String m, Row b) async {
    final draft = b['as_draft'] == true,
        keys = ['title', ...modules[m]!.skip(1), if (!pdf(m)) 'content_format'],
        values = <String, dynamic>{};
    for (final key in keys) {
      final long = ['content', 'description'].contains(key);
      final v = str(
        b,
        key,
        long
            ? 20000
            : key == 'category'
            ? 100
            : 200,
        required: !draft && (key == 'title' || (long && !pdf(m))),
      );
      if (long)
        require(
          v.trim().split(RegExp(r'\s+')).length <= 300,
          422,
          'Maximum 300 words.',
        );
      if (key == 'content_format')
        require(['plain', 'markdown'].contains(v), 422, 'Unknown format.');
      if (v.isNotEmpty && key == 'academic_year')
        require(yearOK(v), 422, 'Use consecutive academic years.');
      if (v.isNotEmpty && key == 'semester')
        require(['1', '2'].contains(v), 422, 'Invalid semester.');
      if (v.isNotEmpty && key == 'amount')
        require(
          RegExp(r'^\d{1,10}(\.\d{1,2})?$').hasMatch(v),
          422,
          'Invalid amount.',
        );
      if (v.isNotEmpty && key.endsWith('_date'))
        require(
          DateTime.tryParse(v)?.toIso8601String().substring(0, 10) == v,
          422,
          'Invalid date.',
        );
      values[key] = v.isEmpty ? null : v;
    }
    Row? stored;
    final obsolete = <(String, String)>[];
    try {
      await tx((s) async {
        final actor = await lockedUser(s, u);
        require(allowed(actor).contains(m), 403, 'Module unavailable.');
        final old = b['id'] == null
            ? null
            : await one(s, 'select * from $m where id=?1 for update', [
                int.parse(b['id'].toString()),
              ]);
        require(
          b['id'] == null || old != null && editable(actor, m, old),
          403,
          'No access.',
        );
        require(
          old == null || stamp(old) == b['updated'],
          409,
          'Post changed. Reopen it.',
        );
        final d = b['draft_id'] == null
            ? null
            : await one(
                s,
                'select * from content_drafts where id=?1 and module=?2 and created_by_user_id=?3 for update',
                [b['draft_id'], m, u['id']],
              );
        require(
          b['draft_id'] == null ||
              d != null &&
                  d['lock_version'].toString() == b['version'].toString(),
          409,
          'Draft changed. Reopen it.',
        );
        final prev = d?['payload']?['attachment'];
        final folder = draft
            ? 'drafts/${u['id']}'
            : pdf(m)
            ? (m == 'liquidations' ? 'liquidation' : m)
            : 'post-media/$m';
        if (b['attachment'] != null) {
          stored = await storeUpload(b, folder, 'private', isPdf: pdf(m));
        } else if (!draft && prev != null) {
          require(
            prev['path'].toString().startsWith('drafts/${u['id']}/'),
            422,
            'Invalid draft attachment.',
          );
          final bytes = await object('GET', 'private', prev['path']);
          final key =
              '$folder/${token(20)}.${prev['path'].toString().split('.').last}';
          await object('PUT', 'private', key, bytes);
          stored = {...prev, 'path': key};
        }
        if (draft) {
          require(old == null, 422, 'Drafts are for new posts.');
          if (stored != null || prev != null)
            values['attachment'] = stored ?? prev;
          if (d == null) {
            await rows(
              s,
              'insert into content_drafts(id,created_by_user_id,module,payload,lock_version,created_at,updated_at) values(gen_random_uuid(),?1,?2,?3::json,1,now(),now())',
              [u['id'], m, encode(values)],
            );
          } else {
            await rows(
              s,
              'update content_drafts set payload=?1::json,lock_version=lock_version+1,updated_at=now() where id=?2',
              [encode(values), d['id']],
            );
          }
          if (stored != null && prev != null)
            obsolete.add(('private', prev['path']));
          return;
        }
        final fileKey = pdf(m) ? 'file_path' : 'image';
        require(
          stored != null || old?[fileKey] != null,
          422,
          'Select an attachment.',
        );
        if (stored != null) {
          values[fileKey] = stored!['path'];
          if (pdf(m)) {
            values['file_size'] = stored!['size'];
            values['original_name'] = stored!['original_name'];
          }
          final oldKey = old?[fileKey];
          if (oldKey is String)
            obsolete.add((
              pdf(m) || oldKey.startsWith('post-media/') ? 'private' : 'public',
              oldKey,
            ));
        }
        if (old == null) {
          values.addAll({
            'created_by_user_id': u['id'],
            'approval_status':
                president(actor) &&
                    cfg['SCHOOL_PRESIDENT_POSTS_AUTO_APPROVED'] != 'false'
                ? 'approved'
                : 'pending',
            'content_status': 'active',
          });
          if (values['approval_status'] == 'approved') {
            values['reviewed_by_user_id'] = actor['id'];
            values['reviewed_at'] = DateTime.now().toUtc();
          }
        } else if (!president(actor) &&
            (old['approval_status'] == 'rejected' ||
                old['approval_status'] == 'approved' &&
                    cfg['SCHOOL_RESET_APPROVAL_ON_EDIT'] != 'false')) {
          values.addAll({
            'approval_status': 'pending',
            'reviewed_by_user_id': null,
            'reviewed_at': null,
            'rejection_reason': null,
          });
        }
        final p = await writeRecord(s, m, values, old?['id']);
        Row snap(Row r) => {for (final k in keys) k: r[k]};
        Future<void> version(String kind, Row r) async {
          await rows(
            s,
            'insert into content_versions(post_type,post_id,editor_user_id,editor_name,kind,snapshot,created_at) values(?1,?2,?3,?4,?5,?6::json,now())',
            [
              modules[m]!.first,
              p['id'],
              actor['id'],
              actor['name'],
              kind,
              encode(snap(r)),
            ],
          );
        }

        if (old != null &&
            await one(
                  s,
                  'select id from content_versions where post_type=?1 and post_id=?2 limit 1',
                  [modules[m]!.first, p['id']],
                ) ==
                null)
          await version('baseline', old);
        if (old == null || encode(snap(old)) != encode(snap(p)))
          await version(old == null ? 'created' : 'edited', p);
        if (old == null || values['approval_status'] == 'pending')
          await notify(
            s,
            m,
            p,
            actor,
            p['approval_status'] == 'approved' ? 'published' : 'submitted',
          );
        if (d != null) {
          await rows(s, 'delete from content_drafts where id=?1', [d['id']]);
          if (prev != null) obsolete.add(('private', prev['path']));
        }
      });
    } catch (_) {
      if (stored != null) await object('DELETE', 'private', stored!['path']);
      rethrow;
    }
    for (final (disk, key) in obsolete) {
      try {
        await object('DELETE', disk, key);
      } catch (_) {
        stderr.writeln('Obsolete content attachment requires cleanup.');
      }
    }
    return {'back': 'content/$m'};
  }

  Future<Row> transition(Row u, String m, List<String> path, Row b) async {
    String? removed;
    String disk = 'private';
    await tx((s) async {
      final actor = await lockedUser(s, u);
      require(allowed(actor).contains(m), 403, 'No access.');
      if (path.length == 5 && path[2] == 'draft' && path.last == 'delete') {
        final d = await one(
          s,
          'delete from content_drafts where id=?1 and module=?2 and created_by_user_id=?3 returning payload',
          [path[3], m, u['id']],
        );
        final k = d?['payload']?['attachment']?['path'];
        if (k is String && k.startsWith('drafts/${u['id']}/')) removed = k;
        return;
      }
      require(path.length == 4, 404, 'Unknown action.');
      final id = int.parse(path[2]), op = path.last;
      final p = await one(s, 'select * from $m where id=?1 for update', [id]);
      require(p != null && editable(actor, m, p), 403, 'No access.');
      require(stamp(p!) == b['updated'], 409, 'Post changed. Reload it.');
      if (['archive', 'restore'].contains(op)) {
        await rows(
          s,
          'update $m set content_status=?1,updated_at=now() where id=?2',
          [op == 'archive' ? 'archived' : 'active', id],
        );
        return;
      }
      require(president(actor), 403, 'President required.');
      if (op == 'delete') {
        require(
          p['content_status'] == 'archived',
          409,
          'Archive this post first.',
        );
        for (final t in ['post_likes', 'post_views']) {
          await rows(s, 'delete from $t where post_type=?1 and post_id=?2', [
            modules[m]!.first,
            id,
          ]);
        }
        await rows(s, 'delete from $m where id=?1', [id]);
        removed = p[pdf(m) ? 'file_path' : 'image'];
        if (!pdf(m) && removed?.startsWith('post-media/') == false)
          disk = 'public';
        return;
      }
      require(
        ['approve', 'reject'].contains(op) && p['approval_status'] == 'pending',
        409,
        'Only pending posts can be reviewed.',
      );
      final decision = op == 'approve' ? 'approved' : 'rejected',
          reason = op == 'reject'
              ? str(b, 'reason', 255, required: true)
              : null;
      await rows(
        s,
        'update $m set approval_status=?1,rejection_reason=?2,reviewed_by_user_id=?3,reviewed_at=now(),updated_at=now() where id=?4',
        [decision, reason, u['id'], id],
      );
      await rows(
        s,
        'insert into content_review_events(post_type,post_id,reviewer_user_id,reviewer_name,post_title,decision,reason,created_at) values(?1,?2,?3,?4,?5,?6,?7,now())',
        [
          modules[m]!.first,
          id,
          u['id'],
          actor['name'],
          p['title'],
          decision,
          reason,
        ],
      );
      await notify(s, m, p, actor, decision, reason);
      if (decision == 'approved' && p['content_status'] == 'active')
        await notify(s, m, p, actor, 'published');
    });
    if (removed != null) await object('DELETE', disk, removed!);
    return {'back': 'content/$m'};
  }
}
