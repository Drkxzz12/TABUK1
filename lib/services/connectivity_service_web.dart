// lib/services/connectivity_service_web.dart
// Web-specific connectivity check for conditional import
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:capstone_app/utils/constants.dart';
import 'package:capstone_app/models/connectivity_info.dart';

Future<ConnectivityInfo> checkConnectionPlatform() async {
  final online = html.window.navigator.onLine ?? false;
  return ConnectivityInfo(
    status: online ? ConnectionStatus.connected : ConnectionStatus.noInternet,
    connectionType: online ? ConnectivityResult.wifi : ConnectivityResult.none,
    message: online ? AppConstants.connectivityConnected : AppConstants.connectivityNoInternet,
  );
}
