// lib/services/connectivity_service.dart
// Platform-agnostic connectivity service using conditional imports


import 'package:capstone_app/models/connectivity_info.dart';
import 'dart:async';

// Export the correct implementation based on the platform
import 'connectivity_service_mobile.dart'
    if (dart.library.html) 'connectivity_service_web.dart';

/// ConnectivityService provides a unified API for connectivity across platforms.
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final StreamController<ConnectivityInfo> _controller = StreamController<ConnectivityInfo>.broadcast();
  StreamSubscription? _platformSubscription;
  bool _monitoring = false;

  /// Returns a stream of connectivity changes.
  Stream<ConnectivityInfo> get connectivityStream => _controller.stream;

  /// Checks the current connection status once.
  Future<ConnectivityInfo> checkConnection() async {
    final info = await checkConnectionPlatform();
    return info;
  }

  /// Starts monitoring connectivity changes (polling every 2 seconds).
  void startMonitoring({Duration interval = const Duration(seconds: 2)}) {
    if (_monitoring) return;
    _monitoring = true;
    _platformSubscription = Stream.periodic(interval).asyncMap((_) => checkConnectionPlatform()).listen((info) {
      _controller.add(info);
    });
  }

  /// Stops monitoring connectivity changes.
  void stopMonitoring() {
    _monitoring = false;
    _platformSubscription?.cancel();
    _platformSubscription = null;
  }

  void dispose() {
    stopMonitoring();
    _controller.close();
  }
}

// The function signature is the same for both platforms
// Usage: await checkConnectionPlatform();

// ConnectivityInfo, ConnectionStatus, and AppConstants should be defined in a shared location
// (e.g., utils/constants.dart or a shared model file)

// This file only provides the import mechanism. The actual implementation is in the platform-specific files.
