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

  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}

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
        onError: (_) {},
      );
      _connectivityService.startMonitoring();
    } catch (_) {}
  }

  void _handleGlobalConnectivityChange(ConnectivityInfo info) {
    setState(() {});
    if (_currentRouteName != null &&
        _currentRouteName != AppConstants.rootRoute &&
        _currentRouteName != AppConstants.splashRoute) {
      if (info.status != ConnectionStatus.connected &&
          info.status != ConnectionStatus.checking) {
        _navigateToSplashScreen(info.message);
      }
    }
  }

  void _navigateToSplashScreen(String reason) {
  if (_isAppInForeground) {
    final navigator = _navigatorKey.currentState;
    if (navigator != null) {
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const SplashScreen(),
          settings: const RouteSettings(name: '/splash'),
        ),
        (route) => false,
      );
    }
  }
}

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    _isAppInForeground = state == AppLifecycleState.resumed;
    if (state == AppLifecycleState.resumed) {
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
      theme: ThemeData(primarySwatch: Colors.orange, fontFamily: 'Roboto'),
      initialRoute: AppConstants.splashRoute,
      onGenerateRoute: (settings) {
        _currentRouteName = settings.name;
        if (settings.name == AppConstants.splashRoute) {
          return MaterialPageRoute(
            builder: (_) => const SplashScreen(),
            settings: settings,
          );
        }
        return null;
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
