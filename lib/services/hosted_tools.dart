part of 'cms_api.dart';

typedef _Row = Map<String, dynamic>;
List<_Row> _rows(dynamic value) => (value as List? ?? []).cast<_Row>();
_Row _field(
  String k, [
  dynamic value,
  String type = 'text',
  List<String>? choices,
]) => {
  'key': k,
  'value': value?.toString() ?? '',
  'type': type,
  'choices': ?choices,
};
_Row _link(String title, String path, [String? detail]) => {
  'title': title,
  'path': path,
  'detail': ?detail,
};
_Row _act(String title, String submit, [List<_Row> fields = const []]) => {
  'title': title,
  'submit': submit,
  'fields': fields,
};
const _roles = ['President', 'Secretary', 'Auditor', 'Social Media Manager'];
const _rosterTitles = [
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
const _fields = {
  'articles': ['content', 'category', 'content_format'],
  'activities': [
    'description',
    'category',
    'activity_date',
    'location',
    'content_format',
  ],
  'achievements': [
    'description',
    'category',
    'achievement_date',
    'awardee',
    'content_format',
  ],
  'documents': ['description', 'category', 'academic_year', 'semester'],
  'liquidations': ['description', 'amount', 'report_date', 'semester'],
};
bool _pdf(String m) => m == 'documents' || m == 'liquidations';

_Row _toolScreen(String path, _Row data, Map<String, String> filters) {
  final p = path.split('/'),
      k = p.first,
      m = p.elementAtOrNull(1) ?? '',
      r = (data['record'] as _Row?) ?? {},
      rows = _rows(data['rows']);
  final items = <_Row>[], controls = <_Row>[];
  final query = (filters['q'] ?? '').toLowerCase(),
      status = filters['status'] ?? '';
  bool matches(dynamic v) => v.toString().toLowerCase().contains(query);
  final now = DateTime.now().toUtc().add(const Duration(hours: 8)),
      year = now.year - (now.month < 6 ? 1 : 0),
      ay = '$year-${year + 1}';
  String title;
  switch (k) {
    case 'workspace':
      title = 'Workspace';
      final stats = _rows(data['stats']);
      if (data['president'] == true) {
        items.add(_link('Review submissions', 'reviews'));
      }
      final modules = <_Row>[];
      for (final mod in (data['modules'] as List).cast<String>()) {
        final counts = stats.where((row) => row['module'] == mod);
        int total(bool Function(_Row) include) => counts
            .where(include)
            .fold(0, (sum, row) => sum + (row['n'] as int));
        final activity =
            {
                  'pending': total((r) => r['approval'] == 'pending'),
                  'published': total(
                    (r) =>
                        r['approval'] == 'approved' && r['status'] == 'active',
                  ),
                  'archived': total((r) => r['status'] == 'archived'),
                }.entries
                .where((e) => e.value > 0)
                .map((e) => '${e.value} ${e.key}')
                .join(' \u00b7 ');
        modules.add(
          _link(
            mod == 'liquidations'
                ? 'Transparency'
                : mod[0].toUpperCase() + mod.substring(1),
            'content/$mod',
            activity.isEmpty ? null : activity,
          ),
        );
      }
      if (modules.isNotEmpty) {
        items.add({'title': 'Content library', 'rows': modules});
      }
      final tools = [
        if (modules.isNotEmpty) _link('Content activity', 'history'),
        if (data['president'] == true) ...[
          _link('Officer roster', 'roster'),
          _link('Sponsors', 'sponsors'),
        ],
        if (data['members'] is Map) _link('User accounts', 'users'),
      ];
      if (tools.isNotEmpty) items.add({'title': 'Organization', 'rows': tools});
      if (data['members'] case final Map counts) {
        items.add({
          'title': 'Member overview',
          'collapsed': true,
          'rows': [
            {
              'title': 'Members',
              'detail': counts.entries
                  .map((e) => '${e.key}: ${e.value}')
                  .join(' \u00b7 '),
            },
            for (final stat in stats.where(
              (r) =>
                  r['approval'] == 'pending' &&
                  !(data['modules'] as List).contains(r['module']),
            ))
              {'title': stat['module'], 'detail': '${stat['n']} pending'},
            for (final leader in _rows(data['leaders']))
              {'title': leader['name'], 'detail': leader['role']},
          ],
        });
      }
      break;
    case 'reviews':
    case 'history':
      title = k == 'reviews' ? 'Reviews' : 'Content activity';
      final mod = filters['module'] ?? '',
          state = filters['status'] ?? (k == 'reviews' ? 'pending' : '');
      final modules = (data['modules'] as List).cast<String>(),
          days = filters['days'] == '30' ? 30 : 7;
      controls.addAll([
        _field('module', mod, 'select', ['', ...modules]),
        _field('status', state, 'select', [
          '',
          if (k == 'reviews') 'pending',
          'approved',
          'rejected',
        ]),
        if (k == 'history') _field('days', days, 'select', ['7', '30']),
      ]);
      final posts = _rows(
            data['records'],
          ).where((r) => mod.isEmpty || mod == r['module']),
          events = _rows(
            data['events'],
          ).where((r) => mod.isEmpty || mod == r['module']);
      if (k == 'reviews') {
        for (final post in posts.where(
          (v) => (state.isEmpty || v['status'] == state) && matches(v['title']),
        )) {
          items.add(
            _link(
              post['title'],
              'content/${post['module']}/${post['id']}',
              '${post['module']} · ${post['status']}',
            ),
          );
        }
      } else {
        final daily = <String, List<int>>{};
        void count(_Row row, int index) {
          final date = DateTime.tryParse(row['created_at'].toString());
          if (date != null &&
              !date.isBefore(
                DateTime(
                  now.year,
                  now.month,
                  now.day,
                ).subtract(Duration(days: days - 1)),
              )) {
            (daily[date.toIso8601String().substring(0, 10)] ??= [
              0,
              0,
              0,
            ])[index]++;
          }
        }

        for (final post in posts) {
          count(post, 0);
        }
        for (final event in events) {
          count(event, event['decision'] == 'approved' ? 1 : 2);
        }
        final dates = daily.keys.toList()..sort();
        items.add({
          'title': 'Activity over $days days',
          'detail': dates.isEmpty
              ? 'No activity'
              : dates
                    .map(
                      (d) =>
                          '$d · ${daily[d]![0]} submitted · ${daily[d]![1]} approved · ${daily[d]![2]} rejected',
                    )
                    .join('\n'),
        });
        for (final e in events.where(
          (v) =>
              (state.isEmpty || v['decision'] == state) && matches(v['title']),
        )) {
          items.add({
            'title': e['title'],
            'detail':
                "${e['decision']} · ${e['reviewer']} · ${e['created_at']}\n${e['reason'] ?? ''}",
          });
        }
      }
      break;
    case 'profile':
      title = 'Profile';
      items.addAll([
        {
          'title': data['name'],
          'detail': "${data['email']}\n${data['role']}",
          'image': _photo(data['photo']),
        },
        _act('Update profile picture', 'profile/photo', [
          _field('attachment', null, 'image'),
        ]),
        if (data['photo'] != null)
          _act('Remove profile picture', 'profile/remove'),
      ]);
      break;
    case 'notifications':
      title = 'Notifications';
      if (rows.any((x) => x['read_at'] == null)) {
        items.add(_act('Mark all as read', 'notifications/read-all'));
      }
      const kinds = {
        'article': 'articles',
        'activity': 'activities',
        'achievement': 'achievements',
        'document': 'documents',
        'liquidation': 'liquidations',
      };
      for (final n in rows) {
        final d = n['data'];
        items.add({
          'title': d['message'] ?? 'Notification',
          'detail': d['title'] ?? '',
          if (kinds.containsKey(d['post_type']) && d['post_id'] != null)
            'path': "post/${kinds[d['post_type']]}/${d['post_id']}",
          'actions': [
            if (n['read_at'] == null)
              _act('Mark read', "notifications/${n['id']}/read"),
            _act('Delete notification', "notifications/${n['id']}/delete"),
          ],
        });
      }
      break;
    case 'post':
      title = r['title'];
      items.addAll([
        {
          'title': r['approval_status'],
          'detail': r['description'] ?? r['content'] ?? '',
        },
        if (_attachment(m, r) case final String url)
          {'title': 'Open attachment', 'file': url, 'pdf': _pdf(m)},
        if (data['editable'] == true)
          _link('Manage post', 'content/$m/${r['id']}'),
      ]);
      break;
    case 'users':
      title = m.isEmpty ? 'User accounts' : r['name'];
      if (m.isEmpty) {
        for (final t in rows) {
          items.add(
            _link(
              t['name'],
              'users/${t['id']}',
              '${t['email']} · ${t['role']}',
            ),
          );
        }
      } else {
        final choices = data['actor_role'] == 'adviser'
            ? ['student', 'officer']
            : r['role'] == 'adviser'
            ? ['student']
            : ['adviser'];
        items.addAll([
          {
            'title': r['email'],
            'detail': "${r['role']} · ${r['officer_position'] ?? ''}",
          },
          _act('Update role', path, [
            _field(
              'role',
              choices.contains(r['role']) ? r['role'] : choices.first,
              'select',
              choices,
            ),
            if (choices.contains('officer'))
              _field('position', r['officer_position'], 'select', [
                '',
                ..._roles,
              ]),
          ]),
        ]);
      }
      break;
    case 'sponsors':
    case 'roster':
      final roster = k == 'roster';
      title = roster ? 'Officer roster' : 'Sponsors';
      if (m.isEmpty) {
        items.addAll([
          _link('Add entry', '$k/new'),
          if (roster)
            _act('Copy previous year', 'roster/copy', [
              _field('academic_year', ay),
            ]),
          for (final t in rows)
            _link(
              t['name'],
              '$k/${t['id']}',
              roster
                  ? '${t['position']} · ${t['academic_year']}'
                  : t['description'],
            ),
        ]);
      } else {
        title = r['name'] ?? 'Add entry';
        items.addAll([
          _act('Save', path, [
            _field('name', r['name']),
            if (roster) ...[
              _field(
                'position',
                r['position'] ?? _rosterTitles.first,
                'select',
                _rosterTitles,
              ),
              _field('academic_year', r['academic_year'] ?? ay),
              _field('user_id', r['user_id'], 'select', [
                '',
                for (final t in _rows(data['users']))
                  "${t['id']}|${t['name']} · ${t['email']}",
              ]),
            ] else ...[
              _field('description', r['description'], 'long'),
              _field('website_url', r['website_url']),
              _field('is_active', r['is_active'] ?? true, 'select', [
                'true',
                'false',
              ]),
              if (r['logo_path'] != null) _field('remove_logo', false, 'check'),
            ],
            _field('sort_order', r['sort_order'] ?? 0),
            _field('attachment', null, 'image'),
          ]),
          if (m != 'new') _act('Delete entry', '$path/delete'),
        ]);
      }
      break;
    case 'content':
      final base = 'content/$m', doc = _pdf(m);
      if (p.length == 2) {
        title = 'Manage $m';
        controls.add(
          _field('status', status, 'select', [
            '',
            'draft',
            'pending',
            'approved',
            'rejected',
            'archived',
          ]),
        );
        items.addAll([
          _link('Create post', '$base/new'),
          for (final d in _rows(data['drafts']).where(
            (d) => (status.isEmpty || status == 'draft') && matches(d['title']),
          ))
            _link(
              d['title'] ?? 'Untitled draft',
              '$base/draft/${d['id']}',
              'Draft',
            ),
          for (final t in rows.where(
            (t) =>
                (status.isEmpty ||
                    t['approval_status'] == status ||
                    t['content_status'] == status) &&
                matches(t['title']),
          ))
            _link(
              t['title'],
              '$base/${t['id']}',
              '${t['approval_status']} · ${t['content_status']}',
            ),
          if (data['president'] == true)
            {
              'title': 'Bulk archive',
              'collapsed': true,
              'rows': [
                _act('Archive selected posts', '$base/bulk', [
                  _field('post_ids', '', 'ids', [
                    for (final t in rows) "${t['id']}|${t['title']}",
                  ]),
                ]),
              ],
            },
        ]);
      } else {
        final d = data['draft'], existing = r['id'] != null && d == null;
        title = r['title'] ?? (d == null ? 'New post' : 'Edit draft');
        if (existing) {
          items.add({
            'title': r['approval_status'],
            'detail': "${r['content_status']} ${r['rejection_reason'] ?? ''}",
          });
          if (_attachment(m, r) case final String url) {
            items.add({'title': 'Open attachment', 'file': url, 'pdf': doc});
          }
        }
        final fields = [
          _field('title', r['title']),
          for (final key in _fields[m]!)
            _field(
              key,
              key == 'content_format' ? r[key] ?? 'plain' : r[key],
              ['content', 'description'].contains(key)
                  ? 'long'
                  : ['semester', 'content_format'].contains(key)
                  ? 'select'
                  : key.endsWith('_date')
                  ? 'date'
                  : 'text',
              key == 'semester'
                  ? ['', '1', '2']
                  : key == 'content_format'
                  ? ['plain', 'markdown']
                  : null,
            ),
          _field('attachment', null, doc ? 'pdf' : 'image'),
          if (d != null) ...[
            _field('draft_id', d['id'], 'hidden'),
            _field('version', d['lock_version'], 'hidden'),
          ],
          if (existing) ...[
            _field('id', r['id'], 'hidden'),
            _field('updated', r['updated_at'], 'hidden'),
          ],
        ];
        items.add({
          ..._act(
            existing ? 'Save changes' : 'Submit post',
            '$base/save',
            fields,
          ),
          'draft': !existing,
          'preview': !doc,
        });
        if (d != null) items.add(_act('Delete draft', '$path/delete'));
        if (existing) {
          final actions = <_Row>[];
          for (final op in [
            r['content_status'] == 'archived' ? 'restore' : 'archive',
            if (data['president'] == true &&
                r['approval_status'] == 'pending') ...[
              'approve',
              'reject',
            ],
            if (data['president'] == true && r['content_status'] == 'archived')
              'delete',
          ]) {
            actions.add(
              _act(op[0].toUpperCase() + op.substring(1), '$path/$op', [
                _field('updated', r['updated_at'], 'hidden'),
                if (op == 'reject') _field('reason'),
              ]),
            );
          }
          items.add({
            'title': 'Publishing actions',
            'collapsed': true,
            'rows': actions,
          });
          final versions = <_Row>[];
          for (final v in _rows(data['versions'])) {
            versions.add({
              'title': "${v['kind']} · ${v['editor_name'] ?? ''}",
              'detail': (v['snapshot'] as Map).entries
                  .map((e) => '${e.key}: ${e.value ?? ''}')
                  .join('\n'),
            });
          }
          if (versions.isNotEmpty) {
            items.add({
              'title': 'Version history',
              'collapsed': true,
              'rows': versions,
            });
          }
        }
      }
      break;
    default:
      throw const FormatException('Unknown account page.');
  }
  return {
    'title': title,
    'items': items,
    if (controls.isNotEmpty) 'filters': controls,
  };
}
