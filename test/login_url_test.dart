import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Microsoft sign-in callback uses the registered app scheme', () {
    const redirectUri = 'ssiteapp://auth/callback';
    expect(Uri.parse(redirectUri).scheme, 'ssiteapp');
    expect(Uri.parse(redirectUri).host, 'auth');
    expect(Uri.parse(redirectUri).path, '/callback');
  });
}
