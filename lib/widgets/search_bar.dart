import 'package:flutter/material.dart';

class AppSearchBar extends StatelessWidget {
  const AppSearchBar({super.key});

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Discover something from SSITE...',
        hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 11,
          vertical: 10,
        ),

        filled: true,
        fillColor: Colors.white,

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFFD0D0D0)),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFF4C9AB5)),
        ),
      ),
    );
  }
}
