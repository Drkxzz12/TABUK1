// ===========================================
// lib/widgets/connectivity_widget.dart
// ===========================================
// Widget for displaying connectivity status to the user.

import 'package:flutter/material.dart';
import 'package:capstone_app/models/connectivity_info.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:capstone_app/utils/colors.dart';
// ...existing code...

/// Widget that shows the current connectivity status.
class ConnectivityStatusIndicator extends StatelessWidget {
  /// The current connectivity information to display.
  final ConnectivityInfo connectivityInfo;

  /// Creates a [ConnectivityStatusIndicator].
  const ConnectivityStatusIndicator({
    super.key,
    required this.connectivityInfo,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: _getStatusColor().withOpacity(0.2),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: _getStatusColor(), width: 1.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildStatusIcon(),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              connectivityInfo.message,
              style: TextStyle(
                color: _getStatusColor(),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the icon representing the current connectivity status.
  Widget _buildStatusIcon() {
    switch (connectivityInfo.status) {
      case ConnectionStatus.checking:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: _getStatusColor(),
          ),
        );
      case ConnectionStatus.connected:
        return Icon(
          connectivityInfo.connectionType == ConnectivityResult.mobile
              ? Icons.signal_cellular_4_bar
              : Icons.wifi,
          color: _getStatusColor(),
          size: 20,
        );
      default:
        return Icon(
          connectivityInfo.connectionType == ConnectivityResult.mobile
              ? Icons.signal_cellular_off
              : Icons.wifi_off,
          color: _getStatusColor(),
          size: 20,
        );
    }
  }

  /// Returns the color associated with the current connectivity status.
  Color _getStatusColor() {
    switch (connectivityInfo.status) {
      case ConnectionStatus.checking:
        return AppColors.primaryOrange;
      case ConnectionStatus.connected:
        return Colors.green;
      case ConnectionStatus.mobileDataNoInternet:
        return Colors.orange;
      default:
        return Colors.red;
    }
  }
}

/// Card widget that displays a warning when mobile data is enabled but no internet is available.
class MobileDataWarningCard extends StatelessWidget {
  /// Creates a [MobileDataWarningCard].
  const MobileDataWarningCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300, width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade700,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Mobile Data Issue Detected',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Your mobile data is enabled but there\'s no internet access. This could mean:',
            style: TextStyle(color: Colors.orange.shade700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWarningPoint('• You have no mobile data balance/load'),
              _buildWarningPoint('• Your data plan has expired'),
              _buildWarningPoint('• Your mobile data is restricted'),
              _buildWarningPoint('• Poor network signal in your area'),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade300),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Colors.orange.shade700,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Please check your mobile data balance or connect to WiFi',
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a single warning point in the warning list.
  Widget _buildWarningPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
      ),
    );
  }
}

/// Button widget for retrying connectivity or showing progress.
class ConnectivityActionButton extends StatelessWidget {
  /// The current connectivity information.
  final ConnectivityInfo connectivityInfo;
  /// Callback to retry the connection.
  final VoidCallback onRetry;
  /// Whether the app is currently navigating (e.g., logging in).
  final bool isNavigating;

  /// Creates a [ConnectivityActionButton].
  const ConnectivityActionButton({
    super.key,
    required this.connectivityInfo,
    required this.onRetry,
    this.isNavigating = false,
  });

  @override
  Widget build(BuildContext context) {
    // Show navigation loading only when isNavigating is true
    if (isNavigating) {
      return const Column(
        children: [
          CircularProgressIndicator(
            color: AppColors.primaryOrange,
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'Proceeding to login...',
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      );
    }

    // Show checking loading
    if (connectivityInfo.status == ConnectionStatus.checking) {
      return const Column(
        children: [
          CircularProgressIndicator(
            color: AppColors.primaryOrange,
            strokeWidth: 3,
          ),
          SizedBox(height: 16),
          Text(
            'Checking connection...',
            style: TextStyle(
              color: AppColors.textLight,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      );
    }

    // Show retry button for all error states
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, color: Colors.white),
          label: const Text(
            'Retry Connection',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryOrange,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Text(
            connectivityInfo.isMobileDataWithoutInternet
                ? 'Please ensure you have sufficient mobile data balance or connect to a WiFi network with internet access.'
                : 'This app requires an active internet connection to function properly.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textLight, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
