import 'package:flutter/material.dart';

// SSITECMS/public/css/app.css and site-navigation.css.
const navy = Color(0xFF17324D);
const blue = Color(0xFF3DAFEA);
const accent = Color(0xFF8AD5F4);
const canvas = Color(0xFFF7FAFC);
const ink = Color(0xFF17324D);
const muted = Color(0xFF52697C);
const line = Color(0xFFD9E6EE);

ThemeData buildAppTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Poppins',
  scaffoldBackgroundColor: canvas,
  colorScheme: ColorScheme.fromSeed(
    seedColor: navy,
    primary: navy,
    secondary: blue,
    surface: Colors.white,
  ),
  textTheme: const TextTheme(
    headlineSmall: TextStyle(
      fontSize: 24,
      height: 1.3,
      fontWeight: FontWeight.w700,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      height: 1.35,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.4,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: TextStyle(fontSize: 15, height: 1.65),
    bodyMedium: TextStyle(fontSize: 14, height: 1.6),
    bodySmall: TextStyle(fontSize: 12, height: 1.5),
    labelLarge: TextStyle(
      fontSize: 13,
      height: 1.4,
      fontWeight: FontWeight.w600,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      height: 1.4,
      fontWeight: FontWeight.w600,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      height: 1.4,
      fontWeight: FontWeight.w600,
    ),
  ).apply(fontFamily: 'Poppins', bodyColor: ink, displayColor: ink),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF7BD0ED),
    foregroundColor: Color(0xFF063847),
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    toolbarHeight: 72,
    titleTextStyle: TextStyle(
      fontFamily: 'Poppins',
      fontSize: 18,
      color: ink,
      fontWeight: FontWeight.w600,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFF155571), width: 1.5),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: Colors.white,
    selectedColor: const Color(0xFFC7ECF9),
    side: const BorderSide(color: line),
    showCheckmark: false,
    labelStyle: const TextStyle(
      fontFamily: 'Poppins',
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: ink,
    ),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
  dividerTheme: const DividerThemeData(color: line, thickness: 1, space: 24),
  popupMenuTheme: const PopupMenuThemeData(
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    textStyle: TextStyle(fontFamily: 'Poppins', fontSize: 14, color: ink),
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: const Color(0xFF7BD0ED),
    indicatorColor: const Color(0xFFB9E8F7),
    labelTextStyle: WidgetStateProperty.all(
      const TextStyle(
        fontFamily: 'Poppins',
        color: Color(0xFF063847),
        fontSize: 10,
      ),
    ),
    iconTheme: WidgetStateProperty.all(
      const IconThemeData(color: Color(0xFF063847), size: 22),
    ),
  ),
);
