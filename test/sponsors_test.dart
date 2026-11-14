import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ssiteapp/services/cms_api.dart';
import 'package:ssiteapp/services/supabase_feed.dart';

import 'supabase_feed_test.dart' show signedInClient;

void main() {
  test('home reads sponsor fields and supports older responses', () {
    final home = CmsHome.fromJson({
      'data': {
        'sponsors': [
          {
            'name': 'Community Partner',
            'description': 'Supporting students.',
            'website_url': 'https://partner.example',
            'logo_url': 'https://cdn.example/logo.png',
          },
          {'name': 'Partner without logo', 'description': 'Thank you.'},
        ],
      },
    });
    expect(home.sponsors.first.name, 'Community Partner');
    expect(home.sponsors.first.description, 'Supporting students.');
    expect(home.sponsors.first.websiteUrl, 'https://partner.example');
    expect(home.sponsors.first.logoUrl, 'https://cdn.example/logo.png');
    expect(home.sponsors.last.logoUrl, isNull);
    expect(home.sponsors.last.websiteUrl, isNull);
    expect(CmsHome.fromJson({'data': <String, dynamic>{}}).sponsors, isEmpty);
  });

  test('Supabase home reads ordered sponsors and signs their logos', () async {
    var requestedSponsors = false;
    final client = await signedInClient(
      MockClient((request) async {
        Object body = <Object>[];
        if (request.url.path.endsWith('/rpc/mobile_reader_allowed')) {
          body = true;
        } else if (request.url.path.contains('/storage/v1/object/sign/')) {
          expect(request.url.path, endsWith('/published/logo.png'));
          body = {
            'signedURL':
                '/object/sign/ssite-mobile/published/logo.png?token=signed',
          };
        } else if (request.url.queryParameters['module'] == 'eq.sponsors') {
          requestedSponsors = true;
          expect(
            request.url.queryParameters['order'],
            'sort_order.asc.nullslast,title.asc.nullslast,record_id.asc.nullslast',
          );
          body = [
            {
              'payload': {
                'name': 'Shared Partner',
                'description': 'Available in the app.',
                'logo_path': 'published/logo.png',
              },
            },
          ];
        }
        return http.Response(
          jsonEncode(body),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    try {
      final home = CmsHome.fromJson(await SupabaseFeed(client).get('home', {}));
      expect(requestedSponsors, isTrue);
      expect(home.sponsors.single.name, 'Shared Partner');
      expect(home.sponsors.single.logoUrl, contains('token=signed'));
    } finally {
      await client.dispose();
    }
  });
}
