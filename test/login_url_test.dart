import 'package:flutter_test/flutter_test.dart';
import 'package:ssiteapp/services/cms_api.dart';

void main() {
  test('native sign-in uses the CMS website without a browser return URL', () {
    final uri = cmsMicrosoftLoginUri();
    expect(uri.toString(), '$cmsWebBaseUrl/auth/microsoft/mobile');
    expect(uri.hasQuery, isFalse);
  });

  test('browser sign-in keeps the Flutter origin, port and deployment path', () {
    final uri = cmsMicrosoftLoginUri(
      browserUri: Uri.parse('http://localhost:54321/ssite/?old=value#/login'),
    );
    expect(uri.queryParameters['return_url'], 'http://localhost:54321/ssite/');
    expect(uri.path, '${Uri.parse(cmsWebBaseUrl).path}/auth/microsoft/mobile');
  });
}
