// ===========================================
// lib/screens/splash_screen.dart
// ===========================================
// Splash screen with connectivity check and navigation to login.

import 'package:flutter/material.dart';
import 'package:capstone_app/models/connectivity_info.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:capstone_app/utils/constants.dart';
import 'package:capstone_app/screens/login_screen.dart';
import 'package:capstone_app/services/connectivity_service.dart';
import 'package:capstone_app/widgets/connectivity_widget.dart';
import 'package:capstone_app/widgets/app_logo_widget.dart';
import 'dart:async';

/// Splash screen that checks connectivity and navigates to login.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final ConnectivityService _connectivityService = ConnectivityService();
  StreamSubscription<ConnectivityInfo>? _connectivitySubscription;
  ConnectivityInfo _currentConnectivityInfo = ConnectivityInfo(
    status: ConnectionStatus.checking,
    connectionType: ConnectivityResult.none,
    message: AppConstants.connectivityChecking,
  );

// Add import for ConnectivityResult

  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _initializeConnectivity();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivityService.stopMonitoring();
    super.dispose();
  }

  /// Initializes connectivity monitoring and listens for changes.
  void _initializeConnectivity() {
    _connectivitySubscription = _connectivityService.connectivityStream.listen(
      _handleConnectivityChange,
    );
    _connectivityService.startMonitoring();
  }

  /// Handles connectivity changes and navigates to login if connected.
  void _handleConnectivityChange(ConnectivityInfo connectivityInfo) {
    if (!mounted) return;
    setState(() {
      _currentConnectivityInfo = connectivityInfo;
    });
    if (connectivityInfo.status == ConnectionStatus.connected && !_isNavigating) {
      _navigateToLogin();
    }
  }

  /// Navigates to the login screen after a short delay.
  Future<void> _navigateToLogin() async {
    setState(() {
      _isNavigating = true;
    });
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  /// Retries the connectivity check.
  void _retryConnection() {
    _connectivityService.checkConnection();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Logo
                  const AppLogoWidget(),
                  const SizedBox(height: AppConstants.splashLogoSpacing),
                  // Connection Status Indicator (only show when not checking)
                  if (_currentConnectivityInfo.status != ConnectionStatus.checking) ...[
                    ConnectivityStatusIndicator(
                      connectivityInfo: _currentConnectivityInfo,
                    ),
                    const SizedBox(height: AppConstants.splashStatusSpacing),
                  ],
                  // Mobile Data Warning (show when mobile data is on but no internet)
                  if (_currentConnectivityInfo.isMobileDataWithoutInternet &&
                      _currentConnectivityInfo.status != ConnectionStatus.checking) ...[
                    const MobileDataWarningCard(),
                    const SizedBox(height: AppConstants.splashWarningSpacing),
                  ],
                  // Action Button/Loading Indicator
                  ConnectivityActionButton(
                    connectivityInfo: _currentConnectivityInfo,
                    onRetry: _retryConnection,
                    isNavigating: _isNavigating,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
// Add/fix doc comments for all classes and key methods, centralize constants, use const where possible, and ensure code quality and maintainability throughout the file.
