// ===========================================
// lib/widgets/social_login_button.dart
// ===========================================
// Button for social login (Google, Facebook, etc.) with icon or image.

import 'package:flutter/material.dart';
import 'package:capstone_app/utils/constants.dart';

/// Button for social login (Google, Facebook, etc.) with icon or image.
class SocialLoginButton extends StatelessWidget {
  /// The button label text.
  final String text;
  /// The icon to display if no image is provided.
  final IconData? icon;
  /// The asset path for the image to display.
  final String? imagePath;
  /// The background color of the button.
  final Color backgroundColor;
  /// The text color of the button.
  final Color textColor;
  /// Callback when the button is pressed.
  final VoidCallback onPressed;

  /// Creates a [SocialLoginButton].
  const SocialLoginButton({
    super.key,
    required this.text,
    this.icon,
    this.imagePath,
    required this.backgroundColor,
    required this.textColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: AppConstants.buttonHeight,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
            side: backgroundColor == Colors.white
                ? BorderSide(color: Colors.grey.withOpacity(0.3))
                : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (imagePath != null && imagePath!.isNotEmpty)
              Image.asset(
                imagePath!,
                width: AppConstants.socialIconSize,
                height: AppConstants.socialIconSize,
                errorBuilder: (context, error, stackTrace) {
                  // Always fallback to icon if image fails to load
                  return Icon(icon ?? Icons.login, size: AppConstants.socialIconSize, color: textColor);
                },
              )
            else
              Icon(icon ?? Icons.login, size: AppConstants.socialIconSize, color: textColor),
            const SizedBox(width: AppConstants.socialIconSpacing),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: AppConstants.buttonFontSize,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                  overflow: TextOverflow.ellipsis,
                ),
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
