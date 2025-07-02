// ===========================================
// lib/services/google_verification_helper.dart (FIXED VERSION)
// ===========================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/utils/constants.dart';
import 'package:capstone_app/utils/colors.dart';
import 'dart:async';

/// Enhanced helper class for handling authentication verification
class GoogleVerificationHelper {
  static const int _maxVerificationAttempts = 5;
  static const Duration _verificationCheckInterval = Duration(seconds: 3);
  
  /// Handles verification flow for different authentication providers
  static Future<bool> handleProviderVerification({
    required String uid,
    required String provider,
    required bool isNewUser,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        debugPrint('handleProviderVerification: User is null');
        return false;
      }

      // Get user document from Firestore with retry logic
      final userDoc = await _getUserDocWithRetry(uid);
      if (userDoc == null) {
        debugPrint('handleProviderVerification: Could not fetch user document');
        return false;
      }

      final userData = userDoc.data();
      final appEmailVerified = (userData as Map<String, dynamic>?)?['app_email_verified'] ?? false;

      debugPrint('Provider: $provider, isNewUser: $isNewUser, emailVerified: ${user.emailVerified}, appEmailVerified: $appEmailVerified');

      // For Google sign-in - Google emails are pre-verified
      if (provider == 'google') {
        return await _handleGoogleVerification(user, uid, isNewUser, appEmailVerified);
      }
      
      // For email sign-in - requires manual verification
      if (provider == 'email') {
        return await _handleEmailVerification(user, uid, appEmailVerified);
      }

      debugPrint('handleProviderVerification: Unknown provider: $provider');
      return false;
    } catch (e) {
      debugPrint('Error in handleProviderVerification: $e');
      return false;
    }
  }

  /// Retry logic for fetching user document
  static Future<DocumentSnapshot?> _getUserDocWithRetry(String uid, {int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('Users')
            .doc(uid)
            .get();
        return userDoc;
      } catch (e) {
        debugPrint('Attempt [33m${i + 1}[0m failed to fetch user doc: $e');
        if (i == maxRetries - 1) rethrow;
        await Future.delayed(Duration(seconds: i + 1));
      }
    }
    return null;
  }

  /// FIXED: Google-specific verification logic
  /// Google accounts are pre-verified, so we just need to sync the status
  static Future<bool> _handleGoogleVerification(
    User user,
    String uid,
    bool isNewUser,
    bool appEmailVerified,
  ) async {
    try {
      // Google accounts are always verified by Google
      // We just need to ensure our app records reflect this
      
      if (!appEmailVerified) {
        // Update our app's verification status to match Google's verification
        await AuthService.setAppEmailVerified(uid, value: true);
        debugPrint('Google user verification status updated in app database');
      }
      
      debugPrint('Google user is verified (Google pre-verification)');
      return true; // Google users are always considered verified
      
    } catch (e) {
      debugPrint('Error in _handleGoogleVerification: $e');
      // Even if there's an error updating the database, 
      // Google users should still be allowed through
      return true;
    }
  }

  /// Email-specific verification logic (unchanged)
  static Future<bool> _handleEmailVerification(
    User user,
    String uid,
    bool appEmailVerified,
  ) async {
    try {
      // Refresh user to get latest verification status
      await user.reload();
      final refreshedUser = FirebaseAuth.instance.currentUser;
      if (refreshedUser == null) return false;

      debugPrint('Email verification: emailVerified=${refreshedUser.emailVerified}, appEmailVerified=$appEmailVerified');
      
      if (refreshedUser.emailVerified && !appEmailVerified) {
        // Firebase verified but app not updated - sync the status
        await AuthService.setAppEmailVerified(uid, value: true);
        debugPrint('Email user verification status synced');
        return true;
      }
      
      return refreshedUser.emailVerified && appEmailVerified;
    } catch (e) {
      debugPrint('Error in _handleEmailVerification: $e');
      return false;
    }
  }

  /// Creates a verification screen for EMAIL sign-in users only
  /// Google users should NOT see this screen
  static void showEmailVerificationScreen(
    BuildContext context,
    String email, {
    required VoidCallback onVerificationComplete,
    bool showBackButton = true,
  }) {
    if (!context.mounted) return;
    
    debugPrint('Navigating to EmailVerificationScreen for: $email');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmailVerificationScreen(
          email: email,
          showBackButton: showBackButton,
          onVerificationComplete: onVerificationComplete,
        ),
      ),
    );
  }

  /// DEPRECATED: Google users should not see verification screens
  /// This method is kept for backward compatibility but should not be used
  @Deprecated('Google users should not see verification screens. This method is a no-op.')
  static void showGoogleVerificationScreen(
    BuildContext context,
    String email, {
    required VoidCallback onVerificationComplete,
    bool showBackButton = true,
  }) {
    debugPrint('WARNING: showGoogleVerificationScreen called - Google users should not need verification');
    // No-op: Immediately complete verification for backward compatibility
    onVerificationComplete();
  }
}

/// Verification screen for EMAIL sign-in users only
/// Google users should NOT see this screen
class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final bool showBackButton;
  final VoidCallback onVerificationComplete;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.onVerificationComplete,
    this.showBackButton = true,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isLoading = false;
  bool _isCheckingVerification = false;
  int _verificationAttempts = 0;
  Timer? _verificationTimer;
  
  @override
  void initState() {
    super.initState();
    // Send initial verification email
    _sendInitialVerificationEmail();
    // Start periodic verification check after a short delay
    _startPeriodicVerificationCheck();
  }

  @override
  void dispose() {
    _verificationTimer?.cancel();
    super.dispose();
  }

  /// Send initial verification email when screen loads
  Future<void> _sendInitialVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.emailVerified) {
      try {
        await user.sendEmailVerification(
          ActionCodeSettings(
            url: AppConstants.authActionUrl,
            handleCodeInApp: true,
            androidInstallApp: true,
            androidMinimumVersion: '12',
          ),
        );
        debugPrint('Initial verification email sent to ${user.email}');
      } catch (e) {
        debugPrint('Failed to send initial verification email: $e');
      }
    }
  }

  /// Starts checking verification status periodically
  void _startPeriodicVerificationCheck() {
    _verificationTimer?.cancel();
    
    _verificationTimer = Timer(GoogleVerificationHelper._verificationCheckInterval, () {
      if (mounted) {
        _checkVerificationStatus();
      }
    });
  }

  /// Check if email has been verified
  Future<void> _checkVerificationStatus() async {
    if (_isCheckingVerification || _verificationAttempts >= GoogleVerificationHelper._maxVerificationAttempts) {
      return;
    }
    
    setState(() => _isCheckingVerification = true);
    _verificationAttempts++;
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        final updatedUser = FirebaseAuth.instance.currentUser;
        
        if (updatedUser?.emailVerified == true) {
          // Email is verified, update Firestore and complete verification
          await AuthService.setAppEmailVerified(updatedUser!.uid, value: true);
          
          if (mounted) {
            _showSnackBar('Email verified successfully!', Colors.green);
            widget.onVerificationComplete();
          }
          return;
        }
      }
      
      // If not verified and haven't reached max attempts, check again
      if (mounted && _verificationAttempts < GoogleVerificationHelper._maxVerificationAttempts) {
        final delay = Duration(seconds: 3 + (_verificationAttempts * 2));
        _verificationTimer = Timer(delay, () {
          if (mounted) _checkVerificationStatus();
        });
      } else if (mounted && _verificationAttempts >= GoogleVerificationHelper._maxVerificationAttempts) {
        _showSnackBar('Verification check stopped. Please try manually refreshing.', Colors.orange);
      }
    } catch (e) {
      debugPrint('Error checking verification status: $e');
      if (mounted) {
        _showSnackBar('Error checking verification status. Please try again.', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingVerification = false);
      }
    }
  }

  /// Manual verification check
  Future<void> _manualVerificationCheck() async {
    if (_isCheckingVerification) return;
    
    setState(() => _isCheckingVerification = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.reload();
        final updatedUser = FirebaseAuth.instance.currentUser;
        
        if (updatedUser?.emailVerified == true) {
          await AuthService.setAppEmailVerified(updatedUser!.uid, value: true);
          
          if (mounted) {
            _showSnackBar('Email verified successfully!', Colors.green);
            widget.onVerificationComplete();
          }
        } else {
          if (mounted) {
            _showSnackBar('Email not yet verified. Please check your email.', Colors.orange);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error checking verification: ${e.toString()}', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingVerification = false);
      }
    }
  }

  /// Resend verification email
  Future<void> _resendVerificationEmail() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.sendEmailVerification(
          ActionCodeSettings(
            url: AppConstants.authActionUrl,
            handleCodeInApp: true,
            androidInstallApp: true,
            androidMinimumVersion: '12',
          ),
        );
        
        if (mounted) {
          _showSnackBar('Verification email sent!', AppColors.primaryTeal);
          _verificationAttempts = 0;
          _startPeriodicVerificationCheck();
        }
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to send email';
        if (e.toString().contains('too-many-requests')) {
          errorMessage = 'Too many requests. Please wait before trying again.';
        }
        _showSnackBar(errorMessage, Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Show snackbar message
  void _showSnackBar(String message, Color backgroundColor) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Handle back button - sign out user
  Future<void> _handleBackPress() async {
    try {
      await AuthService.signOut();
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('Error signing out: ${e.toString()}', Colors.red);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (widget.showBackButton) {
          await _handleBackPress();
          return true;
        }
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: widget.showBackButton
            ? AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
                  onPressed: _handleBackPress,
                ),
                title: const Text(
                  'Verify Your Email',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Email verification icon
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primaryTeal.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.mark_email_read_outlined,
                      size: 60,
                      color: AppColors.primaryTeal,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Title
                  const Text(
                    'Verify Your Email',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Description
                  Text(
                    'We\'ve sent a verification email to:',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Email address
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primaryTeal.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      widget.email,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textDark,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Instructions
                  Text(
                    'Please check your email and click the verification link to continue. This screen will automatically update once verified.',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textLight,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Verification status indicator
                  if (_isCheckingVerification)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Checking verification status... ([33m$_verificationAttempts[0m/${GoogleVerificationHelper._maxVerificationAttempts})',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 32),
                  
                  // Action buttons
                  Row(
                    children: [
                      // Manual check button
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isCheckingVerification ? null : _manualVerificationCheck,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primaryTeal,
                            side: const BorderSide(color: AppColors.primaryTeal),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: Text(
                            _isCheckingVerification ? 'Checking...' : 'Check Now',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 16),
                      
                      // Resend button
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _resendVerificationEmail,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryTeal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 2,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  'Resend Email',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Note about checking spam
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange[700],
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Don\'t see the email? Check your spam folder.',
                            style: TextStyle(
                              color: Colors.orange[700],
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
