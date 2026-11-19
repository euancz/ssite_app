import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ssiteapp/services/supabase_feed.dart';

Future<SupabaseClient> signedInClient(http.Client httpClient) async {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'publishable-test-key',
    httpClient: httpClient,
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  );
  final token =
      '${base64Url.encode(utf8.encode('{"alg":"HS256"}'))}.'
      '${base64Url.encode(utf8.encode(jsonEncode({'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600})))}.signature';
  await client.auth.setInitialSession(
    jsonEncode({
      'access_token': token,
      'refresh_token': 'test-refresh',
      'token_type': 'bearer',
      'user': {
        'id': '00000000-0000-0000-0000-000000000001',
        'email': 'student@mcc.edu.ph',
        'app_metadata': {'provider': 'azure'},
        'user_metadata': {},
        'aud': 'authenticated',
        'created_at': '2026-01-01T00:00:00Z',
      },
    }),
  );
  return client;
}

void main() {
  test('distributed app queries cloud feed and signs private files', () async {
    final client = await signedInClient(
      MockClient((request) async {
        expect(request.url.host, 'example.supabase.co');
        if (request.url.path.endsWith('/rpc/mobile_reader_allowed')) {
          return http.Response(
            'true',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.url.path.contains('/storage/v1/object/sign/')) {
          expect(
            request.url.path,
            '/storage/v1/object/sign/ssite-mobile/published/report.pdf',
          );
          return http.Response(
            '{"signedURL":"/object/sign/ssite-mobile/published/report.pdf?token=signed"}',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }
        expect(request.url.path, '/rest/v1/mobile_publications');
        expect(request.url.queryParameters['module'], 'eq.articles');
        expect(request.url.queryParameters['search_text'], 'ilike.%Published%');
        expect(request.url.queryParameters['offset'], '10');
        expect(
          request.url.queryParameters['order'],
          'title.asc.nullslast,record_id.asc.nullslast',
        );
        return http.Response(
          jsonEncode([
            {
              'payload': {
                'id': 7,
                'title': 'Published',
                'description': 'Shared from website',
                'file_path': 'published/report.pdf',
              },
            },
          ]),
          200,
          request: request,
          headers: {
            'content-range': '10-10/11',
            'content-type': 'application/json',
          },
        );
      }),
    );
    final result = await SupabaseFeed(
      client,
    ).get('articles', {'q': 'Published', 'page': '2', 'sort': 'title'});
    expect(result['meta']['total'], 11);
    expect(
      result['data'][0]['file_url'],
      contains('example.supabase.co/storage/v1/object/sign/'),
    );
    expect(result['data'][0].containsKey('file_path'), isFalse);
    await client.dispose();
  });

  test('rejected cloud identity cannot read published records', () async {
    final client = await signedInClient(
      MockClient((request) async {
        expect(request.url.path, '/rest/v1/rpc/mobile_reader_allowed');
        return http.Response(
          'false',
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    await expectLater(
      SupabaseFeed(client).get('home', {}),
      throwsA(isA<AuthException>()),
    );
    await client.dispose();
  });

  test('combined Discover searches and pages all three story modules', () async {
    final client = await signedInClient(
      MockClient((request) async {
        final params = request.url.queryParameters;
        const headers = {'content-type': 'application/json'};
        if (request.url.path.endsWith('/rpc/mobile_reader_allowed')) {
          return http.Response('true', 200, request: request, headers: headers);
        }
        expect(request.url.path, '/rest/v1/mobile_publications');
        expect(params['module'], 'in.("articles","activities","achievements")');
        expect(params['search_text'], 'ilike.%campus%');
        expect(params['sort_date'], startsWith('gte.'));
        expect(params['offset'], '9');
        expect(params['limit'], '9');
        return http.Response(
          '[{"payload":{"id":2,"module":"activities","title":"Campus event"}}]',
          200,
          request: request,
          headers: {...headers, 'content-range': '9-9/10'},
        );
      }),
    );
    try {
      final result = await SupabaseFeed(client).get('discover', {
        'feed': '1',
        'q': 'campus',
        'period': 'week',
        'page': '2',
      });
      expect(result['data'][0]['module'], 'activities');
      expect(result['meta']['last_page'], 2);
    } finally {
      await client.dispose();
    }
  });

  test(
    'Transparency facets and filters use the report date and event title',
    () async {
      final client = await signedInClient(
        MockClient((request) async {
          final params = request.url.queryParameters;
          const headers = {'content-type': 'application/json'};
          if (request.url.path.endsWith('/rpc/mobile_reader_allowed')) {
            return http.Response(
              'true',
              200,
              request: request,
              headers: headers,
            );
          }
          expect(request.url.path, '/rest/v1/mobile_publications');
          expect(params['module'], 'eq.liquidations');
          if (params['select'] == 'title,year:payload->>date') {
            return http.Response(
              '[{"title":"Campus event","year":"2026-02-07"},{"title":"Assembly","year":"2025-11-19"}]',
              200,
              request: request,
              headers: headers,
            );
          }
          expect(params['title'], 'eq.Campus event');
          expect(params['semester'], 'eq.2');
          expect(request.url.queryParametersAll['payload->>date'], [
            'gte.2026-01-01',
            'lt.2027-01-01',
          ]);
          expect(params['order'], startsWith('payload->>date.desc'));
          return http.Response(
            '[{"payload":{"id":1,"title":"Campus event","date":"2026-02-07"}}]',
            200,
            request: request,
            headers: {...headers, 'content-range': '0-0/1'},
          );
        }),
      );
      try {
        final result = await SupabaseFeed(client).get('liquidations', {
          'event': 'Campus event',
          'year': '2026',
          'semester': '2',
          'sort': 'report_latest',
        });
        expect(result['meta']['filters']['year'], ['2026', '2025']);
        expect(result['meta']['filters']['event'], [
          'Assembly',
          'Campus event',
        ]);
      } finally {
        await client.dispose();
      }
    },
  );
}
