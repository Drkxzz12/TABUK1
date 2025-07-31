library;

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'dart:async';
import 'screens/splash_screen.dart';
import 'services/connectivity_service.dart';
import 'package:capstone_app/models/connectivity_info.dart';
import 'package:capstone_app/utils/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure channel buffers before Firebase initialization
  ServicesBinding.instance.defaultBinaryMessenger.setMessageHandler(
    'flutter/lifecycle',
    (message) async => null,
  );

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    // Consider if you want to continue without Firebase or exit
  }

  runApp(const TabukRoot());
}

class TabukRoot extends StatefulWidget {
  const TabukRoot({super.key});

  @override
  State<TabukRoot> createState() => _TabukRootState();
}

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

  void _initializeConnectivityMonitoring() {
    try {
      _connectivitySubscription = _connectivityService.connectivityStream.listen(
        (ConnectivityInfo info) {
          _handleGlobalConnectivityChange(info);
        },
        onError: (error) {
          debugPrint('Connectivity stream error: $error');
        },
      );
      _connectivityService.startMonitoring();
    } catch (e) {
      debugPrint('Failed to initialize connectivity monitoring: $e');
    }
  }

  void _handleGlobalConnectivityChange(ConnectivityInfo info) {
    if (!mounted) return; // Safety check
    
    setState(() {});
    
    // Only navigate if we're not already on splash and connection is lost
    if (_shouldNavigateToSplash(info)) {
      _navigateToSplashScreen(info.message);
    }
  }

  bool _shouldNavigateToSplash(ConnectivityInfo info) {
    return _currentRouteName != null &&
           _currentRouteName != AppConstants.rootRoute &&
           _currentRouteName != AppConstants.splashRoute &&
           info.status != ConnectionStatus.connected &&
           info.status != ConnectionStatus.checking;
  }

  void _navigateToSplashScreen(String reason) {
    if (!_isAppInForeground) return;
    
    final navigator = _navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('Navigator is null, cannot navigate to splash');
      return;
    }

    // Prevent multiple navigation attempts
    if (_currentRouteName == AppConstants.splashRoute) return;

    debugPrint('Navigating to splash due to: $reason');
    
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const SplashScreen(),
        settings: const RouteSettings(name: AppConstants.splashRoute),
      ),
      (route) => false,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    final wasInForeground = _isAppInForeground;
    _isAppInForeground = state == AppLifecycleState.resumed;
    
    // Only check connection when resuming from background
    if (!wasInForeground && _isAppInForeground) {
      debugPrint('App resumed, checking connectivity');
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: AppConstants.appName,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        fontFamily: 'Roboto',
        // Add visual density for better touch targets
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: AppConstants.splashRoute,
      onGenerateRoute: (settings) {
        _currentRouteName = settings.name;
        
        switch (settings.name) {
          case AppConstants.splashRoute:
            return MaterialPageRoute(
              builder: (_) => const SplashScreen(),
              settings: settings,
            );
          // Add other routes here as needed
          default:
            // Handle unknown routes
            debugPrint('Unknown route: ${settings.name}');
            return MaterialPageRoute(
              builder: (_) => const SplashScreen(),
              settings: const RouteSettings(name: AppConstants.splashRoute),
            );
        }
      },
      debugShowCheckedModeBanner: false,
    );
  }


}