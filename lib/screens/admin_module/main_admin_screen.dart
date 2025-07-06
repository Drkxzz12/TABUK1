import 'package:capstone_app/screens/admin_module/hotspots/hotspots.dart';
import 'package:flutter/material.dart';
import 'package:capstone_app/screens/admin_module/profile/profile_screen.dart';
import 'package:capstone_app/screens/admin_module/events/events.dart';

import 'package:capstone_app/utils/colors.dart';

/// Main screen for admin users with bottom navigation.
class MainAdminScreen extends StatefulWidget {
  const MainAdminScreen({super.key});

  @override
  State<MainAdminScreen> createState() => _MainAdminScreenState();
}

class _MainAdminScreenState extends State<MainAdminScreen> {
  int _selectedIndex = 0;

  // List of screens for navigation - matching the bottom nav items
  final List<Widget> _screens = [
    const _PlaceholderScreen(title: 'Dashboard'),
    HotspotsManagementScreen(),
    EventsManagementScreen(),
    const _PlaceholderScreen(title: 'Notifications'),
    ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return BottomNavigationBar(
      items: const [
        // Alternative bottom nav items
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: 'Dashboard',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.location_on),
          label: 'Hotspots',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.event),
          label: 'Events',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications),
          label: 'Notifications',
        ),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
      ],
      currentIndex: _selectedIndex,
      selectedItemColor: AppColors.primaryOrange,
      unselectedItemColor: AppColors.textLight,
      onTap: _onItemTapped,
      type: BottomNavigationBarType.fixed,
      showSelectedLabels: true,
      showUnselectedLabels: true,
    );
  }
}

// Helper widget for placeholder screens
class _PlaceholderScreen extends StatelessWidget {
  final String title;

  const _PlaceholderScreen({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.primaryOrange,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.construction, size: 64, color: AppColors.textLight),
            const SizedBox(height: 16),
            Text(
              '$title Screen',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming Soon',
              style: TextStyle(fontSize: 16, color: AppColors.textLight),
            ),
          ],
        ),
      ),
    );
  }
}
// Add/fix doc comments for all classes and key methods, centralize constants, use const where possible, and ensure code quality and maintainability throughout the file.
