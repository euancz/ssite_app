import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'app_gate.dart';

void main() => runApp(const SSITEApp());

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
