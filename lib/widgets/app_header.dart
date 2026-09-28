import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  final VoidCallback onMenuTap;

  const AppHeader({super.key, required this.onMenuTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      width: double.infinity,
      color: const Color(0xFF9DDEF7),
      child: Row(
        children: [
          const SizedBox(width: 8),

          // ======================================================
          // SSITE LOGO
          // ======================================================
          SizedBox(
            width: 52,
            height: 52,
            child: Image.asset(
              'assets/images/ssite_logo_cropped.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),

          const SizedBox(width: 4),

          // ======================================================
          // ORGANIZATION NAME
          // ======================================================
          const Expanded(
            child: Text(
              'STUDENT SOCIETY IN INFORMATION\nTECHNOLOGY EDUCATION',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Color(0xFF163D4A),
                height: 1.15,
              ),
            ),
          ),

          // ======================================================
          // NOTIFICATION
          // ======================================================
          IconButton(
            onPressed: () {},
            tooltip: 'Notifications',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: const Icon(
              Icons.notifications,
              color: Color(0xFF164B5C),
              size: 23,
            ),
          ),

          IconButton(
            onPressed: onMenuTap,
            tooltip: 'Open menu',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            icon: const Icon(Icons.menu, color: Color(0xFF164B5C), size: 25),
          ),

          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
