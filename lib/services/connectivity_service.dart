// ===========================================
// lib/services/connectivity_service.dart
// ===========================================
// Provides connectivity status monitoring and exposes a stream of connectivity changes.

import 'dart:async';
import 'dart:io';
// Only import dart:html on web
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:capstone_app/utils/constants.dart';

/// Enum representing the connection status.
enum ConnectionStatus {
  checking,
  connected,
  noNetwork,
  noInternet,
  mobileDataNoInternet,
}

/// Model for connectivity information.
class ConnectivityInfo {
  /// The current connection status.
  final ConnectionStatus status;
  /// The type of connection (WiFi, mobile, etc.).
  final ConnectivityResult? connectionType;
  /// A user-friendly message about the connection.
  final String message;
  /// Whether mobile data is enabled but has no internet.
  final bool isMobileDataWithoutInternet;

  /// Creates a [ConnectivityInfo] model.
  const ConnectivityInfo({
    required this.status,
    this.connectionType,
    required this.message,
    this.isMobileDataWithoutInternet = false,
  });
}

/// Service for monitoring device connectivity and internet access.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  final StreamController<ConnectivityInfo> _connectivityController =
      StreamController<ConnectivityInfo>.broadcast();

  /// Stream of connectivity changes.
  Stream<ConnectivityInfo> get connectivityStream =>
      _connectivityController.stream;

  static const List<String> _testUrls = [
    'google.com',
    '8.8.8.8',
    'cloudflare.com',
    '1.1.1.1',
    'facebook.com',
  ];

  /// Starts monitoring connectivity changes.
  void startMonitoring() {
    // Initial check
    checkConnection();

    // Listen to connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      ConnectivityResult result,
    ) {
      checkConnection();
    });
  }

  /// Stops monitoring connectivity changes.
  void stopMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// Checks the current connection and emits status updates.
  Future<ConnectivityInfo> checkConnection() async {
    _emitStatus(
      ConnectivityInfo(
        status: ConnectionStatus.checking,
        message: AppConstants.connectivityChecking,
      ),
    );

    try {
      if (kIsWeb) {
        // Web: use browser's online status via dart:html
        final online = html.window.navigator.onLine ?? false;
        final info = ConnectivityInfo(
          status: online ? ConnectionStatus.connected : ConnectionStatus.noInternet,
          connectionType: online ? ConnectivityResult.wifi : ConnectivityResult.none,
          message: online ? AppConstants.connectivityConnected : AppConstants.connectivityNoInternet,
        );
        _emitStatus(info);
        return info;
      }

      final connectivityResult = await Connectivity().checkConnectivity();

      // Check if device has any network connection
      if (connectivityResult == ConnectivityResult.none) {
        final info = ConnectivityInfo(
          status: ConnectionStatus.noNetwork,
          connectionType: ConnectivityResult.none,
          message: AppConstants.connectivityNoNetwork,
        );
        _emitStatus(info);
        return info;
      }

      final connectionType = connectivityResult;

      // Test actual internet connectivity
      final hasRealInternet = await _testInternetAccess(connectionType);

      ConnectivityInfo info;
      if (hasRealInternet) {
        info = ConnectivityInfo(
          status: ConnectionStatus.connected,
          connectionType: connectionType,
          message: AppConstants.connectivityConnected,
        );
      } else {
        // Determine specific no-internet scenario
        if (connectivityResult == ConnectivityResult.mobile) {
          info = ConnectivityInfo(
            status: ConnectionStatus.mobileDataNoInternet,
            connectionType: connectionType,
            message: AppConstants.connectivityMobileNoInternet,
            isMobileDataWithoutInternet: true,
          );
        } else if (connectivityResult == ConnectivityResult.wifi) {
          info = ConnectivityInfo(
            status: ConnectionStatus.noInternet,
            connectionType: connectionType,
            message: AppConstants.connectivityWifiNoInternet,
          );
        } else {
          info = ConnectivityInfo(
            status: ConnectionStatus.noInternet,
            connectionType: connectionType,
            message: AppConstants.connectivityNetworkNoInternet,
          );
        }
      }

      _emitStatus(info);
      return info;
    } catch (e) {
      final info = ConnectivityInfo(
        status: ConnectionStatus.noInternet,
        message: AppConstants.connectivityError,
      );
      _emitStatus(info);
      return info;
    }
  }

  /// Tests actual internet access by DNS and HTTP requests.
  Future<bool> _testInternetAccess(ConnectivityResult connectionType) async {
    try {
      // Try multiple attempts for mobile data reliability
      for (int attempt = 0; attempt < AppConstants.connectivityTestAttempts; attempt++) {
        for (String url in _testUrls) {
          try {
            final result = await InternetAddress.lookup(
              url,
            ).timeout(const Duration(seconds: AppConstants.connectivityDnsTimeoutSeconds));

            if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
              // Double-check with HTTP request for mobile data
              if (connectionType == ConnectivityResult.mobile) {
                return await _testHttpConnection();
              }
              return true;
            }
          } catch (e) {
            continue; // Try next URL
          }
        }
        // Wait before retry
        if (attempt == 0) {
          await Future.delayed(const Duration(seconds: AppConstants.connectivityRetryDelaySeconds));
        }
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Tests HTTP connection to a known endpoint.
  Future<bool> _testHttpConnection() async {
    try {
      final httpClient = HttpClient();
      httpClient.connectionTimeout = const Duration(seconds: AppConstants.connectivityHttpTimeoutSeconds);

      final request = await httpClient.getUrl(
        Uri.parse(AppConstants.connectivityHttpTestUrl),
      );
      final response = await request.close().timeout(
        const Duration(seconds: AppConstants.connectivityHttpTimeoutSeconds),
      );

      httpClient.close();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Emits the current connectivity info to the stream.
  void _emitStatus(ConnectivityInfo info) {
    if (!_connectivityController.isClosed) {
      _connectivityController.add(info);
    }
  }

  /// Disposes the connectivity service and closes the stream.
  void dispose() {
    stopMonitoring();
    _connectivityController.close();
  }
}
