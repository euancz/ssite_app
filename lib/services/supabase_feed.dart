import 'package:supabase_flutter/supabase_flutter.dart';

/// Only the curated read model is exposed to app users, never CMS tables.
class SupabaseFeed {
  SupabaseFeed(this.client);
  final SupabaseClient client;
  static const bucket = String.fromEnvironment(
    'SSITE_SUPABASE_MOBILE_BUCKET',
    defaultValue: 'ssite-mobile',
  );

  Future<List<Map<String, dynamic>>> _payloads(List<dynamic> rows) async =>
      Future.wait(
        rows.map((row) async {
          final data = Map<String, dynamic>.from(row['payload'] as Map);
          for (final entry in const {
            'image_path': 'image_url',
            'file_path': 'file_url',
            'photo_path': 'photo_url',
            'logo_path': 'logo_url',
          }.entries) {
            final path = data.remove(entry.key);
            if (path is String && path.isNotEmpty) {
              data[entry.value] = await client.storage
                  .from(bucket)
                  .createSignedUrl(path, 3600);
            }
          }
          return data;
        }),
      );

  Future<List<Map<String, dynamic>>> _recent(
    String module,
    int limit, {
    bool eventDate = false,
  }) async {
    return _payloads(
      await client
          .from('mobile_publications')
          .select('payload')
          .eq('module', module)
          .order(
            eventDate ? 'payload->>date' : 'sort_date',
            ascending: false,
            nullsFirst: false,
          )
          .order('record_id', ascending: module != 'articles')
          .limit(limit),
    );
  }

  String get academicYear {
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    final start = now.month >= 6 ? now.year : now.year - 1;
    return '$start-${start + 1}';
  }

  Future<Map<String, dynamic>> get(
    String path,
    Map<String, String> params,
  ) async {
    if (client.auth.currentSession == null) {
      throw const AuthException('Sign in again.');
    }
    final allowed = await client.rpc('mobile_reader_allowed');
    if (allowed != true) {
      throw const AuthException(
        'Use your Mabalacat City College Microsoft account.',
      );
    }
    if (path == 'auth/me') {
      final user = client.auth.currentUser!;
      return {
        'user': {
          'name': user.userMetadata?['full_name'] ?? user.email,
          'email': user.email,
          'can_access_workspace': false,
        },
      };
    }
    final combinedDiscover = path == 'discover' && params['feed'] == '1';
    if (path == 'home' || (path == 'discover' && !combinedDiscover)) {
      final limit = path == 'home' ? 1 : 3;
      final groups = await Future.wait([
        _recent('articles', limit),
        _recent('activities', limit, eventDate: path == 'home'),
        _recent('achievements', limit, eventDate: path == 'home'),
      ]);
      return {
        'data': {
          'articles': groups[0],
          'activities': groups[1],
          'achievements': groups[2],
          if (path == 'home')
            'officers': (await get('about', {}))['data']['officers'],
          if (path == 'home')
            'sponsors': await _payloads(
              await client
                  .from('mobile_publications')
                  .select('payload')
                  .eq('module', 'sponsors')
                  .order('sort_order', ascending: true)
                  .order('title', ascending: true)
                  .order('record_id', ascending: true),
            ),
        },
      };
    }
    if (path == 'about') {
      final rows = await client
          .from('mobile_publications')
          .select('payload')
          .eq('module', 'officers')
          .order('sort_order', ascending: true)
          .order('title', ascending: true);
      final officers = await _payloads(rows);
      final history = <String, List<Map<String, dynamic>>>{};
      for (final officer in officers) {
        final year = officer['academic_year'] as String;
        if (year != academicYear) (history[year] ??= []).add(officer);
      }
      return {
        'data': {
          'academic_year': academicYear,
          'officers': officers
              .where((o) => o['academic_year'] == academicYear)
              .toList(),
          'history': history,
        },
      };
    }
    const stories = ['articles', 'activities', 'achievements'];
    const modules = {...stories, 'documents', 'liquidations'};
    if (!combinedDiscover && !modules.contains(path)) {
      throw ArgumentError('Unknown content section.');
    }
    final type = params['type'];
    final selectedStory = combinedDiscover && stories.contains(type)
        ? type
        : null;
    final publications = client.from('mobile_publications');
    var query = publications.select('payload');
    query = combinedDiscover && selectedStory == null
        ? query.inFilter('module', stories)
        : query.eq('module', selectedStory ?? path);
    final search = (params['q'] ?? '').trim();
    if (search.isNotEmpty) {
      final escaped = search
          .replaceAll('\\', '\\\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_');
      query = query.ilike('search_text', '%$escaped%');
    }
    final permittedFilters = switch (selectedStory ?? path) {
      'documents' => ['category', 'semester', 'academic_year'],
      'liquidations' => ['semester'],
      _ when stories.contains(path) => ['category'],
      _ => <String>[],
    };
    for (final key in permittedFilters) {
      final value = params[key];
      if (value != null && value.isNotEmpty) {
        query = value == 'unassigned' && key == 'academic_year'
            ? query.isFilter(key, null)
            : query.eq(key, value);
      }
    }
    if (combinedDiscover || stories.contains(path)) {
      final now = DateTime.now().toUtc();
      final since = switch (params['period']) {
        'week' => now.subtract(const Duration(days: 7)),
        'month' => now.subtract(const Duration(days: 30)),
        'year' => DateTime.utc(
          now.year - 1,
          now.month,
          now.day,
          now.hour,
          now.minute,
          now.second,
        ),
        _ => null,
      };
      if (since != null) {
        query = query.gte('sort_date', since.toIso8601String());
      }
    }
    if (path == 'liquidations') {
      final event = params['event'];
      if (event != null && event.isNotEmpty) query = query.eq('title', event);
      final year = params['year'] ?? '';
      if (RegExp(r'^[1-9][0-9]{3}$').hasMatch(year) && year != '9999') {
        final nextYear = int.parse(year) + 1;
        query = query
            .gte('payload->>date', '$year-01-01')
            .lt('payload->>date', '$nextYear-01-01');
      }
    }
    final page = (int.tryParse(params['page'] ?? '') ?? 1).clamp(1, 1000000);
    final pageSize = combinedDiscover ? 9 : 10;
    final sort = params['sort'] ?? 'recent';
    final reportDateSort =
        path == 'liquidations' &&
        (sort == 'report_soonest' || sort == 'report_latest');
    var ordered = query.order(
      reportDateSort
          ? 'payload->>date'
          : sort == 'title'
          ? 'title'
          : 'sort_date',
      ascending:
          sort == 'title' || sort == 'oldest' || sort == 'report_soonest',
    );
    if (combinedDiscover) ordered = ordered.order('module', ascending: true);
    final result = await ordered
        .order('record_id', ascending: !combinedDiscover)
        .range((page - 1) * pageSize, page * pageSize - 1)
        .count(CountOption.exact);
    return {
      'data': await _payloads(result.data),
      'meta': {
        'current_page': page,
        'last_page': ((result.count + pageSize - 1) ~/ pageSize).clamp(
          1,
          1000000,
        ),
        'total': result.count,
        'filters': page == 1 && params['facets'] != '0'
            ? await _filters(selectedStory ?? path)
            : <String, List<String>>{},
      },
    };
  }

  Future<Map<String, List<String>>> _filters(String module) async {
    final fields = switch (module) {
      'documents' => {'category': 'category', 'academic_year': 'academic_year'},
      'liquidations' => {'event': 'title', 'year': 'year:payload->>date'},
      'articles' || 'activities' || 'achievements' => {'category': 'category'},
      _ => <String, String>{},
    };
    if (fields.isEmpty) return {};
    final options = {for (final key in fields.keys) key: <String>{}};
    for (var offset = 0; ; offset += 500) {
      final rows = await client
          .from('mobile_publications')
          .select(fields.values.join(','))
          .eq('module', module)
          .order('record_id', ascending: true)
          .range(offset, offset + 499);
      for (final row in rows) {
        for (final key in fields.keys) {
          if (row[key == 'event' ? 'title' : key] case final String value
              when value.trim().isNotEmpty) {
            if (key != 'year') {
              options[key]!.add(value);
            } else if (DateTime.tryParse(value) case final date?) {
              options[key]!.add('${date.year}');
            }
          }
        }
      }
      if (rows.length < 500) break;
    }
    return options.map(
      (key, values) => MapEntry(
        key,
        values.toList()..sort(
          (a, b) => key == 'year' || key == 'academic_year'
              ? b.compareTo(a)
              : a.compareTo(b),
        ),
      ),
    );
  }
}
