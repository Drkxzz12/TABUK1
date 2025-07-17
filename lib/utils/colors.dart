// ===========================================
// lib/utils/colors.dart
// ===========================================
// Centralized color palette for the Tabuk app.

import 'package:flutter/material.dart';

class AppColors {
  static const Color gradientStart = Color(0xFFFFF3CF);
  static const Color gradientEnd = Colors.white;

  // Original colors for compatibility
  static const Color primaryOrange = Color(0xFFFF8C42);
  static const Color primaryTeal = Color(0xFF2E8B8B);
  static const Color backgroundColor = Color(0xFFF5F5DC);
  static const Color textDark = Color(0xFF333333);
  static const Color textLight = Color(0xFF666666);
  static const Color white = Color(0xFFFFFFFF);
  static const Color googleBlue = Color(0xFF4285F4);
  static const Color facebookBlue = Color(0xFF1877F2);
  static const Color cardBackground = white;
  static const Color imagePlaceholder = Color(0xFFE0E0E0);
  static const Color buttonBorder = Color(0xFF666666);
  static const Color buttonText = Colors.black;

  // Add missing color and property getters for compatibility
  static const Color errorRed = Color(0xFFD32F2F);
  static const Color inputBorder = Color(0xFFBDBDBD);
  static const Color homeForYouColor = Color(0xFF42A5F5);
  static const Color homeTrendingColor = Color(0xFFFFA726);
  static const Color homeNearbyColor = Color(0xFF66BB6A);
  static const Color homeSeasonalColor = Color(0xFFAB47BC);
  static const Color profileSignOutButtonColor = Color(0xFFD32F2F);

  // Gradient background
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [gradientStart, gradientEnd],
    stops: [0.0, 1.0],
  );

 
}
