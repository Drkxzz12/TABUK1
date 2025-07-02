// ===========================================
// lib/screens/sign_up_screen.dart
// ===========================================
// Sign up screen for new user registration.

import 'package:flutter/material.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:capstone_app/utils/constants.dart';
import 'package:capstone_app/widgets/custom_text_field.dart';
import 'package:capstone_app/widgets/custom_button.dart';
import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/services/connectivity_service.dart';
import 'package:capstone_app/screens/tourist_module/registration_gate.dart';

/// Sign up screen for new user registration.
class SignUpScreen extends StatefulWidget {
  /// Creates a [SignUpScreen].
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;

  // Role selection
  String? _selectedRole;
  final List<String> _roles = const [
    'Business Owner',
    'Tourist',
    'Administrator',
  ];

  @override
  void initState() {
    super.initState();
    _selectedRole = _roles[0]; // Initialize with first role
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Validates the email input.
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return AppConstants.emailRequiredError;
    }
    final emailRegex = RegExp(
      AppConstants.emailRegex,
    );
    if (!emailRegex.hasMatch(value)) {
      return AppConstants.invalidEmailError;
    }
    return null;
  }

  /// Validates the password input.
  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppConstants.passwordRequiredError;
    }
    if (value.length < AppConstants.minPasswordLength) {
      return AppConstants.passwordLengthError;
    }
    return null;
  }

  /// Validates the confirm password input.
  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return AppConstants.confirmPasswordRequiredError;
    }
    if (value != _passwordController.text) {
      return AppConstants.passwordsDoNotMatchError;
    }
    return null;
  }

  /// Checks for an active internet connection.
  Future<bool> _checkInternetConnection() async {
    final info = await ConnectivityService().checkConnection();
    return info.status == ConnectionStatus.connected;
  }

  /// Handles the email sign up process.
  void _handleEmailSignUp() async {
    if (!await _checkInternetConnection()) {
      _showSnackBar(
        AppConstants.noInternetConnectionError,
        Colors.red,
      );
      return;
    }

    if (_selectedRole == null) {
      _showSnackBar(AppConstants.selectRoleError, Colors.red);
      return;
    }

    setState(() {
      _emailError = _validateEmail(_emailController.text);
      _passwordError = _validatePassword(_passwordController.text);
      _confirmPasswordError = _validateConfirmPassword(
        _confirmPasswordController.text,
      );
    });

    if (_emailError != null ||
        _passwordError != null ||
        _confirmPasswordError != null) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userCredential = await AuthService.signUpWithEmailPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        role: _selectedRole!,
      );

      if (!mounted) return;

      if (userCredential != null) {
        _showSnackBar(
          AppConstants.accountCreationSuccess,
          Colors.green,
        );

        // Sign out the user since they need to verify their email
        await AuthService.signOut();

        // Navigate to RegistrationGate for tourist role
        if (_selectedRole?.toLowerCase() == 'tourist') {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const RegistrationGate(),
            ),
          );
        } else {
          // For other roles, go back to login screen after a delay
          await Future.delayed(const Duration(seconds: 2));
          if (!mounted) return;
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(e.toString(), Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Navigates back to the login screen.
  void _handleSignInNavigation() {
    Navigator.pop(context); // Go back to login screen
  }

  /// Toggles the password visibility.
  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  /// Toggles the confirm password visibility.
  void _toggleConfirmPasswordVisibility() {
    setState(() {
      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
    });
  }

  /// Clears the email error message.
  void _clearEmailError() {
    if (_emailError != null) {
      setState(() {
        _emailError = null;
      });
    }
  }

  /// Clears the password error message.
  void _clearPasswordError() {
    if (_passwordError != null) {
      setState(() {
        _passwordError = null;
      });
    }
  }

  /// Clears the confirm password error message.
  void _clearConfirmPasswordError() {
    if (_confirmPasswordError != null) {
      setState(() {
        _confirmPasswordError = null;
      });
    }
  }

  /// Shows a [SnackBar] with the given [message] and [backgroundColor].
  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: Duration(seconds: AppConstants.snackBarDurationSeconds),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Builds the app logo widget.
  Widget _buildLogo() {
    return SizedBox(
      width: AppConstants.logoSize,
      height: AppConstants.logoSize,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        child: Image.asset(
          'assets/images/TABUK-new-logo.png',
          width: AppConstants.logoSize,
          height: AppConstants.logoSize,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildFallbackLogo(),
        ),
      ));
  }

  /// Builds a fallback logo if the asset fails to load.
  Widget _buildFallbackLogo() {
    return Container(
      width: AppConstants.logoSize,
      height: AppConstants.logoSize,
      decoration: BoxDecoration(
        color: AppColors.primaryOrange,
        borderRadius: BorderRadius.circular(AppConstants.cardBorderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.1 * 255).toInt()),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.landscape, size: AppConstants.cardIconSize, color: AppColors.primaryTeal),
          Positioned(
            bottom: 15,
            child: Text(
              AppConstants.appName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the email input field with error display.
  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextField(
          controller: _emailController,
          hintText: AppConstants.email,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) {
            _clearEmailError();
            return;
          },
          suffixIcon: null,
        ),
        Padding(
          padding: const EdgeInsets.only(left: AppConstants.textFieldHorizontalPadding, top: 2),
          child: Text(
            _emailError ?? '',
            style: TextStyle(
              color: _emailError != null ? Colors.red : Colors.transparent,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the password input field with error display and visibility toggle.
  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextField(
          controller: _passwordController,
          hintText: AppConstants.password,
          obscureText: !_isPasswordVisible,
          onChanged: (_) {
            _clearPasswordError();
            return;
          },
          suffixIcon: IconButton(
            icon: Icon(
              _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
              color: AppColors.textLight,
              size: 30,
            ),
            onPressed: _togglePasswordVisibility,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: AppConstants.textFieldHorizontalPadding, top: 2),
          child: Text(
            _passwordError ?? '',
            style: TextStyle(
              color: _passwordError != null ? Colors.red : Colors.transparent,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the confirm password input field with error display and visibility toggle.
  Widget _buildConfirmPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextField(
          controller: _confirmPasswordController,
          hintText: AppConstants.confirmPassword,
          obscureText: !_isConfirmPasswordVisible,
          onChanged: (_) {
            _clearConfirmPasswordError();
            return;
          },
          suffixIcon: IconButton(
            icon: Icon(
              _isConfirmPasswordVisible ? Icons.visibility_off : Icons.visibility,
              color: AppColors.textLight,
              size: 30,
            ),
            onPressed: _toggleConfirmPasswordVisibility,
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: AppConstants.textFieldHorizontalPadding, top: 2),
          child: Text(
            _confirmPasswordError ?? '',
            style: TextStyle(
              color: _confirmPasswordError != null ? Colors.red : Colors.transparent,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the role selection dropdown.
  Widget _buildRoleSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            AppConstants.role,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        DropdownButtonFormField<String>(
          value: _selectedRole,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppConstants.textFieldBorderRadius),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppConstants.textFieldHorizontalPadding,
              vertical: AppConstants.textFieldVerticalPadding,
            ),
          ),
          items: _roles
              .map(
                (role) => DropdownMenuItem<String>(
                  value: role,
                  child: Text(
                    role,
                    style: const TextStyle(
                      color: AppColors.textDark,
                      fontSize: 14,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (String? value) {
            if (value != null) {
              setState(() {
                _selectedRole = value;
              });
            }
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return AppConstants.selectRoleError;
            }
            return null;
          },
        ),
      ],
    );
  }

  /// Builds the sign up button.
  Widget _buildSignUpButton() {
    return CustomButton(
      text: _isLoading ? AppConstants.creatingAccount : AppConstants.signUpWithEmail,
      onPressed: _isLoading ? () {} : _handleEmailSignUp,
    );
  }

  /// Builds the sign in prompt below the sign up form.
  Widget _buildSignInPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          AppConstants.alreadyHaveAccount,
          style: const TextStyle(color: AppColors.textLight, fontSize: 12),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: _handleSignInNavigation,
          child: Text(
            AppConstants.signIn,
            style: const TextStyle(
              color: Color.fromARGB(255, 66, 151, 255),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Builds the sign up screen UI.
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: true,
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.signUpFormHorizontalPadding),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const SizedBox(height: AppConstants.signUpFormTopSpacing),
                  _buildLogo(),
                  const SizedBox(height: AppConstants.signUpFormSectionSpacing),
                  _buildEmailField(),
                  const SizedBox(height: AppConstants.signUpFormSectionSpacing),
                  _buildPasswordField(),
                  const SizedBox(height: AppConstants.signUpFormSectionSpacing),
                  _buildConfirmPasswordField(),
                  const SizedBox(height: AppConstants.signUpFormSectionSpacing),
                  _buildRoleSelection(),
                  const SizedBox(height: AppConstants.signUpFormButtonSpacing),
                  _buildSignUpButton(),
                  const SizedBox(height: AppConstants.signUpFormButtonSpacing),
                  _buildSignInPrompt(),
                  const SizedBox(height: AppConstants.signUpFormButtonSpacing),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
