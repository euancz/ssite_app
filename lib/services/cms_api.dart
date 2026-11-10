import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:http/http.dart' as http;

const _configuredCmsApiBaseUrl = String.fromEnvironment('SSITE_API_BASE_URL');
const _configuredCmsWebBaseUrl = String.fromEnvironment('SSITE_WEB_BASE_URL');

String get cmsApiBaseUrl {
  if (_configuredCmsApiBaseUrl.isNotEmpty) {
    return _configuredCmsApiBaseUrl.replaceFirst(RegExp(r'/$'), '');
  }
  if (_configuredCmsWebBaseUrl.isNotEmpty) {
    return '$cmsWebBaseUrl/api/mobile/v1';
  }
  final host = kIsWeb
      ? Uri.base.host
      : defaultTargetPlatform == TargetPlatform.android
      ? '10.0.2.2'
      : 'localhost';
  final scheme = kIsWeb ? Uri.base.scheme : 'http';
  return '$scheme://$host:8000/api/mobile/v1';
}

String get cmsWebBaseUrl {
  if (_configuredCmsWebBaseUrl.isNotEmpty) {
    return _configuredCmsWebBaseUrl.replaceFirst(RegExp(r'/$'), '');
  }
  final uri = Uri.parse(cmsApiBaseUrl);
  return uri
      .replace(
        path: uri.path.replaceFirst(RegExp(r'/api/mobile/v1/?$'), ''),
        query: null,
        fragment: null,
      )
      .toString()
      .replaceFirst(RegExp(r'/$'), '');
}

Uri cmsMicrosoftLoginUri({Uri? browserUri}) {
  final uri = Uri.parse('$cmsWebBaseUrl/auth/microsoft/mobile');
  return browserUri == null
      ? uri
      : uri.replace(
          queryParameters: {
            'return_url': Uri(
              scheme: browserUri.scheme,
              host: browserUri.host,
              port: browserUri.hasPort ? browserUri.port : null,
              path: browserUri.path,
            ).toString(),
          },
        );
}

/// Preserve asset paths while replacing an unreachable Laravel localhost origin.
String resolveCmsImageUrl(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null) return value;
  if (!uri.hasAuthority) {
    return Uri.parse('$cmsWebBaseUrl/').resolve(value).toString();
  }
  const localHosts = {'localhost', '127.0.0.1', '0.0.0.0', '::1'};
  if (!localHosts.contains(uri.host.toLowerCase())) return value;
  final base = Uri.parse(cmsApiBaseUrl);
  return uri
      .replace(
        scheme: base.scheme,
        host: base.host,
        port: base.hasPort ? base.port : null,
      )
      .toString();
}

String? _url(dynamic value) =>
    value is String && value.isNotEmpty ? resolveCmsImageUrl(value) : null;

class CmsPost {
  const CmsPost({
    required this.id,
    required this.title,
    required this.description,
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
  });
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
    module: json['module'] as String? ?? 'articles',
    author: json['author'] as String? ?? 'Former member',
    authorRole: json['author_role'] as String?,
    createdAt: json['created_at'] as String?,
    imageUrl: _url(json['image_url']),
    date: json['date'] as String?,
    category: json['category'] as String?,
    location: json['location'] as String?,
    awardee: json['awardee'] as String?,
    url: _url(json['url']),
    fileUrl: _url(json['file_url']),
    amount: json['amount']?.toString(),
    academicYear: json['academic_year'] as String?,
    semester: json['semester']?.toString(),
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

class CmsHome {
  const CmsHome({
    required this.articles,
    required this.activities,
    required this.achievements,
    this.officers = const [],
  });
  final List<CmsPost> articles, activities, achievements;
  final List<CmsOfficer> officers;
  factory CmsHome.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>? ?? const {};
    return CmsHome(
      articles: _posts(data['articles']),
      activities: _posts(data['activities']),
      achievements: _posts(data['achievements']),
      officers: _officers(data['officers']),
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
    : _client = client ?? http.Client();
  static final CmsApi instance = CmsApi();
  final http.Client _client;
  final String? baseUrl;
  String? accessToken;
  Uri get _base {
    final url = baseUrl ?? cmsApiBaseUrl;
    return Uri.parse(url.endsWith('/') ? url : '$url/');
  }

  // Never forward the session token to external content/image hosts.
  Map<String, String> headersForUrl(String url) {
    final uri = Uri.tryParse(url);
    return accessToken != null &&
            uri != null &&
            uri.hasAuthority &&
            uri.origin == _base.origin
        ? {'Authorization': 'Bearer $accessToken'}
        : const {};
  }

  Map<String, String> get imageHeaders => headersForUrl(_base.toString());

  Future<Map<String, dynamic>> _get(
    String path, [
    Map<String, String>? query,
  ]) async {
    final uri = _base.resolve(path).replace(queryParameters: query);
    final response = await _client
        .get(uri, headers: {'Accept': 'application/json', ...imageHeaders})
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 401) throw CmsUnauthorized();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw http.ClientException('CMS returned ${response.statusCode}', uri);
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> currentUser() async =>
      (await _get('auth/me'))['user'] as Map<String, dynamic>;

  Future<Uri> openWorkspaceSession() async {
    final uri = _base.resolve('workspace/session');
    final response = await _client
        .post(uri, headers: {'Accept': 'application/json', ...imageHeaders})
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 401) throw CmsUnauthorized();
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Workspace is unavailable for this account.',
        uri,
      );
    }
    final url =
        (jsonDecode(response.body) as Map<String, dynamic>)['url'] as String;
    final target = Uri.parse(resolveCmsImageUrl(url));
    if (target.origin != _base.origin) {
      throw http.ClientException('Invalid workspace address.', uri);
    }
    return target;
  }

  Future<CmsHome> home() async => CmsHome.fromJson(await _get('home'));
  Future<CmsAbout> about() async => CmsAbout.fromJson(await _get('about'));
  Future<CmsPostPage> postsPage(
    String module, {
    String query = '',
    String sort = 'recent',
    int page = 1,
    Map<String, String> filters = const {},
  }) async => CmsPostPage.fromJson(
    await _get(module, {
      if (query.trim().isNotEmpty) 'q': query.trim(),
      'sort': sort,
      'page': '$page',
      'per_page': '10',
      ...filters,
    }),
  );
  Future<List<CmsPost>> posts(String module, {String query = ''}) async =>
      (await postsPage(module, query: query)).items;

  Future<String> exchangeLoginCode(String code) async {
    final uri = _base.resolve('auth/exchange');
    final response = await _client
        .post(
          uri,
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({'code': code}),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Microsoft sign-in could not be verified.',
        uri,
      );
    }
    return (jsonDecode(response.body) as Map<String, dynamic>)['token']
        as String;
  }

  Future<bool> validateAccessToken(String token) async {
    final uri = _base.resolve('auth/me');
    final response = await _client
        .get(
          uri,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode == 401) return false;
    if (response.statusCode != 200) {
      throw http.ClientException('Could not verify the saved session.', uri);
    }
    return true;
  }

  Future<void> revokeAccessToken() async {
    if (accessToken == null) return;
    await _client
        .post(
          _base.resolve('auth/logout'),
          headers: {'Accept': 'application/json', ...imageHeaders},
        )
        .timeout(const Duration(seconds: 20));
  }
}
