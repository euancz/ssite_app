import 'package:flutter/material.dart';

class AppBottomNav extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 61,

      decoration: const BoxDecoration(
        color: Color(0xFF9DDEF7),
        border: Border(top: BorderSide(color: Color(0xFF164B5C), width: 1)),
      ),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(icon: Icons.home, label: 'Home', index: 0),

          _buildNavItem(icon: Icons.newspaper, label: 'Articles', index: 1),

          // ADD
          GestureDetector(
            onTap: () {
              // Add button logic
            },
            child: const Icon(
              Icons.add_circle_outline,
              size: 29,
              color: Color(0xFF164B5C),
            ),
          ),

          _buildNavItem(icon: Icons.grid_view, label: 'Activities', index: 2),

          _buildNavItem(
            icon: Icons.account_circle_outlined,
            label: 'Profile',
            index: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final bool selected = selectedIndex == index;

    return GestureDetector(
      onTap: () {
        onItemTapped(index);
      },

      child: SizedBox(
        width: 55,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 25, color: const Color(0xFF164B5C)),

            const SizedBox(height: 2),

            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: const Color(0xFF164B5C),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
