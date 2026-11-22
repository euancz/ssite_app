# Run the mobile service and Flutter client

Use the Dart and Flutter SDK versions specified in the two pubspec files. The Dart service needs network access to the existing PostgreSQL database, Microsoft identity services and the configured media storage.

## Local service

From the `ssiteapp` directory in PowerShell:

```powershell
cd backend
dart pub get
$env:SSITE_CONFIG_FILE = (Resolve-Path ../../SSITECMS/.env).Path
$env:MOBILE_ORIGIN = 'http://localhost:8001'
dart run bin/server.dart
```

The configuration file supplies database, storage and Microsoft credentials. The Laravel process can be stopped. The health endpoint at `http://localhost:8001/up` checks database connectivity. For local filesystem media, set `MOBILE_STORAGE_ROOT` to the absolute path of the CMS's `storage/app` directory. For Supabase media, use the existing public and private S3 bucket settings.

Register the mobile service's exact **Web** redirect URI in the Microsoft Entra application. For the example above, it is `http://localhost:8001/auth/microsoft/callback`. Keep the existing website callback registered. The service exchanges the Microsoft authorization code, checks the school domain and issues a single-use code bound to the Flutter client's verifier.

## Run Flutter

For a USB-connected Android device or emulator, forward its localhost port to the development machine. From `ssiteapp`, in a second terminal:

```powershell
adb reverse tcp:8001 tcp:8001
flutter pub get
flutter run --dart-define=SSITE_BACKEND_URL=http://localhost:8001
```

A physical iPhone or an untethered Android phone needs a reachable backend URL. Set `MOBILE_ORIGIN` and `SSITE_BACKEND_URL` to the same HTTPS origin and register that origin's Microsoft callback. For a Flutter web preview, also set `SSITE_WEB_ORIGINS` to the exact Flutter origin. API and attachment requests use the configured mobile service. Source links shared with another reader use the website's `APP_URL`.

## Independent deployment

Deploy the contents of `backend/` to a Dart-capable host. Provide server-side PostgreSQL settings (`DB_HOST`, `DB_PORT`, `DB_DATABASE`, `DB_USERNAME`, `DB_PASSWORD`, `DB_SSLMODE`), `MICROSOFT_CLIENT_ID`, `MICROSOFT_CLIENT_SECRET`, `MICROSOFT_TENANT_ID`, `MOBILE_ORIGIN` and the same media configuration used by the website. Environment variables override values in the optional configuration file. Set `MOBILE_BIND` and `PORT` for the hosting environment. Terminate HTTPS at the service's public origin. The client only needs that origin.

The CMS migrations own the shared schema. The retirement migration drops the former publication index and its dependent read policies. Earlier read-only app releases require an update. Original documents, posts and media use their existing locations.

## Verify

```powershell
flutter analyze --no-pub lib test
flutter test --no-pub
cd backend
dart analyze
dart test
```

Set `SSITE_TEST_POSTGRES=1` alongside the server connection settings to include the PostgreSQL integration test. It uses connection-local temporary tables and a temporary attachment directory.
