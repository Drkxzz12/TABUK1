// ===========================================
// lib/screens/sign_up_screen.dart
// ===========================================
// Sign up screen for new user registration.

import 'package:flutter/material.dart';
import 'package:capstone_app/models/connectivity_info.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:capstone_app/utils/constants.dart';
import 'package:capstone_app/widgets/custom_text_field.dart';
import 'package:capstone_app/widgets/custom_button.dart';
import 'package:capstone_app/services/auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_app/services/connectivity_service.dart';

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
    try {
      _selectedRole = _roles[0]; // Initialize with first role
    } catch (e) {
      debugPrint('Error initializing role: $e');
      _selectedRole = null;
    }
  }

  @override
  void dispose() {
    try {
      _emailController.dispose();
      _passwordController.dispose();
      _confirmPasswordController.dispose();
    } catch (e) {
      debugPrint('Error disposing controllers: $e');
    }
    super.dispose();
  }

  /// Validates the email input.
  String? _validateEmail(String? value) {
    try {
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
    } catch (e) {
      debugPrint('Error validating email: $e');
      return 'Email validation error';
    }
  }

  /// Validates the password input.
  String? _validatePassword(String? value) {
    try {
      if (value == null || value.isEmpty) {
        return AppConstants.passwordRequiredError;
      }
      if (value.length < AppConstants.minPasswordLength) {
        return AppConstants.passwordLengthError;
      }
      return null;
    } catch (e) {
      debugPrint('Error validating password: $e');
      return 'Password validation error';
    }
  }

  /// Validates the confirm password input.
  String? _validateConfirmPassword(String? value) {
    try {
      if (value == null || value.isEmpty) {
        return AppConstants.confirmPasswordRequiredError;
      }
      if (value != _passwordController.text) {
        return AppConstants.passwordsDoNotMatchError;
      }
      return null;
    } catch (e) {
      debugPrint('Error validating confirm password: $e');
      return 'Confirm password validation error';
    }
  }

  /// Checks for an active internet connection.
  Future<bool> _checkInternetConnection() async {
    try {
      final info = await ConnectivityService().checkConnection();
      return info.status == ConnectionStatus.connected;
    } catch (e) {
      debugPrint('Error checking internet connection: $e');
      return false;
    }
  }

  /// Enhanced email sign up handler with better error handling
  void _handleEmailSignUp() async {
    try {
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
        // Check if email already exists before attempting to create account
        final emailExists = await AuthService.emailExists(_emailController.text.trim());
        if (emailExists) {
          _showSnackBar(
            'An account with this email already exists. Please use a different email or sign in.',
            Colors.red,
          );
          return;
        }

        final userCredential = await AuthService.signUpWithEmailPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          role: _selectedRole!,
        );

        if (!mounted) return;

        if (userCredential != null) {
          // Always sign out the user after registration
          try {
            await AuthService.signOut();
          } catch (signOutError) {
            debugPrint('Error signing out after registration: $signOutError');
          }

          // Show a message to check email for verification (not a prompt, just info)
          if (mounted) {
            _showSnackBar(
              'Account created! Please check your email to verify your account before logging in.',
              Colors.green,
            );
            // After showing the snackbar, navigate back to login screen after a short delay
            await Future.delayed(const Duration(seconds: 2));
            if (mounted) Navigator.pop(context);
          }
        } else {
          _showSnackBar('Account creation failed. Please try again.', Colors.red);
        }
      } on FirebaseAuthException catch (authError) {
        debugPrint('Firebase Auth error: ${authError.code} - ${authError.message}');
        if (!mounted) return;
        String errorMessage = 'An error occurred during registration';
        switch (authError.code) {
          case 'email-already-in-use':
            errorMessage = 'This email is already in use.';
            break;
          case 'weak-password':
            errorMessage = 'The password is too weak.';
            break;
          case 'invalid-email':
            errorMessage = 'The email address is invalid.';
            break;
          case 'network-request-failed':
            errorMessage = 'Network error. Please check your connection.';
            break;
          case 'operation-not-allowed':
            errorMessage = 'Operation not allowed. Please contact support.';
            break;
          default:
            errorMessage = authError.message ?? 'An error occurred during registration';
        }
        _showSnackBar(errorMessage, Colors.red);
      } catch (e) {
        debugPrint('Unexpected error in sign up process: $e');
        if (!mounted) return;
        // Handle platform or other errors that mention account already exists
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('already exists') || errorStr.contains('account already exists')) {
          _showSnackBar('This email is already in use.', Colors.red);
        } else {
          _showSnackBar('An unexpected error occurred. Please try again.', Colors.red);
        }
      }
    } catch (e) {
      debugPrint('Critical error in sign up process: $e');
      if (!mounted) return;
      _showSnackBar('A critical error occurred. Please try again.', Colors.red);
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
    try {
      Navigator.pop(context); // Go back to login screen
    } catch (e) {
      debugPrint('Error navigating to sign in: $e');
      _showSnackBar('Navigation error occurred', Colors.red);
    }
  }

  /// Toggles the password visibility.
  void _togglePasswordVisibility() {
    try {
      setState(() {
        _isPasswordVisible = !_isPasswordVisible;
      });
    } catch (e) {
      debugPrint('Error toggling password visibility: $e');
    }
  }

  /// Toggles the confirm password visibility.
  void _toggleConfirmPasswordVisibility() {
    try {
      setState(() {
        _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
      });
    } catch (e) {
      debugPrint('Error toggling confirm password visibility: $e');
    }
  }

  /// Clears the email error message.
  void _clearEmailError() {
    try {
      if (_emailError != null) {
        setState(() {
          _emailError = null;
        });
      }
    } catch (e) {
      debugPrint('Error clearing email error: $e');
    }
  }

  /// Clears the password error message.
  void _clearPasswordError() {
    try {
      if (_passwordError != null) {
        setState(() {
          _passwordError = null;
        });
      }
    } catch (e) {
      debugPrint('Error clearing password error: $e');
    }
  }

  /// Clears the confirm password error message.
  void _clearConfirmPasswordError() {
    try {
      if (_confirmPasswordError != null) {
        setState(() {
          _confirmPasswordError = null;
        });
      }
    } catch (e) {
      debugPrint('Error clearing confirm password error: $e');
    }
  }

  /// Shows a [SnackBar] with the given [message] and [backgroundColor].
  void _showSnackBar(String message, Color backgroundColor) {
    try {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: Duration(seconds: AppConstants.snackBarDurationSeconds),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Error showing snackbar: $e');
    }
  }

  /// Builds the app logo widget.
  Widget _buildLogo() {
    try {
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
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Error loading logo image: $error');
              return _buildFallbackLogo();
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error building logo: $e');
      return _buildFallbackLogo();
    }
  }

  /// Builds a fallback logo if the asset fails to load.
  Widget _buildFallbackLogo() {
    try {
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
    } catch (e) {
      debugPrint('Error building fallback logo: $e');
      return const SizedBox(
        width: 80,
        height: 80,
        child: Icon(Icons.error, color: Colors.red),
      );
    }
  }

 /// Builds the email input field with error display.
Widget _buildEmailField() {
  try {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextField(
          controller: _emailController,
          hintText: AppConstants.email,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) {
            _clearEmailError();
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
  } catch (e) {
    debugPrint('Error building email field: $e');
    return const SizedBox(height: 60);
  }
}

/// Builds the password input field with error display and visibility toggle.
Widget _buildPasswordField() {
  try {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextField(
          controller: _passwordController,
          hintText: AppConstants.password,
          obscureText: !_isPasswordVisible,
          onChanged: (_) {
            _clearPasswordError();
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
  } catch (e) {
    debugPrint('Error building password field: $e');
    return const SizedBox(height: 60);
  }
}

/// Builds the confirm password input field with error display and visibility toggle.
Widget _buildConfirmPasswordField() {
  try {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomTextField(
          controller: _confirmPasswordController,
          hintText: AppConstants.confirmPassword,
          obscureText: !_isConfirmPasswordVisible,
          onChanged: (_) {
            _clearConfirmPasswordError();
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
  } catch (e) {
    debugPrint('Error building confirm password field: $e');
    return const SizedBox(height: 60);
  }
}

  /// Builds the role selection dropdown.
  Widget _buildRoleSelection() {
    try {
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
              try {
                if (value != null) {
                  setState(() {
                    _selectedRole = value;
                  });
                }
              } catch (e) {
                debugPrint('Error changing role selection: $e');
              }
            },
            validator: (value) {
              try {
                if (value == null || value.isEmpty) {
                  return AppConstants.selectRoleError;
                }
                return null;
              } catch (e) {
                debugPrint('Error validating role selection: $e');
                return 'Role validation error';
              }
            },
          ),
        ],
      );
    } catch (e) {
      debugPrint('Error building role selection: $e');
      return const SizedBox(height: 60);
    }
  }

  /// Builds the sign up button.
  Widget _buildSignUpButton() {
    try {
      return CustomButton(
        text: _isLoading ? AppConstants.creatingAccount : AppConstants.signUpWithEmail,
        onPressed: _isLoading ? () {} : _handleEmailSignUp,
      );
    } catch (e) {
      debugPrint('Error building sign up button: $e');
      return const SizedBox(height: 50);
    }
  }

  /// Builds the sign in prompt below the sign up form.
  Widget _buildSignInPrompt() {
    try {
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
    } catch (e) {
      debugPrint('Error building sign in prompt: $e');
      return const SizedBox(height: 20);
    }
  }

  /// Builds the sign up screen UI.
  @override
  Widget build(BuildContext context) {
    try {
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
    } catch (e) {
      debugPrint('Error building SignUpScreen: $e');
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'An error occurred while loading the sign-up screen',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }
  }
}