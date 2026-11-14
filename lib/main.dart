import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_theme.dart';
import 'app_gate.dart';

const _supabaseUrl = String.fromEnvironment(
  'SSITE_SUPABASE_URL',
  defaultValue: 'https://olohkttykytclqfuenrp.supabase.co',
);
const _supabaseAnonKey = String.fromEnvironment(
  'SSITE_SUPABASE_ANON_KEY',
  defaultValue: 'sb_publishable_PS-6ehrZVem6m-9wumRaTQ_X_1tggMO',
);
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_supabaseUrl.isEmpty || _supabaseAnonKey.isEmpty) {
    runApp(const _ConfigurationErrorApp());
    return;
  }
  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabaseAnonKey,
  );
  runApp(const SSITEApp());
}

class SSITEApp extends StatelessWidget {
  const SSITEApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'SSITE',
    theme: buildAppTheme(),
    home: const AppGate(),
  );
}

class _ConfigurationErrorApp extends StatelessWidget {
  const _ConfigurationErrorApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: buildAppTheme(),
    home: const Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Supabase is not configured. Start the app with '
            'SSITE_SUPABASE_URL and SSITE_SUPABASE_ANON_KEY.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    ),
  );
}
