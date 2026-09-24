import 'package:flutter/material.dart';
import 'screens/main_screen.dart';

void main() {
  runApp(const SSITEApp());
}

class SSITEApp extends StatelessWidget {
  const SSITEApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SSITE',
      home: const MainScreen(),
    );
  }
}
