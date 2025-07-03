// ===========================================
// lib/widgets/custom_text_field.dart
// ===========================================
// Custom styled text field for consistent UI.

import 'package:flutter/material.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:capstone_app/utils/constants.dart';

/// Custom text field widget for the app, providing consistent styling.
class CustomTextField extends StatelessWidget {
  /// The controller for the text field.
  final TextEditingController controller;
  /// The hint text to display.
  final String hintText;
  /// Whether to obscure the text (e.g., for passwords).
  final bool obscureText;
  /// Callback for when the text changes.
  final ValueChanged<String>? onChanged;
  /// Validator for form field usage.
  final String? Function(String?)? validator;
  /// Optional suffix icon widget.
  final Widget? suffixIcon;
  /// The keyboard type for the text field.
  final TextInputType? keyboardType;

  /// Creates a [CustomTextField].
  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.onChanged,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppConstants.textFieldBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        validator: validator,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: AppColors.textLight, fontSize: AppConstants.textFieldFontSize),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppConstants.textFieldBorderRadius),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppConstants.textFieldHorizontalPadding,
            vertical: AppConstants.textFieldVerticalPadding,
          ),
          suffixIcon: suffixIcon,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
