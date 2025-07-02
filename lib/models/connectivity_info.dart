// lib/models/connectivity_info.dart
import 'package:connectivity_plus/connectivity_plus.dart';

/// Enum representing the connection status
enum ConnectionStatus {
  checking,
  connected,
  noNetwork,
  noInternet,
  mobileDataNoInternet,
}

/// Model for connectivity information
class ConnectivityInfo {
  final ConnectionStatus status;
  final ConnectivityResult connectionType;
  final String message;
  final bool isMobileDataWithoutInternet;

  ConnectivityInfo({
    required this.status,
    required this.connectionType,
    required this.message,
    this.isMobileDataWithoutInternet = false,
  });
}
