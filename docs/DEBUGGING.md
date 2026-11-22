# Source map

| Feature | Flutter | Dart service |
| --- | --- | --- |
| Microsoft sign-in and session restore | `lib/cms_app_gate.dart` | `backend/lib/auth.dart`, `backend/lib/server.dart` |
| Home, Discover, search, document and report listings | `lib/screens/content/`, `lib/services/cms_api.dart` | `backend/lib/feed.dart` |
| Profile, notifications and staff navigation | `lib/screens/account_tools.dart`, `lib/screens/member_account.dart` | `backend/lib/administration.dart` |
| Drafts, submission, review, archive and history | `lib/screens/account_tools.dart` | `backend/lib/workspace.dart` |
| Roles, roster and sponsors | `lib/screens/account_tools.dart` | `backend/lib/administration.dart` |
| Attachments | `lib/screens/content/document_content.dart`, `lib/screens/account_tools.dart` | `backend/lib/media.dart` |

For service connectivity or Microsoft redirect setup, see [setup](SETUP.md). The endpoint prefix is `/api/mobile/v1` on the Dart service. Start with `test/workflows_test.dart` in the backend package when investigating shared database writes or access checks.
