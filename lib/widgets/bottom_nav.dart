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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildNavItem(icon: Icons.home, label: 'Home', index: 0),

          _buildNavItem(icon: Icons.newspaper, label: 'Articles', index: 1),

          SizedBox(
            width: 55,
            child: GestureDetector(
              onTap: () {
                // Add button logic
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_circle_outline,
                    size: 28,
                    color: Color(0xFF164B5C),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Add',
                    style: TextStyle(
                      fontSize: 9,
                      color: const Color(0xFF164B5C),
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                ],
              ),
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
    final Color activeColor = const Color(0xFF123E4C);
    final Color inactiveColor = const Color(0xFF164B5C);

    return GestureDetector(
      onTap: () {
        onItemTapped(index);
      },
      child: SizedBox(
        width: 55,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 25, color: selected ? activeColor : inactiveColor),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                color: selected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
