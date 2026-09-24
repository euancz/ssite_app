import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      color: const Color(0xFF9DDEF7),
      child: Row(
        children: [
          const SizedBox(width: 16),

          // SSITE LOGO
          SizedBox(
            width: 48,
            height: 48,
            child: Image.asset(
              'assets/images/ssite_logo_cropped.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              isAntiAlias: true,
            ),
          ),

          const SizedBox(width: 9),

          // Organization name
          const Expanded(
            child: Text(
              'STUDENT SOCIETY IN INFORMATION\nTECHNOLOGY EDUCATION',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Color(0xFF163D4A),
                height: 1.15,
              ),
            ),
          ),

          // Notification
          IconButton(
            onPressed: () {},
            icon: const Icon(
              Icons.notifications,
              color: Color(0xFF164B5C),
              size: 23,
            ),
          ),

          const SizedBox(width: 7),
        ],
      ),
    );
  }
}
