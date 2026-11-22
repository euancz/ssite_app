import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'cms_app_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SSITEApp());
}

class SSITEApp extends StatelessWidget {
  const SSITEApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'SSITE',
    theme: buildAppTheme(),
    home: const CmsAppGate(),
  );
}
