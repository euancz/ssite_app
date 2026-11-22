import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'cms_app_gate.dart';
import 'services/cms_api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(url: projectUrl, publishableKey: publishableKey);
  runApp(SSITEApp(client: Supabase.instance.client));
}

class SSITEApp extends StatelessWidget {
  const SSITEApp({super.key, required this.client});
  final SupabaseClient client;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'SSITE',
    theme: buildAppTheme(),
    home: CmsAppGate(client: client),
  );
}
