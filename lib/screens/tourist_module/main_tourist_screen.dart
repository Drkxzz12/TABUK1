import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'event_calendar/event_calendar.dart';
import 'home/home.dart';
import 'map/map_screen.dart';
import 'trips/trips_screen.dart';
import 'profile/profile_screen.dart';

/// Main screen for tourist users with bottom navigation.
class MainTouristScreen extends StatefulWidget {
  const MainTouristScreen({super.key});

  @override
  State<MainTouristScreen> createState() => _MainTouristScreenState();
}

class _MainTouristScreenState extends State<MainTouristScreen> {
  int _selectedIndex = 0;
  String? _userRole; // Assume this is fetched from somewhere
  bool get _isGuest => _userRole?.toLowerCase() == 'guest';

  // List of screens for navigation
  List<Widget> get _screens {
    if (_userRole == null) {
      // Show loading until role is fetched
      return [const Center(child: CircularProgressIndicator())];
    }
    if (_isGuest) {
      return [
        const MapScreen(),
        const EventCalendarScreen(),
        const ProfileScreen(),
      ];
    } else {
      return [
        const HomeScreen(),
        const MapScreen(),
        const TripsScreen(),
        const EventCalendarScreen(),
        const ProfileScreen(),
      ];
    }
  }

  @override
void initState() {
  super.initState();
  _fetchUserRole();
}

Future<void> _fetchUserRole() async {
  final user = AuthService.currentUser;
  if (user == null) return;
  final doc = await FirebaseFirestore.instance.collection('Users').doc(user.uid).get();
  setState(() {
    _userRole = doc.data()?['role'];
  });
}

  void _onItemTapped(int index) {
    // Restrict guest navigation to only allowed tabs
    if (_isGuest) {
      // Only allow Map (0), Events (1), and Profile (2)
      if (index > 2) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This feature is only available for registered users'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Prevent navigation bar from showing until role is loaded
    if (_userRole == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    if (_userRole == null) {
      return const SizedBox.shrink();
    }
    if (_isGuest) {
      return BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Maps'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Events'),
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
    } else {
      return BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Maps'),
          BottomNavigationBarItem(icon: Icon(Icons.luggage), label: 'Trips'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Calendar'),
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
}

// Add/fix doc comments for all classes and key methods, centralize constants, use const where possible, and ensure code quality and maintainability throughout the file.
