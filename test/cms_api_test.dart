import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ssiteapp/services/cms_api.dart';

void main() {
  test('links Microsoft through the hosted verification RPC', () async {
    final api = CmsApi(
      baseUrl: 'https://app.example/rest/v1/rpc',
      client: MockClient((req) async {
        expect(req.url.path, '/rest/v1/rpc/ssite_app_link');
        expect(req.headers['Authorization'], 'Bearer session');
        expect(jsonDecode(req.body), {'provider_token': 'graph-token'});
        return http.Response('', 204);
      }),
    )..accessToken = 'session';
    await api.linkMicrosoft('graph-token');
  });

  test('keeps server-rendered rich article content separate from excerpts', () {
    final post = CmsPost.fromJson({
      'id': 1,
      'title': 'Rich',
      'description': 'Bold',
      'content_html': '<p><strong>Bold</strong></p>',
    });
    expect(post.description, 'Bold');
    expect(post.contentHtml, '<p><strong>Bold</strong></p>');
  });

  test('passes session, search, sort and pagination to the CMS', () async {
    final api = CmsApi(
      baseUrl: 'https://cms.example/api/mobile/v1',
      client: MockClient((request) async {
        expect(request.url.path, '/api/mobile/v1/ssite_app_read');
        final rpc = jsonDecode(request.body);
        expect(rpc['route'], 'documents');
        expect(request.headers['Authorization'], 'Bearer session');
        expect(rpc['params']['q'], 'Minutes');
        expect(rpc['params']['sort'], 'title');
        expect(rpc['params']['page'], '2');
        expect(rpc['params']['semester'], '1');
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
        'https://cms.example/storage/v1/object/authenticated/files/articles/1',
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
    'only private files on the configured Supabase origin receive the session',
    () {
      final api = CmsApi(baseUrl: 'https://app.example/rest/v1/rpc')
        ..accessToken = 'test';
      expect(
        api.headersForUrl(
          'https://app.example/storage/v1/object/authenticated/bucket/file.pdf',
        )['Authorization'],
        'Bearer test',
      );
      expect(api.headersForUrl('https://elsewhere.example/photo'), isEmpty);
      expect(
        api.headersForUrl(
          'https://app.example/storage/v1/object/public/bucket/photo',
        ),
        isEmpty,
      );
    },
  );
}
