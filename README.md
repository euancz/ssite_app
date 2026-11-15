# SSITE app

Flutter companion app for SSITE articles, activities, achievements, documents,
transparency reports, officers, and sponsors. Microsoft school sign-in and
published content use Supabase; recipients can read content while the local CMS
computer is off.

Start with [the debugging map](docs/DEBUGGING.md) to find a feature, or
[setup and distribution](docs/SETUP.md) for backend configuration, sign-in,
building, and troubleshooting.

## Source layout

| Location | Responsibility |
| --- | --- |
| `lib/main.dart`, `lib/app_gate.dart` | Startup and authentication |
| `lib/screens/auth/` | Sign-in screen |
| `lib/screens/main_screen.dart` | App shell and navigation |
| `lib/screens/content/` | Feeds, cards, documents, About, sponsors, shared UI |
| `lib/screens/workspace_screen.dart` | Embedded CMS browser |
| `lib/services/` | Content models, HTTP client, Supabase feed |
| `lib/widgets/`, `lib/app_theme.dart` | Shared navigation, heroes, theme |
| `assets/` | Images, SVGs, fonts, and licenses |
| `test/` | Rendering, search, authentication, and data regressions |
| Platform folders | Flutter platform integration |

## Run and verify

```powershell
flutter pub get
flutter run
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --release
```

See [setup and distribution](docs/SETUP.md) before sharing a build. It covers
Microsoft redirect configuration, CMS publishing, signing, and backend overrides.

## Files kept local

Builds, packaged APKs, test reports, local environment settings, signing keys,
dependencies, and editor caches are ignored. Commit source, assets, platform
integration, tests, and `pubspec.lock`. Never put backend service keys in the app.
