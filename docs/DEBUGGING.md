# Source map

Microsoft login and session restoration live in `lib/cms_app_gate.dart`. The Supabase client adapter, storage operations and native workspace forms are in `lib/services/`. Flutter screens are in `lib/screens/`.

The five SQL migrations in `supabase/migrations/` implement account linking, feed and workspace reads, Storage authorization, content workflows and administrative actions, respectively. Use `flutter test` to run the client tests.
