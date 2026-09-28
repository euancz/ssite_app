import 'package:flutter/material.dart';

import 'home/home_screen.dart';
import 'articles/articles_screen.dart';
import 'activities/activities_screen.dart';
import 'profile/profile_screen.dart';

import '../widgets/app_header.dart';
import '../widgets/sidebar.dart';
import '../widgets/bottom_nav.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  // KEY FOR THE DRAWER
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _screens = const [
    HomeScreen(),
    ArticlesScreen(),
    ActivitiesScreen(),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _openEndDrawer() {
    _scaffoldKey.currentState?.openEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,

      // ==========================================================
      // SIDEBAR
      // ==========================================================
      endDrawer: const Sidebar(),

      backgroundColor: Colors.white,

      // ==========================================================
      // MAIN CONTENT
      // ==========================================================
      body: Column(
        children: [
          // HEADER
          AppHeader(onMenuTap: _openEndDrawer),

          // CURRENT SCREEN
          Expanded(
            child: IndexedStack(index: _selectedIndex, children: _screens),
          ),
        ],
      ),

      // ==========================================================
      // BOTTOM NAVIGATION
      // ==========================================================
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }
}
