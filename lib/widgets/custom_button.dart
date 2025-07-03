// ===========================================
// lib/widgets/custom_button.dart
// ===========================================
// Custom styled button for consistent UI.

import 'package:flutter/material.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:capstone_app/utils/constants.dart';

/// Custom button widget for the app, providing consistent styling.
class CustomButton extends StatelessWidget {
  /// The button label text.
  final String text;
  /// The callback when the button is pressed.
  final void Function()? onPressed;

  /// Creates a [CustomButton].
  const CustomButton({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppConstants.buttonHeight,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.textDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
            side: BorderSide(
              color: AppColors.buttonBorder,
              width: AppConstants.buttonBorderWidth,
            ),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: AppConstants.buttonFontSize,
            fontWeight: FontWeight.w500,
            color: AppColors.buttonText,
          ),
        ),
      ),
    );
  }
}
