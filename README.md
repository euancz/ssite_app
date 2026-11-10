# SSITE Mobile App

Flutter mobile client for the SSITE CMS. Articles, activities, achievements, published documents, transparency reports, and officer lists are read from Laravel; the CMS remains the source of truth for published content.

## Local setup

1. Start the Laravel CMS on the port used by its Microsoft callback:

   ```powershell
   cd SSITECMS
   php artisan serve --host=0.0.0.0 --port=8000
   ```

2. From `ssiteapp`, run `flutter run -d chrome` for the browser or `flutter run` for an Android emulator. The default CMS URL is `http://localhost:8000` in the browser and `http://10.0.2.2:8000` on Android. Browser sign-in uses the same tab and returns to the Flutter app; native sign-in returns through `ssiteapp://`.

   For XAMPP on port 80, override the URL explicitly:

   ```powershell
   flutter run --dart-define=SSITE_WEB_BASE_URL=http://localhost/elective/SSITECMS/public
   ```

   Use `10.0.2.2` instead of `localhost` for an Android emulator. For a physical phone, use the computer's LAN address. You can also supply `SSITE_API_BASE_URL` when the API is hosted separately.

3. Set Laravel's `APP_URL` and `MICROSOFT_REDIRECT_URI` to the CMS address reachable by the sign-in browser. The current local callback is `http://localhost:8000/auth/microsoft/callback`; register that exact URL in Microsoft. For emulator/phone sign-in, use a registered callback address reachable from that device.

4. Local Laravel environments accept localhost browser return ports automatically. For a deployed Flutter web app, set `SSITE_WEB_ORIGINS=https://app.example.com` in Laravel (comma-separated exact origins, including ports when applicable), and launch/build Flutter with `--dart-define=SSITE_WEB_BASE_URL=https://cms.example.com`. Clear Laravel's config cache after changing these settings.

The app requires Microsoft sign-in before opening the content tabs. Laravel issues a short-lived one-time sign-in code and a revocable 30-day app token; mobile content and image requests require that token. Sign out from the account menu to revoke the app token.

The API lives in `SSITECMS/routes/api.php`; the app's API client, sign-in gate, and login screen are in `lib/services/cms_api.dart`, `lib/app_gate.dart`, and `lib/screens/auth/login_screen.dart`.

## Native CMS screens

The app follows the CMS navigation: Home, Discover, Transparency, Documents, and About us. Discover switches between Articles, Activities, and Achievements. Feeds support server-side search, sorting, pagination, pull-to-refresh, full-post reading, image zoom, and copying CMS post links. Documents include semester, category, and academic-year filters where available.

The public navigation uses five persistent bottom tabs below 768px and a top tab row at larger widths, matching the CMS mobile web navigation. Articles, Activities, and Achievements remain inside Discover.

Workspace access is read from the CMS `/auth/me` capability response. Authorized accounts see a Workspace shortcut in the header and account menu. On Android, iOS, and macOS it opens the existing responsive CMS workspace inside an embedded WebView, preserving every existing sidebar destination, form, and role policy. Browser and unsupported desktop builds open the CMS workspace in the browser. Students and officers without content permissions do not receive workspace access. Refresh rechecks the current account permissions.

Opening Workspace exchanges a one-minute, single-use code for a normal CMS web session; the long-lived mobile token never enters a browser URL. Both code issuance and redemption check the current account capabilities. The WebView clears its cookies when opened and closed to isolate app accounts. A full restart of the Flutter application is required after adding the WebView plugin.
Published PDF requests use the mobile bearer token, the existing file policies, and private range responses. PDFs open in the native viewer. Pending and archived records are excluded from mobile listings and file endpoints.

Section banners use a taller mobile layout with readable Poppins text below 768px, matching the responsive CMS. Home and desktop banners load the CMS SVG artwork with bundled offline fallbacks. The mobile tab bar shares the header background color. The Poppins and Pixelify Sans fonts are bundled under assets/fonts with their licenses. If the CMS hero designs change, refresh the bundled copies in assets/heroes for offline consistency.

The default CMS URL targets Laravel on port 8000 from an Android emulator. A physical phone needs SSITE_API_BASE_URL set to the development computer's LAN address; localhost on a phone points to the phone itself. The API and Microsoft sign-in callback must both be reachable from that device.

## Verification

Run flutter analyze --no-pub and flutter test --no-pub for native source and widget checks. The CMS integration tests are in tests/Feature/MobileApiTest.php and run with php artisan test --filter=MobileApiTest from SSITECMS.
