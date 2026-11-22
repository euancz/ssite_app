import 'package:flutter_test/flutter_test.dart';
import 'package:ssiteapp/services/cms_api.dart';

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
}
