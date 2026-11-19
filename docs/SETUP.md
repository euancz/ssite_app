# SSITE app setup

## Shareable Android app

The default Android app signs in through Supabase over HTTPS and reads synced
SSITE content from Supabase. It needs an internet connection and an MCC
Microsoft account. Recipients can use it while the CMS computer is off.

Tap the account avatar to see your name, school email, and Microsoft 365
profile photo. The app requests the delegated Microsoft Graph `User.Read`
permission for the photo. An existing session may need a fresh Microsoft
sign-in to grant this permission. Accounts with no accessible photo display
initials. The app is read-only. Use the website for publishing and reviews.

## Optional direct CMS connection

The direct CMS connection uses the website account's name and photo and
reads published content through the mobile API.

With the updated `SSITECMS` running, start the app from `ssiteapp`:

```powershell
flutter run --dart-define=SSITE_WEB_BASE_URL=https://your-cms-host
```

Use a CMS URL reachable from the phone. Set the CMS `APP_URL` and Microsoft
callback to its reachable address and register the exact callback with
Microsoft. For browser previews, add the Flutter origin to
`SSITE_WEB_ORIGINS` and permit it in the CMS API's CORS configuration.

## Published-content access through Supabase

Use the default Supabase configuration for distribution. A CMS URL, USB
connection, and PHP server are unnecessary for browsing published content.

## How website information appears in the app

1. Start your website as usual and sign in as an authorized officer/adviser.
2. Create or edit an article, activity, achievement, document, transparency report, or officer entry.
3. Submit and approve the post using the existing review workflow. Pending, rejected, and archived content is excluded.
4. The website saves a safe copy in Supabase `mobile_publications` and copies attachments into the private `ssite-mobile` bucket. With `SSITE_MOBILE_SYNC=true`, this happens automatically when records are saved.
5. In the app, pull down to refresh or choose Account > Refresh. Open Discover for articles/activities/achievements, Documents for PDFs, Transparency for reports, and About us for officers.

Recipients need internet for published content and can refresh to see updates. The Supabase mode includes global search and browsing for synced publications while your computer is off.

## One-time backend setup

The current Supabase project is configured in `lib/main.dart`. Public project URL and publishable key belong in the app; database passwords, S3 secrets, and service-role keys must stay on the website.

The website must use the SAME Supabase PostgreSQL database as the app's project. In `SSITECMS/.env`, retain your existing `DB_*` values and configure:

```dotenv
SSITE_MOBILE_SYNC=true
SUPABASE_MOBILE_BUCKET=ssite-mobile
SUPABASE_S3_ENDPOINT=https://YOUR_PROJECT_REF.storage.supabase.co/storage/v1/s3
SUPABASE_S3_REGION=YOUR_PROJECT_REGION
SUPABASE_S3_ACCESS_KEY_ID=YOUR_S3_ACCESS_KEY
SUPABASE_S3_SECRET_ACCESS_KEY=YOUR_S3_SECRET
```

S3 credentials come from Supabase Storage settings. Originals can remain on your computer; the mobile disk uploads separate copies. `MEDIA_STORAGE` does not need to change. Retain local originals, since the local website still uses them.

From `SSITECMS`:

```powershell
php artisan config:clear
php artisan migrate --path=database/migrations/2026_11_14_000001_create_mobile_publications.php
php artisan migrate --path=database/migrations/2026_11_14_000002_create_sponsors_table.php
php artisan migrate --path=database/migrations/2026_11_20_000001_allow_published_sponsors_in_mobile_feed.php
php artisan mobile:sync
```

The migration creates the private bucket and read-only app permissions. It does not open private CMS tables to app users. The initial sync publishes existing approved content. Run `php artisan mobile:sync` again after importing data, bulk database edits, changing author names, or recovering from an upload failure. Normal website saves sync automatically. Do not enable the flag on a different/local database: the app needs the shared Supabase database.

In Supabase Dashboard > Authentication > Providers > Azure, enable Microsoft with your Microsoft application credentials. Microsoft must have this Web redirect URI:

```text
https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback
```

In Supabase Authentication > URL Configuration > Redirect URLs, allow:

```text
ssiteapp://auth/callback
http://localhost:5173
```

The first address is for Android APKs; the second is for the optional browser preview. The native callback is already registered in AndroidManifest.xml. Microsoft sign-in requires internet but never calls your local Laravel server. Configure the Azure tenant for your school. Database policies independently require the Azure provider and `mcc.edu.ph` email domain.

## Run and build

From `ssiteapp`:

```powershell
flutter pub get
flutter run
flutter build apk --release
```

Share `build/app/outputs/flutter-apk/app-release.apk`. The project currently uses the debug signing configuration for release builds; keep the signing key consistent for updates and configure your own release keystore for long-term distribution.

For another Supabase project:

```powershell
flutter build apk --release --dart-define=SSITE_SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SSITE_SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY
```

For a browser preview:

```powershell
flutter run -d chrome --web-port=5173
```

The default app uses Supabase. Set `SSITE_WEB_BASE_URL` or `SSITE_API_BASE_URL` to select the CMS connection.

## Confirm it works before sharing

1. Approve a recognizable post on the website.
2. Refresh the app and find it in the appropriate section. Open its image/PDF if present.
3. Stop the website, turn off Wi-Fi on your phone, and use mobile data. Close and reopen the app and refresh. The published information should still load.
4. Restart the website, archive the post, then refresh the app. It should disappear.
5. Install the APK on another Android phone and sign in with an allowed Microsoft account.

Private file links expire after one hour. Refresh to obtain new links. Archiving/deleting stops new reads/signing immediately through database policies; an already issued signed link remains usable until expiry. Downloaded files cannot be recalled.

If sign-in does not return to the app, check the Supabase native redirect allow list. If content fails, check Supabase Data API availability and migrations. If content is empty, confirm the account is an Azure school account and run `php artisan mobile:sync`. If attachments fail, check the website S3 credentials and rerun the sync. Schema/bucket changes require an administrator; no privileged keys should be added to the APK.

## Verification

```powershell
flutter analyze --no-pub
flutter test --no-pub
```

From `SSITECMS`, run `php artisan test --filter=Mobile` for the API, publishing, permissions, and formatting regressions. Supabase access uses row-level security and short-lived private file links: https://supabase.com/docs/guides/storage/security/access-control
