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
    bool featured = false,
    bool eventDate = false,
  }) async {
    var query = client
        .from('mobile_publications')
        .select('payload')
        .eq('module', module)
        .order(
          featured
              ? 'featured_at'
              : eventDate
              ? 'payload->>date'
              : 'sort_date',
          ascending: false,
          nullsFirst: false,
        );
    if (featured) query = query.order('sort_date', ascending: false);
    return _payloads(
      await query.order('record_id', ascending: true).limit(limit),
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
    if (path == 'home' || path == 'discover') {
      final limit = path == 'home' ? 1 : 3;
      final groups = await Future.wait([
        _recent('articles', limit, featured: true),
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
    const modules = {
      'articles',
      'activities',
      'achievements',
      'documents',
      'liquidations',
    };
    if (!modules.contains(path)) {
      throw ArgumentError('Unknown content section.');
    }
    var query = client
        .from('mobile_publications')
        .select('payload')
        .eq('module', path);
    final search = (params['q'] ?? '').trim();
    if (search.isNotEmpty) {
      final escaped = search
          .replaceAll('\\', '\\\\')
          .replaceAll('%', r'\%')
          .replaceAll('_', r'\_');
      query = query.ilike('search_text', '%$escaped%');
    }
    for (final key in ['category', 'semester', 'academic_year']) {
      final value = params[key];
      if (path == 'documents' && value != null && value.isNotEmpty) {
        query = value == 'unassigned' && key == 'academic_year'
            ? query.isFilter(key, null)
            : query.eq(key, value);
      }
    }
    final page = (int.tryParse(params['page'] ?? '') ?? 1).clamp(1, 1000000);
    final sort = params['sort'] ?? 'recent';
    final result = await query
        .order(
          sort == 'title' ? 'title' : 'sort_date',
          ascending: sort == 'title' || sort == 'oldest',
        )
        .order('record_id', ascending: true)
        .range((page - 1) * 10, page * 10 - 1)
        .count(CountOption.exact);
    final filters = <String, List<String>>{};
    if (path == 'documents') {
      // Filter choices use the same RLS boundary and paginate past PostgREST's row limit.
      final categories = <String>{}, years = <String>{};
      for (var offset = 0; ; offset += 500) {
        final rows = await client
            .from('mobile_publications')
            .select('category,academic_year')
            .eq('module', path)
            .order('record_id', ascending: true)
            .range(offset, offset + 499);
        for (final row in rows) {
          if (row['category'] case final String value when value.isNotEmpty) {
            categories.add(value);
          }
          if (row['academic_year'] case final String value
              when value.isNotEmpty) {
            years.add(value);
          }
        }
        if (rows.length < 500) break;
      }
      filters['category'] = categories.toList()..sort();
      filters['academic_year'] = years.toList()..sort((a, b) => b.compareTo(a));
    }
    return {
      'data': await _payloads(result.data),
      'meta': {
        'current_page': page,
        'last_page': ((result.count + 9) ~/ 10).clamp(1, 1000000),
        'total': result.count,
        'filters': filters,
      },
    };
  }
}
