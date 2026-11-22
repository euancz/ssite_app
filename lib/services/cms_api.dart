import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:markdown/markdown.dart' as md;
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

part 'supabase_access.dart';
part 'hosted_tools.dart';

String? _url(dynamic value) =>
    value is String && value.isNotEmpty ? resolveCmsImageUrl(value) : null;

class CmsPost {
  const CmsPost({
    required this.id,
    required this.title,
    required this.description,
    this.contentHtml,
    this.module = 'articles',
    this.author = 'Former member',
    this.authorRole,
    this.createdAt,
    this.imageUrl,
    this.date,
    this.category,
    this.location,
    this.awardee,
    this.url,
    this.fileUrl,
    this.amount,
    this.academicYear,
    this.semester,
    this.viewCount,
    this.likeCount,
    this.likedByViewer,
  });
  final String? contentHtml;
  final int id;
  final String title, description, module, author;
  final String? authorRole,
      createdAt,
      imageUrl,
      date,
      category,
      location,
      awardee,
      url,
      fileUrl,
      amount,
      academicYear,
      semester;
  final int? viewCount, likeCount;
  final bool? likedByViewer;
  String get moduleLabel => switch (module) {
    'activities' => 'Activities',
    'achievements' => 'Achievements',
    'documents' => 'Documents',
    'liquidations' => 'Transparency',
    _ => 'Articles',
  };

  factory CmsPost.fromJson(Map<String, dynamic> json) => CmsPost(
    id: (json['id'] as num?)?.toInt() ?? 0,
    title: json['title'] as String? ?? 'Untitled',
    description: json['description'] as String? ?? '',
    contentHtml: json['content_html'] as String?,
    module: json['module'] as String? ?? 'articles',
    author: json['author'] as String? ?? 'Former member',
    authorRole: json['author_role'] as String?,
    createdAt: json['created_at'] as String?,
    imageUrl: _url(json['image_url']),
    date: json['date'] as String?,
    category: json['category'] as String?,
    location: json['location'] as String?,
    awardee: json['awardee'] as String?,
    url: json['url'] as String?,
    fileUrl: _url(json['file_url']),
    amount: json['amount']?.toString(),
    academicYear: json['academic_year'] as String?,
    semester: json['semester']?.toString(),
    viewCount: (json['view_count'] as num?)?.toInt(),
    likeCount: (json['like_count'] as num?)?.toInt(),
    likedByViewer:
        json['liked_by_viewer'] == true || json['liked_by_viewer'] == 1,
  );
}

List<CmsPost> _posts(dynamic value) => (value as List? ?? const [])
    .whereType<Map<String, dynamic>>()
    .map(CmsPost.fromJson)
    .toList();

class CmsOfficer {
  const CmsOfficer({required this.name, required this.position, this.photoUrl});
  final String name, position;
  final String? photoUrl;
  factory CmsOfficer.fromJson(Map<String, dynamic> json) => CmsOfficer(
    name: json['name'] as String? ?? '',
    position: json['position'] as String? ?? '',
    photoUrl: _url(json['photo_url']),
  );
}

List<CmsOfficer> _officers(dynamic value) => (value as List? ?? const [])
    .whereType<Map<String, dynamic>>()
    .map(CmsOfficer.fromJson)
    .toList();

class CmsSponsor {
  const CmsSponsor({
    required this.name,
    required this.description,
    this.logoUrl,
    this.websiteUrl,
  });
  final String name, description;
  final String? logoUrl, websiteUrl;
  factory CmsSponsor.fromJson(Map<String, dynamic> json) => CmsSponsor(
    name: json['name'] as String? ?? '',
    description: json['description'] as String? ?? '',
    logoUrl: _url(json['logo_url']),
    websiteUrl: json['website_url'] as String?,
  );
}

class CmsHome {
  const CmsHome({
    required this.articles,
    required this.activities,
    required this.achievements,
    this.officers = const [],
    this.sponsors = const [],
  });
  final List<CmsPost> articles, activities, achievements;
  final List<CmsOfficer> officers;
  final List<CmsSponsor> sponsors;
  factory CmsHome.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    return CmsHome(
      articles: _posts(data['articles']),
      activities: _posts(data['activities']),
      achievements: _posts(data['achievements']),
      officers: _officers(data['officers']),
      sponsors: (data['sponsors'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(CmsSponsor.fromJson)
          .toList(),
    );
  }
}

class CmsAbout {
  const CmsAbout({
    required this.academicYear,
    required this.officers,
    required this.history,
  });
  final String academicYear;
  final List<CmsOfficer> officers;
  final Map<String, List<CmsOfficer>> history;
  factory CmsAbout.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    final history = data['history'];
    return CmsAbout(
      academicYear: data['academic_year'] as String? ?? '',
      officers: _officers(data['officers']),
      history: history is Map<String, dynamic>
          ? history.map((key, value) => MapEntry(key, _officers(value)))
          : {},
    );
  }
}

class CmsPostPage {
  const CmsPostPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    this.filters = const {},
  });
  final List<CmsPost> items;
  final int currentPage, lastPage, total;
  final Map<String, List<String>> filters;
  bool get hasMore => currentPage < lastPage;
  CmsPostPage withItems(List<CmsPost> items) => CmsPostPage(
    items: items,
    currentPage: currentPage,
    lastPage: lastPage,
    total: total,
    filters: filters,
  );
  factory CmsPostPage.fromJson(Map<String, dynamic> json) {
    final meta = json['meta'] as Map<String, dynamic>? ?? const {};
    final items = _posts(json['data']);
    return CmsPostPage(
      items: items,
      currentPage: (meta['current_page'] as num?)?.toInt() ?? 1,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? 1,
      total: (meta['total'] as num?)?.toInt() ?? items.length,
      filters: meta['filters'] is Map<String, dynamic>
          ? (meta['filters'] as Map<String, dynamic>).map(
              (key, value) => MapEntry(
                key,
                (value as List).map((item) => item.toString()).toList(),
              ),
            )
          : {},
    );
  }
}

class CmsUnauthorized implements Exception {}

class CmsApi {
  CmsApi({http.Client? client, this.baseUrl})
    : _client = client ?? http.Client(),
      _customClient = client != null;
  static final CmsApi instance = CmsApi(baseUrl: cmsApiBaseUrl);
  final http.Client _client;
  final bool _customClient;
  bool get supportsWebsite => baseUrl != null || _customClient;
  final String? baseUrl;
  String? accessToken;
  String? Function()? sessionToken;
  String? get bearer => sessionToken?.call() ?? accessToken;
  Uri get _base => Uri.parse(
    '${(baseUrl ?? cmsApiBaseUrl).replaceFirst(RegExp(r'/$'), '')}/',
  );

  Map<String, String> headersForUrl(String url) {
    final uri = Uri.tryParse(url);
    if (bearer == null ||
        uri == null ||
        !uri.hasAuthority ||
        uri.origin != _base.origin ||
        !uri.path.startsWith('/storage/v1/object/authenticated/'))
      return {};
    return {'Authorization': 'Bearer $bearer', 'apikey': publishableKey};
  }

  Future<Map<String, dynamic>> _rpc(
    String name,
    Map<String, dynamic> args,
  ) async {
    final response = await _client
        .post(
          _base.resolve(name),
          headers: {
            'Content-Type': 'application/json',
            'apikey': publishableKey,
            'Authorization': 'Bearer ${bearer ?? publishableKey}',
          },
          body: jsonEncode(args),
        )
        .timeout(const Duration(seconds: 60));
    if (response.statusCode == 401) throw CmsUnauthorized();
    final value = response.bodyBytes.isEmpty
        ? null
        : jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode < 200 || response.statusCode >= 300)
      throw FormatException(
        value is Map
            ? value['message']?.toString() ?? 'Request failed.'
            : 'Request failed.',
      );
    return value is Map<String, dynamic> ? value : {};
  }

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String>? query,
  ]) async {
    final response = await _rpc('ssite_app_read', {
      'route': path,
      'params': query ?? {},
    });
    final data = response['data'];
    if (data is List) {
      for (final post in data.cast<_Row>()) {
        _decoratePost(post);
      }
    }
    if (data is Map) {
      for (final m in ['articles', 'activities', 'achievements']) {
        for (final post in _rows(data[m])) {
          _decoratePost(post);
        }
      }
      for (final officer in [
        ..._rows(data['officers']),
        for (final group in (data['history'] as Map? ?? {}).values)
          ..._rows(group),
      ]) {
        if (officer['photo'] != null)
          officer['photo_url'] = _photo(officer['photo']);
      }
      for (final sponsor in _rows(data['sponsors'])) {
        if (sponsor['logo'] != null)
          sponsor['logo_url'] = _photo(sponsor['logo']);
      }
    }
    return response;
  }

  Future<Map<String, dynamic>> currentUser() async {
    final u = (await _get('auth/me'))['user'] as _Row;
    if (u['avatar'] != null) u['avatar_url'] = _photo(u['avatar']);
    return u;
  }

  Future<Map<String, dynamic>> toolPage(
    String path,
    Map<String, String> filters,
  ) async => _toolScreen(path, await _get('tools/$path', filters), filters);
  Future<String> policyText() async =>
      'SSITE provides organization updates, activities and resources for the MCC community. Use materials for their intended school purposes and respect authorship and document restrictions. Publishing and administrative tools are limited to assigned roles. Keep your account secure and sign out on shared devices.\n\nSSITE uses your name, school email and Microsoft identifier to identify you. Microsoft handles your password. SSITE creates your account and saves your photo after you accept the terms and privacy policy. You can manage your photo in profile settings. Contact ssite@gmail.com about content, account access, corrections or removal.';
  Future<Map<String, dynamic>> sendAction(
    String path,
    Map<String, dynamic> data,
  ) async {
    final values =
        data.containsKey('attachment') || data.containsKey('draft_id')
        ? await _upload(path, data)
        : data;
    final result = await _rpc('ssite_app_write', {
      'route': path,
      'body': values,
    });
    if (path.startsWith('tools/') || path == 'profile/complete')
      unawaited(cleanRetiredFiles().catchError((Object _) {}));
    return result;
  }

  Future<CmsPostPage> discoverPage({
    String type = 'all',
    String query = '',
    String sort = 'recent',
    String period = '',
    String category = '',
    int page = 1,
    bool includeOptions = true,
  }) async => CmsPostPage.fromJson(
    await _get('discover', {
      'feed': '1',
      'type': type,
      if (query.isNotEmpty) 'q': query,
      if (period.isNotEmpty) 'period': period,
      if (category.isNotEmpty) 'category': category,
      if (!includeOptions) 'facets': '0',
      'sort': sort,
      'page': '$page',
    }),
  );

  Future<CmsHome> home() async => CmsHome.fromJson(await _get('home'));
  Future<CmsAbout> about() async => CmsAbout.fromJson(await _get('about'));
  Future<CmsPostPage> postsPage(
    String module, {
    String query = '',
    String sort = 'recent',
    int page = 1,
    Map<String, String> filters = const {},
    bool includeOptions = true,
  }) async => CmsPostPage.fromJson(
    await _get(module, {
      if (query.trim().isNotEmpty) 'q': query.trim(),
      'sort': sort,
      'page': '$page',
      'per_page': '10',
      if (!includeOptions) 'facets': '0',
      ...filters,
    }),
  );
  Future<List<CmsPost>> posts(String module, {String query = ''}) async =>
      (await postsPage(module, query: query)).items;
}
