// ===========================================
// main.dart
// ===========================================
// Entry point for the Tabuk app. Handles Firebase initialization,
/// global connectivity monitoring, and root navigation.
library;


import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'dart:async';
import 'screens/splash_screen.dart';
import 'services/connectivity_service.dart';
import 'package:capstone_app/models/connectivity_info.dart';
import 'package:capstone_app/utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Initialize Firebase with platform-specific options
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const TabukRoot());
}

/// Root widget for the Tabuk app.
class TabukRoot extends StatefulWidget {
  /// Creates a [TabukRoot] widget.
  const TabukRoot({super.key});

  @override
  State<TabukRoot> createState() => _TabukRootState();
}

/// State for [TabukRoot], manages app lifecycle and connectivity.
class _TabukRootState extends State<TabukRoot> with WidgetsBindingObserver {
  late StreamSubscription<ConnectivityInfo> _connectivitySubscription;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _isAppInForeground = true;
  String? _currentRouteName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeConnectivityMonitoring();
  }

  /// Sets up connectivity monitoring and handles global connectivity changes.
  void _initializeConnectivityMonitoring() {
    _connectivitySubscription = _connectivityService.connectivityStream.listen(
      (ConnectivityInfo info) {
        _handleGlobalConnectivityChange(info);
      },
      onError: (error) {
        debugPrint('Global connectivity stream error: $error');
      },
    );
    _connectivityService.startMonitoring();
  }

  /// Handles connectivity changes and navigates to splash screen if needed.
  void _handleGlobalConnectivityChange(ConnectivityInfo info) {
    debugPrint(
      'Connectivity status: ${info.status}, route: $_currentRouteName',
    );
    setState(() {}); // Force UI update for debugging
    if (_currentRouteName != null &&
        _currentRouteName != AppConstants.rootRoute &&
        _currentRouteName != AppConstants.splashRoute) {
      if (info.status != ConnectionStatus.connected &&
          info.status != ConnectionStatus.checking) {
        _navigateToSplashScreen('Connection lost: ${info.message}');
      }
    }
  }

  /// Navigates to the splash screen with a reason if app is in foreground.
  void _navigateToSplashScreen(String reason) {
    if (_isAppInForeground && _navigatorKey.currentState != null) {
      debugPrint('Global navigation to splash screen: $reason');
      _navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: const RouteSettings(name: '/splash'),
        ),
        (route) => false,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _isAppInForeground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
      // App came to foreground - trigger connectivity check
      _connectivityService.checkConnection();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySubscription.cancel();
    _connectivityService.stopMonitoring();
    super.dispose();
  }

  /// Builds the root [MaterialApp] for the Tabuk app.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: AppConstants.appName,
      theme: ThemeData(primarySwatch: Colors.orange, fontFamily: 'Roboto'),
      home: const SplashScreen(),
      routes: {AppConstants.splashRoute: (context) => const SplashScreen()},
      onGenerateRoute: (settings) {
        _currentRouteName = settings.name;
        return null; // Let the default routing handle it
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
