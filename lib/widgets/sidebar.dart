import 'package:flutter/material.dart';

import '../screens/auth/login_screen.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 230,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      backgroundColor: const Color(0xFF155A73),
      child: SafeArea(
        child: Column(
          children: [
            // =====================================================
            // PROFILE HEADER
            // =====================================================
            Container(
              height: 55,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF6C9BAA), width: 1),
                ),
              ),
              child: Row(
                children: [
                  // PROFILE ICON
                  Container(
                    width: 31,
                    height: 31,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: const Icon(
                      Icons.person,
                      size: 22,
                      color: Color(0xFF155A73),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // USER INFORMATION
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alden Euan Raine Cruz',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'SSITE Officer',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // =====================================================
            // MENU
            // =====================================================
            const SizedBox(height: 10),

            _buildMenuItem(
              context,
              icon: Icons.emoji_events_outlined,
              title: 'Achievements',
              onTap: () {
                Navigator.pop(context);
              },
            ),

            _buildMenuItem(
              context,
              icon: Icons.description_outlined,
              title: 'Documents',
              onTap: () {
                Navigator.pop(context);
              },
            ),

            _buildMenuItem(
              context,
              icon: Icons.attach_money,
              title: 'Liquidation',
              onTap: () {
                Navigator.pop(context);
              },
            ),

            _buildMenuItem(
              context,
              icon: Icons.hourglass_empty,
              title: 'About SSITE',
              onTap: () {
                Navigator.pop(context);
              },
            ),

            _buildMenuItem(
              context,
              icon: Icons.contact_phone_outlined,
              title: 'Contact Us',
              onTap: () {
                Navigator.pop(context);
              },
            ),

            const Spacer(),

            // =====================================================
            // LOG OUT
            // =====================================================
            Padding(
              padding: const EdgeInsets.only(left: 15, right: 15, bottom: 10),
              child: SizedBox(
                width: double.infinity,
                height: 28,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2A91B5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  child: const Text('Log out', style: TextStyle(fontSize: 12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 40,
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            const SizedBox(width: 29),

            Icon(icon, color: Colors.white, size: 22),

            const SizedBox(width: 13),

            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}
