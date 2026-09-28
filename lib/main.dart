import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:ssiteapp/screens/splash_screen.dart';

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
      theme: ThemeData(
        fontFamily: GoogleFonts.poppins().fontFamily,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const SplashScreen(),
    );
  }
}
