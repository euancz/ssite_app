import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ssiteapp/services/member_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'uses the Microsoft token for the photo and caches bytes per account',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final photos = MicrosoftProfilePhoto(
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            r'https://graph.microsoft.com/v1.0/me/photos/96x96/$value',
          );
          expect(request.headers['Authorization'], 'Bearer microsoft-access');
          expect(request.followRedirects, isFalse);
          return http.Response.bytes(
            [255, 216, 255, 217],
            200,
            headers: {'content-type': 'image/jpeg'},
          );
        }),
      );
      addTearDown(photos.dispose);
      const user = User(
        id: 'account-1',
        appMetadata: {'provider': 'azure'},
        userMetadata: {'full_name': 'Ari Reyes'},
        aud: 'authenticated',
        createdAt: '',
        email: 'ari@mcc.edu.ph',
      );
      final session = Session(
        accessToken: 'supabase-token',
        tokenType: 'bearer',
        providerToken: 'microsoft-access',
        user: user,
      );
      final profile = MemberProfile.fromMicrosoft(
        user,
        photo: await photos.load(session),
      );
      expect(profile.name, 'Ari Reyes');
      expect(profile.email, 'ari@mcc.edu.ph');
      expect(profile.photoBytes, [255, 216, 255, 217]);
      expect(
        await photos.load(
          Session(
            accessToken: 'refreshed-supabase-token',
            tokenType: 'bearer',
            user: user,
          ),
        ),
        profile.photoBytes,
      );
    },
  );
}
