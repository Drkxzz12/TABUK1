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
  bool _roleDialogShown = false;

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
    final role = doc.data()?['role'];
    setState(() {
      _userRole = role;
    });
    // If no role, show role selection dialog (only once)
    if ((role == null || (role is String && role.isEmpty)) && !_roleDialogShown) {
      _roleDialogShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showRoleSelectionDialog(user.uid);
      });
    }
  }

void _showRoleSelectionDialog(String uid) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _RoleSelectionDialog(
        onRoleSelected: (role) async {
  final messenger = ScaffoldMessenger.of(dialogContext); // capture before await

  await AuthService.storeUserData(
    uid,
    AuthService.currentUser?.email ?? '',
    role,
  );

  if (!mounted) return;

  setState(() {
    _userRole = role;
  });

  if (!mounted) return;

  // ignore: use_build_context_synchronously
  Navigator.of(dialogContext).pop();

  if (!mounted) return;

  messenger.showSnackBar(
    SnackBar(
      content: Text('Role set to $role!'),
      backgroundColor: Colors.green,
      duration: const Duration(seconds: 2),
    ),
  );
}
      );
    },
  );
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

class _RoleSelectionDialog extends StatefulWidget {
  final Function(String) onRoleSelected;
  const _RoleSelectionDialog({required this.onRoleSelected});
  @override
  State<_RoleSelectionDialog> createState() => _RoleSelectionDialogState();
}

class _RoleSelectionDialogState extends State<_RoleSelectionDialog> {
  String _selectedRole = 'Tourist';
  static const _roles = ['Business Owner', 'Tourist', 'Administrator'];
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Select Your Role',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      content: DropdownButtonFormField<String>(
        value: _selectedRole,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white.withOpacity(0.8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
        items: _roles.map((role) => DropdownMenuItem(
          value: role,
          child: Text(role, style: const TextStyle(color: AppColors.textDark, fontSize: 14)),
        )).toList(),
        onChanged: (value) {
          if (value != null) setState(() => _selectedRole = value);
        },
      ),
      actions: [
        ElevatedButton(
          onPressed: () {
            widget.onRoleSelected(_selectedRole);
          },
          child: const Text('Continue'),
        ),
      ],
    );
  }
}

// Add/fix doc comments for all classes and key methods, centralize constants, use const where possible, and ensure code quality and maintainability throughout the file.
