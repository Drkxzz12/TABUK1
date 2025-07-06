// ===========================================
  // lib/screens/login_screen.dart
  // ===========================================
  // Login screen for user authentication (email, Google, etc.).


// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:capstone_app/models/connectivity_info.dart';
  import 'package:flutter/foundation.dart' show kIsWeb;
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:google_sign_in/google_sign_in.dart';

  // App imports
  import 'package:capstone_app/utils/constants.dart';
  import 'package:capstone_app/utils/colors.dart';
  import 'package:capstone_app/utils/navigation_helper.dart';
  import 'package:capstone_app/widgets/custom_text_field.dart';
  import 'package:capstone_app/widgets/social_login_button.dart';
  import 'package:capstone_app/widgets/custom_button.dart';
  import 'package:capstone_app/screens/sign_up_screen.dart';
  import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/services/connectivity_service.dart';
  import 'package:capstone_app/screens/tourist_module/registration_gate.dart';
  import 'package:capstone_app/screens/tourist_module/main_tourist_screen.dart';
  import 'package:capstone_app/services/google_verification_helper.dart';

  /// Login screen for user authentication.
  class LoginScreen extends StatefulWidget {
    /// Creates a [LoginScreen].
    const LoginScreen({super.key});

    @override
    State<LoginScreen> createState() => _LoginScreenState();
  }

  class _LoginScreenState extends State<LoginScreen> {
    // Controllers
    final _emailController = TextEditingController();
    final _passwordController = TextEditingController();

    // State variables
    bool _isPasswordVisible = false;
    bool _isLoading = false;
    String? _emailError;
    String? _passwordError;
    
    @override
    void dispose() {
      _emailController.dispose();
      _passwordController.dispose();
      // Removed EmailVerificationHelper.dispose(); as it's not needed
      super.dispose();
    }

    // Validation methods
    /// Validates the email input.
    String? _validateEmail(String? value) {
      if (value?.isEmpty ?? true) return AppConstants.emailRequired;
      final emailRegex = RegExp(AppConstants.emailRegexPattern);
      if (!emailRegex.hasMatch(value!)) {
        return AppConstants.invalidEmailMessage;
      }
      return null;
    }

    /// Validates the password input.
    String? _validatePassword(String? value) {
      if (value?.isEmpty ?? true) return AppConstants.passwordRequired;
      if (value!.length < AppConstants.minPasswordLength) return AppConstants.passwordTooShortMessage;
      return null;
    }

    // Utility methods
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

    /// Clears any error messages from the form fields.
    void _clearErrors() {
      if (_emailError != null || _passwordError != null) {
        setState(() {
          _emailError = null;
          _passwordError = null;
        });
      }
    }

    /// Checks for an active internet connection.
    Future<bool> _checkInternetConnection() async {
      final info = await ConnectivityService().checkConnection();
      final isOnline = info.status == ConnectionStatus.connected;
      if (!isOnline && mounted) {
        _showSnackBar(AppConstants.noInternetMessage, AppColors.errorRed);
      }
      return isOnline;
    }

    // Authentication methods
    /// Updated email login handler with better error handling
    Future<void> _handleEmailLogin() async {
      if (!await _checkInternetConnection()) return;

      setState(() {
        _emailError = _validateEmail(_emailController.text);
        _passwordError = _validatePassword(_passwordController.text);
      });

      if (_emailError != null || _passwordError != null) return;

      setState(() => _isLoading = true);

      try {
        final userCredential = await AuthService.signInWithEmailPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        if (!mounted) return;

        if (userCredential != null) {
          final uid = userCredential.user!.uid;
          // Use EMAIL provider verification
          final isVerified = await GoogleVerificationHelper.handleProviderVerification(
            uid: uid,
            provider: 'email',
            isNewUser: false,
          );
          if (!isVerified) {
            _showEmailVerificationScreen();
            return;
          }
          await _handleSuccessfulAuth(uid);
        }
      } catch (e) {
        if (mounted) _showSnackBar(e.toString(), Colors.red);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }

    /// Updated Google sign-in handler with better verification flow
    Future<void> _handleGoogleSignIn() async {
      if (!await _checkInternetConnection()) return;
      setState(() => _isLoading = true);
      try {
        // Always sign out before sign-in to force account selection
        if (kIsWeb) {
          await FirebaseAuth.instance.signOut();
        } else {
          await GoogleSignIn().signOut();
        }
        try {
          final userCredential = await AuthService.signInWithGoogle();
          if (!mounted) return;
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            _showSnackBar('Google authentication failed. Please try again.', Colors.red);
            debugPrint('Google sign-in: user is null');
            return;
          }
          final isNewUser = userCredential?.additionalUserInfo?.isNewUser ?? false;
          final uid = user.uid;
          // Always ensure Firestore user doc exists
          try {
            final userDoc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
            if (!userDoc.exists) {
              await AuthService.storeUserData(
                uid,
                user.email ?? '',
                '', // No role yet
                username: user.displayName ?? '',
                appEmailVerified: true, // Google users are pre-verified
              );
              debugPrint('Google sign-in: Firestore user doc created for $uid');
            }
          } catch (e) {
            debugPrint('Google sign-in: error ensuring Firestore user doc: $e');
          }
          // Google verification should always pass
          final isVerified = await GoogleVerificationHelper.handleProviderVerification(
            uid: uid,
            provider: 'google',
            isNewUser: isNewUser,
          );
          debugPrint('Google sign-in: isVerified = $isVerified');
          // Check if user has a role
          final userDoc = await FirebaseFirestore.instance.collection('Users').doc(uid).get();
          final existingRole = userDoc.data()?['role'];
          final roleMissing = existingRole == null || (existingRole is String && existingRole.trim().isEmpty);
          if (isVerified) {
            if (roleMissing) {
              // New user or no role, show role selection dialog
              await Future.delayed(const Duration(milliseconds: 100)); // Ensure UI is ready
              _showRoleSelectionDialog(uid);
              _showSnackBar('Please select your role to continue.', Colors.orange);
            } else {
              await _handleSuccessfulAuth(uid);
              _showSnackBar('Google sign-in successful!', Colors.green);
            }
          } else {
            debugPrint('ERROR: Google user verification failed - this should not happen');
            _showSnackBar('Google sign-in verification failed. Please try again.', Colors.red);
          }
        } on FirebaseAuthException catch (e) {
          if (e.code == 'account-exists-with-different-credential') {
            // The account already exists with a different credential
            final pendingCred = e.credential;
            final email = e.email;
            _showSnackBar('This email is already registered with another sign-in method. Please login with email and password to link your Google account.', Colors.orange);
            // Prompt for password and link
            await _showLinkAccountDialog(email, pendingCred);
          } else {
            _showSnackBar('Google Sign-In failed: ${e.message}', Colors.red);
          }
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('Google Sign-In failed: ${e.toString()}', Colors.red);
          debugPrint('Google sign-in: exception: ${e.toString()}');
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }

    /// Dialog to prompt for password and link Google credential
    Future<void> _showLinkAccountDialog(String? email, AuthCredential? pendingCred) async {
      if (email == null || pendingCred == null) return;
      String password = '';
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Link Google Account'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Enter your password for $email to link your Google account.'),
                const SizedBox(height: 16),
                TextField(
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                  onChanged: (val) => password = val,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    final emailUser = await AuthService.signInWithEmailPassword(email: email, password: password);
                    if (emailUser != null) {
                      await emailUser.user?.linkWithCredential(pendingCred);
                      Navigator.of(dialogContext).pop();
                      _showSnackBar('Accounts linked! You can now sign in with Google.', Colors.green);
                      await _handleSuccessfulAuth(emailUser.user!.uid);
                    } else {
                      _showSnackBar('Failed to sign in with email/password.', Colors.red);
                    }
                  } on FirebaseAuthException catch (e) {
                    _showSnackBar(e.message ?? 'Failed to link accounts.', Colors.red);
                  }
                },
                child: const Text('Link'),
              ),
            ],
          );
        },
      );
    }

    /// Show the email verification screen for email sign-in only
    void _showEmailVerificationScreen() {
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      if (user?.email == null) return;
      debugPrint('Navigating to EmailVerificationScreen for: ${user?.email}');
      
      GoogleVerificationHelper.showEmailVerificationScreen(
        context,
        user!.email!,
        onVerificationComplete: () async {
          await AuthService.setAppEmailVerified(user.uid);
          if (mounted) {
            Navigator.of(context).pop(); // Close verification screen
            await _handleSuccessfulAuth(user.uid);
            _showSnackBar('Email verified successfully!', Colors.green);
          }
        },
        showBackButton: true,
      );
    }

    /// Improved success handler with better error handling
    Future<void> _handleSuccessfulAuth(String uid) async {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('Users') // Make sure this matches your collection name
            .doc(uid)
            .get();
        if (!mounted) return;
        final existingRole = userDoc.data()?['role'];
        if (existingRole?.toString().isNotEmpty == true) {
          if (existingRole == 'Tourist') {
            // Check if tourist is already registered
            final touristDoc = await FirebaseFirestore.instance
                .collection('tourist_preferences')
                .doc(uid)
                .get();
            if (!mounted) return;
            final isRegistered = touristDoc.data()?['isRegistered'] == true;
            if (isRegistered) {
              // Go to main tourist screen
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const MainTouristScreen()),
                (route) => false,
              );
            } else {
              // Go to registration flow
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const RegistrationGate()),
                (route) => false,
              );
            }
          } else {
            NavigationHelper.navigateBasedOnRole(context, existingRole);
          }
        } else {
          _showRoleSelectionDialog(uid);
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('Error checking user data: $e', Colors.red);
        }
      }
    }

    // Dialog methods
    /// Shows a dialog for role selection after authentication.
    void _showRoleSelectionDialog(String uid) {
      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _RoleSelectionDialog(
          onRoleSelected: (role) => _handleRoleSelection(uid, role),
        ),
      );
    }

    /// Handles the selected role and updates the user document.
    Future<void> _handleRoleSelection(String uid, String role) async {
      try {
        await AuthService.storeUserData(
          uid,
          FirebaseAuth.instance.currentUser?.email ?? '',
          role,
        );
        
        if (!mounted) return;
        
        _showSnackBar('Role set successfully!', Colors.green);
        if (role == 'Tourist') {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const RegistrationGate()),
            (route) => false,
          );
        } else {
          NavigationHelper.navigateBasedOnRole(context, role);
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar('Failed to set role: $e', Colors.red);
        }
      }
    }


    /// Shows a dialog for password reset.
    void _showForgotPasswordDialog() {
      showDialog(
        context: context,
        builder: (context) => _ForgotPasswordDialog(
          initialEmail: _emailController.text.trim(),
          onPasswordResetSent: (message) => _showSnackBar(message, AppColors.primaryTeal),
          onError: (error) => _showSnackBar(error, Colors.red),
        ),
      );
    }

    // UI Builder methods
    /// Builds the login screen UI.
    @override
    Widget build(BuildContext context) {
      return Scaffold(
        resizeToAvoidBottomInset: true,
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.signUpFormHorizontalPadding),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: AppConstants.signUpFormTopSpacing),
                    _buildLogo(),
                    const SizedBox(height: AppConstants.signUpFormSectionSpacing),
                    _buildEmailField(),
                    const SizedBox(height: AppConstants.signUpFormSectionSpacing),
                    _buildPasswordField(),
                    const SizedBox(height: AppConstants.signUpFormSectionSpacing),
                    _buildLoginButton(),
                    const SizedBox(height: AppConstants.signUpFormButtonSpacing),
                    _buildSocialLoginButtons(),
                    const SizedBox(height: AppConstants.signUpFormButtonSpacing),
                    _buildSignUpPrompt(),
                    const SizedBox(height: AppConstants.signUpFormButtonSpacing),
                  
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    /// Builds the app logo widget.
    Widget _buildLogo() {
      return const SizedBox(
        width: AppConstants.logoSize,
        height: AppConstants.logoSize,
        child: _OptimizedLogo(),
      );
    }

    /// Builds the social login buttons (Google, Guest).
    Widget _buildSocialLoginButtons() {
      return Column(
        children: [
          _buildGoogleSignInButton(),
          const SizedBox(height: 12),
          SocialLoginButton(
            text: 'Continue as Guest',
            imagePath: '',
            backgroundColor: AppColors.primaryTeal,
            textColor: AppColors.white,
            onPressed: _handleGuestLogin,
          ),
        ],
      );
    }

    /// Builds the Google sign-in button.
    Widget _buildGoogleSignInButton() {
      return Container(
        width: double.infinity,
        height: AppConstants.googleButtonHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
          border: Border.all(color: AppColors.inputBorder.withOpacity(0.3)),
        ),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppConstants.buttonBorderRadius),
            onTap: _handleGoogleSignIn,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.googleButtonHorizontalPadding),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/images/icons8-google-48.png',
                    width: AppConstants.googleIconSize,
                    height: AppConstants.googleIconSize,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.g_mobiledata,
                      size: 24,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: AppConstants.socialIconSpacing),
                  const Text(
                    AppConstants.signInWithGoogle,
                    style: TextStyle(
                      fontSize: AppConstants.buttonFontSize,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    /// Builds the email input field with error display.
    Widget _buildEmailField() {
      return _FormFieldWithError(
        field: CustomTextField(
          controller: _emailController,
          hintText: AppConstants.email,
          keyboardType: TextInputType.emailAddress,
          onChanged: (_) => _clearErrors(),
        ),
        error: _emailError,
      );
    }

    /// Builds the password input field with error display and visibility toggle.
    Widget _buildPasswordField() {
      return Column(
        children: [
          _FormFieldWithError(
            field: CustomTextField(
              controller: _passwordController,
              hintText: AppConstants.password,
              obscureText: !_isPasswordVisible,
              onChanged: (_) => _clearErrors(),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                  color: AppColors.textLight,
                  size: 30,
                ),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
            ),
            error: _passwordError,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showForgotPasswordDialog,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryTeal,
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              child: Text(AppConstants.forgotPassword),
            ),
          ),
        ],
      );
    }

    /// Builds the login button.
    Widget _buildLoginButton() {
      return CustomButton(
        text: _isLoading ? 'Signing In...' : AppConstants.loginWithEmail,
        onPressed: _isLoading
            ? () {}
            : () {
                _handleEmailLogin();
              },
      );
    }

    /// Builds the sign-up prompt at the bottom of the screen.
    Widget _buildSignUpPrompt() {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            AppConstants.dontHaveAccount,
            style: const TextStyle(color: AppColors.textLight, fontSize: 12),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SignUpScreen()),
            ),
            child: Text(
              AppConstants.signUp,
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

    /// Handles guest login (anonymous sign-in).
    Future<void> _handleGuestLogin() async {
      if (!await _checkInternetConnection()) return;

      setState(() => _isLoading = true);

      try {
        final userCredential = await AuthService.signInAnonymously();
        if (!mounted) return;
        if (userCredential != null) {
          _showSnackBar('Signed in as guest.', Colors.green);
          NavigationHelper.navigateBasedOnRole(context, 'guest');
        }
      } catch (e) {
        if (mounted) _showSnackBar(e.toString(), Colors.red);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  // Extracted widgets for better organization
  class _FormFieldWithError extends StatelessWidget {
    final Widget field;
    final String? error;

    const _FormFieldWithError({required this.field, this.error});

    @override
    Widget build(BuildContext context) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          field,
          if (error != null) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                error!,
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      );
    }
  }

  class _RoleSelectionDialog extends StatefulWidget {
    final Function(String) onRoleSelected;

    const _RoleSelectionDialog({required this.onRoleSelected});

    @override
    State<_RoleSelectionDialog> createState() => _RoleSelectionDialogState();
  }

  class _RoleSelectionDialogState extends State<_RoleSelectionDialog> {
    String _selectedRole = 'Tourist';
    static const _roles = ['Business Owner', 'Tourist', 'Administrator'];

    @override
    Widget build(BuildContext context) {
      return AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Select Your Role',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: DropdownButtonFormField<String>(
          value: _selectedRole,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.3)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: _roles.map((role) => DropdownMenuItem(
            value: role,
            child: Text(
              role,
              style: const TextStyle(color: AppColors.textDark, fontSize: 14),
            ),
          )).toList(),
          onChanged: (value) {
            if (value != null) setState(() => _selectedRole = value);
          },
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: AppColors.primaryTeal,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              widget.onRoleSelected(_selectedRole);
            },
            child: const Text(
              'Continue',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      );
    }
  }

  // ignore: unused_element
  class _EmailVerificationDialog extends StatelessWidget {
    final VoidCallback onResendPressed;

    const _EmailVerificationDialog({required this.onResendPressed});

    @override
    Widget build(BuildContext context) {
      return AlertDialog(
        title: Text(
          AppConstants.emailNotVerifiedTitle,
          style: const TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          AppConstants.emailNotVerifiedContent,
          style: const TextStyle(color: AppColors.textLight, fontSize: 14),
        ),
        actions: [
          _DialogButton(
            text: AppConstants.cancelButton,
            backgroundColor: AppColors.primaryTeal,
            onPressed: () async {
              Navigator.of(context).pop();
              await AuthService.signOut();
            },
          ),
          _DialogButton(
            text: AppConstants.resendEmailButton,
            backgroundColor: AppColors.primaryOrange,
            onPressed: () {
              Navigator.of(context).pop();
              onResendPressed();
            },
          ),
        ],
      );
    }
  }

  class _ForgotPasswordDialog extends StatefulWidget {
    final String initialEmail;
    final Function(String) onPasswordResetSent;
    final Function(String) onError;

    const _ForgotPasswordDialog({
      required this.initialEmail,
      required this.onPasswordResetSent,
      required this.onError,
    });

    @override
    State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
  }

  class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
    late final TextEditingController _emailController;

    @override
    void initState() {
      super.initState();
      _emailController = TextEditingController(text: widget.initialEmail);
    }

    @override
    void dispose() {
      _emailController.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      return AlertDialog(
        title: Text(
          AppConstants.forgotPassword,
          style: const TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: TextField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: AppConstants.email,
            border: const OutlineInputBorder(),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        actions: [
          _DialogButton(
            text: AppConstants.cancelButton,
            backgroundColor: AppColors.primaryTeal,
            onPressed: () => Navigator.of(context).pop(),
          ),
          _DialogButton(
            text: 'Send Reset Link',
            backgroundColor: AppColors.primaryOrange,
            onPressed: () => _handlePasswordReset(),
          ),
        ],
      );
    }

    Future<void> _handlePasswordReset() async {
      final email = _emailController.text.trim();
      if (email.isEmpty) {
        widget.onError('Please enter your email address.');
        return;
      }

      try {
        await AuthService.sendPasswordResetEmail(email);
        if (mounted) {
        Navigator.of(context).pop(); // ✅ Protected with mounted check
        }
        widget.onPasswordResetSent('Password reset email sent. Please check your inbox.');
      } catch (e) {
        widget.onError(e.toString());
      }
    }
  }

  class _DialogButton extends StatelessWidget {
    final String text;
    final Color backgroundColor;
    final VoidCallback onPressed;

    const _DialogButton({
      required this.text,
      required this.backgroundColor,
      required this.onPressed,
    });

    @override
    Widget build(BuildContext context) {
      return TextButton(
        style: TextButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      );
    }
  }

  class _OptimizedLogo extends StatelessWidget {
    const _OptimizedLogo();

    @override
    Widget build(BuildContext context) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.asset(
          'assets/images/TABUK-new-logo.png',
          width: 220,
          height: 220,
          fit: BoxFit.contain,
          cacheWidth: 220,
          cacheHeight: 220,
          errorBuilder: (context, error, stackTrace) => const _LogoFallback(),
        ),
      );
    }
  }

  class _LogoFallback extends StatelessWidget {
    const _LogoFallback();

    @override
    Widget build(BuildContext context) {
      return Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          color: AppColors.primaryOrange,
          borderRadius: BorderRadius.circular(16),
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
            const Icon(Icons.landscape, size: 60, color: AppColors.primaryTeal),
            Positioned(
              bottom: 20,
              child: Text(
                AppConstants.appName,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }