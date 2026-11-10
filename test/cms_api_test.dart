import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ssiteapp/services/cms_api.dart';

void main() {
  test('passes session, search, sort and pagination to the CMS', () async {
    final api = CmsApi(
      baseUrl: 'https://cms.example/api/mobile/v1',
      client: MockClient((request) async {
        expect(request.url.path, '/api/mobile/v1/documents');
        expect(request.headers['Authorization'], 'Bearer session');
        expect(request.url.queryParameters['q'], 'Minutes');
        expect(request.url.queryParameters['sort'], 'title');
        expect(request.url.queryParameters['page'], '2');
        expect(request.url.queryParameters['semester'], '1');
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 1,
                'title': 'Minutes',
                'module': 'documents',
                'description': 'Official record',
              },
            ],
            'meta': {'current_page': 2, 'last_page': 3, 'total': 21},
          }),
          200,
        );
      }),
    )..accessToken = 'session';
    final page = await api.postsPage(
      'documents',
      query: ' Minutes ',
      sort: 'title',
      page: 2,
      filters: const {'semester': '1'},
    );
    expect(page.items.single.title, 'Minutes');
    expect(page.items.single.moduleLabel, 'Documents');
    expect(page.currentPage, 2);
    expect(page.hasMore, isTrue);
  });

  test('never attaches the session to an external asset host', () {
    final api = CmsApi(baseUrl: 'https://cms.example/api/mobile/v1')
      ..accessToken = 'secret';
    expect(api.headersForUrl('https://cdn.example/image.jpg'), isEmpty);
    expect(
      api.headersForUrl(
        'https://cms.example/api/mobile/v1/media/articles/1',
      )['Authorization'],
      'Bearer secret',
    );
  });

  test('reports expired sessions distinctly from connection errors', () async {
    final api = CmsApi(
      client: MockClient((_) async => http.Response('{}', 401)),
    );
    await expectLater(api.home(), throwsA(isA<CmsUnauthorized>()));
  });

  test('reads officers and leadership history from CMS data', () {
    final about = CmsAbout.fromJson({
      'data': {
        'academic_year': '2026-2027',
        'officers': [
          {'name': 'CMS Officer', 'position': 'President'},
        ],
        'history': {
          '2025-2026': [
            {'name': 'Past Officer', 'position': 'Secretary'},
          ],
        },
      },
    });
    expect(about.officers.single.name, 'CMS Officer');
    expect(about.history['2025-2026']!.single.position, 'Secretary');
  });

  test(
    'rewrites localhost media and document URLs to the reachable API host',
    () {
      final base = Uri.parse(cmsApiBaseUrl);
      final resolved = Uri.parse(
        resolveCmsImageUrl(
          'http://localhost/elective/SSITECMS/public/api/mobile/v1/files/documents/1',
        ),
      );
      expect(resolved.host, base.host);
      expect(resolved.port, base.port);
      expect(
        resolved.path,
        '/elective/SSITECMS/public/api/mobile/v1/files/documents/1',
      );
    },
  );
}
