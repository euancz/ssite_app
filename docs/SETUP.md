# Mobile setup

The APK includes the Supabase project URL and publishable key. Keep database credentials, service-role keys and Microsoft client secrets on the server.

The project requires the existing SSITECMS tables and Storage buckets. Apply the SQL migrations in filename order once. Configure the singleton row in `ssite_mobile.settings` with the CMS Microsoft tenant UUID, school email domain, private and public bucket names, and the CMS approval and engagement settings. The optional website URL is used for sharing.

Enable the Azure provider in Supabase Auth for the school tenant. Register the Supabase Auth callback with Microsoft and allow `ssiteapp://auth/callback` as a mobile redirect in Supabase. Members sign in with their school Microsoft account.

Run the Android APK workflow on GitHub and download the SSITE-Android-APK artifact. Install the extracted APK on Android and allow internet access.
