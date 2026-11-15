# Find the code to debug

Start at `lib/main.dart` (Supabase initialization), then `lib/app_gate.dart`
(authentication), then `lib/screens/main_screen.dart` (app shell and navigation).

| Problem or change | Start here |
| --- | --- |
| Sign-in, session changes, sign-out | `lib/app_gate.dart`, `lib/screens/auth/login_screen.dart` |
| Supabase URL or public key | `lib/main.dart`; build-time `SSITE_SUPABASE_*` defines |
| Tabs, header, refresh menu, workspace handoff | `lib/screens/main_screen.dart` |
| Loading, refresh, search, sorting, filters, load more | `lib/screens/content/cms_page.dart` |
| Post cards, detail view, share, images | `lib/screens/content/post_cards.dart` |
| Documents, transparency transactions, PDF opening | `lib/screens/content/document_content.dart` |
| About text and officers | `lib/screens/content/about_content.dart` |
| Sponsor cards | `lib/screens/content/sponsor_card.dart` |
| Shared headings, surfaces, empty/error states, dates | `lib/screens/content/content_widgets.dart` |
| Fonts, colors, theme | `lib/app_theme.dart` |
| Hero images and tab labels | `lib/widgets/cms_hero.dart`, `lib/widgets/cms_navigation.dart` |
| Models, backend selection, legacy HTTP client | `lib/services/cms_api.dart` |
| Published Supabase data, signed media links | `lib/services/supabase_feed.dart` |
| Embedded CMS browser | `lib/screens/workspace_screen.dart` |

Files under `screens/content/` are Dart parts of `main_screen.dart`: they share
its imports and private helpers. Import `main_screen.dart` to use `MainScreen`,
`CmsPage`, `CmsPostCard`, or `formatCmsDate`; do not import a part directly.
This preserves the existing public API and test imports.

## Trace missing content

1. Confirm sign-in succeeds and reaches `AppGate`.
2. Check `CmsApi` for backend selection. The distributed app uses Supabase;
   injected HTTP clients support CMS integration tests.
3. Check `SupabaseFeed` and `mobile_publications`. CMS publishing lives in
   `SSITECMS/app/Services/MobilePublisher.php` and its publication observer.
4. If data arrives but looks wrong, open the presentation file above. Refresh
   expired media links to obtain new signed URLs.

## Verification and Git

Run from `ssiteapp`:

```powershell
flutter analyze --no-pub
flutter test --no-pub
```

Tests are grouped by concern: `cms_pages_test.dart` (rendering/navigation),
`search_usability_test.dart` (search/filters), `cms_api_test.dart` (HTTP),
`supabase_feed_test.dart` and `sponsors_test.dart` (published data),
`widget_test.dart` and `login_url_test.dart` (startup/sign-in).

Keep source, platform files, assets, tests, and `pubspec.lock` in Git. Builds,
`.dart_tool/`, IDE state, signing keys, local environment files, and `artifacts/`
stay local. Only a Supabase public/publishable key belongs in the app; privileged
credentials belong in the backend environment.
