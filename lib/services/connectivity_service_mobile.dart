// Mobile/desktop-specific connectivity check
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:capstone_app/utils/constants.dart';
import 'package:capstone_app/models/connectivity_info.dart';

Future<ConnectivityInfo> checkConnectionPlatform() async {
  final connectivityResult = await Connectivity().checkConnectivity();

  if (connectivityResult == ConnectivityResult.none) {
    return ConnectivityInfo(
      status: ConnectionStatus.noNetwork,
      connectionType: ConnectivityResult.none,
      message: AppConstants.connectivityNoNetwork,
    );
  }

  final connectionType = connectivityResult;
  final hasRealInternet = await _testInternetAccess(connectionType);

  if (hasRealInternet) {
    return ConnectivityInfo(
      status: ConnectionStatus.connected,
      connectionType: connectionType,
      message: AppConstants.connectivityConnected,
    );
  } else {
    if (connectivityResult == ConnectivityResult.mobile) {
      return ConnectivityInfo(
        status: ConnectionStatus.mobileDataNoInternet,
        connectionType: connectionType,
        message: AppConstants.connectivityMobileNoInternet,
        isMobileDataWithoutInternet: true,
      );
    } else if (connectivityResult == ConnectivityResult.wifi) {
      return ConnectivityInfo(
        status: ConnectionStatus.noInternet,
        connectionType: connectionType,
        message: AppConstants.connectivityWifiNoInternet,
      );
    } else {
      return ConnectivityInfo(
        status: ConnectionStatus.noInternet,
        connectionType: connectionType,
        message: AppConstants.connectivityNetworkNoInternet,
      );
    }
  }
}

Future<bool> _testInternetAccess(ConnectivityResult connectionType) async {
  try {
    for (int attempt = 0; attempt < AppConstants.connectivityTestAttempts; attempt++) {
      // Duplicate the test URLs here since we can't access private static members from another file
      const testUrls = [
        'google.com',
        '8.8.8.8',
        'cloudflare.com',
        '1.1.1.1',
        'facebook.com',
      ];
      for (String url in testUrls) {
        try {
          final result = await InternetAddress.lookup(
            url,
          ).timeout(const Duration(seconds: AppConstants.connectivityDnsTimeoutSeconds));

          if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
            if (connectionType == ConnectivityResult.mobile) {
              return await _testHttpConnection();
            }
            return true;
          }
        } catch (e) {
          continue;
        }
      }
      if (attempt == 0) {
        await Future.delayed(const Duration(seconds: AppConstants.connectivityRetryDelaySeconds));
      }
    }
    return false;
  } catch (e) {
    return false;
  }
}

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
