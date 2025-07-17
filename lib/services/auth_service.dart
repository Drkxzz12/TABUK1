// ===========================================
// lib/services/auth_service.dart (FIXED VERSION)
// ===========================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:capstone_app/utils/constants.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Service for authentication and user management.
class AuthService {
  /// Helper to check user provider info for password reset logic
  static Future<Map<String, dynamic>> checkUserProviderInfo(String email) async {
    final result = {
      'exists': false,
      'hasEmailProvider': false,
      'hasGoogleProvider': false,
      'providers': <String>[],
    };
    
    try {
      // First check Firebase Auth for sign-in methods
      final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(email.trim());
      if (methods.isNotEmpty) {
        result['exists'] = true;
        result['providers'] = methods;
        if (methods.contains('password')) result['hasEmailProvider'] = true;
        if (methods.contains('google.com')) result['hasGoogleProvider'] = true;
      }
      
      // If no methods found in Firebase Auth, check Firestore
      if (methods.isEmpty) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('Users')
            .where('email', isEqualTo: email.toLowerCase().trim())
            .get();
        
        if (querySnapshot.docs.isNotEmpty) {
          result['exists'] = true;
          // Since it's in Firestore but not in Firebase Auth methods,
          // it's likely a Google account
          result['hasGoogleProvider'] = true;
          result['providers'] = ['google.com'];
        }
      }
      
    } catch (e) {
      debugPrint('Error checking user provider info: $e');
      // If Firebase Auth throws an error, still check Firestore
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('Users')
            .where('email', isEqualTo: email.toLowerCase().trim())
            .get();
        
        if (querySnapshot.docs.isNotEmpty) {
          result['exists'] = true;
          result['hasGoogleProvider'] = true;
          result['providers'] = ['google.com'];
        }
      } catch (firestoreError) {
        debugPrint('Error checking Firestore for user: $firestoreError');
        result['exists'] = false;
      }
    }
    
    return result;
  }

  /// Method to call the backend function for sending Google account instructions
  static Future<void> sendGooglePasswordResetInstructions(String email) async {
    try {
      final functions = FirebaseFunctions.instance;
      // Configure for your region if needed
      // final functions = FirebaseFunctions.instanceFor(region: 'us-central1');
      final callable = functions.httpsCallable('sendGooglePasswordResetEmail');
      final result = await callable.call(<String, dynamic>{
        'email': email,
      });
      if (result.data['success'] == true) {
        debugPrint('Google password reset instructions sent successfully');
      } else {
        throw 'Failed to send instructions: ${result.data['message'] ?? 'Unknown error'}';
      }
    } on FirebaseFunctionsException catch (e) {
      debugPrint('Firebase Functions error: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'not-found':
          throw 'Account not found. Please check your email address.';
        case 'invalid-argument':
          throw 'Invalid email address provided.';
        case 'unauthenticated':
          throw 'Authentication error. Please try again.';
        case 'permission-denied':
          throw 'Permission denied. Please contact support.';
        case 'unavailable':
          throw 'Service temporarily unavailable. Please try again later.';
        default:
          throw 'Failed to send instructions. Please try again.';
      }
    } catch (e) {
      debugPrint('Error sending Google password reset instructions: $e');
      throw 'Failed to send instructions. Please try again.';
    }
  }

  /// Checks if an email already exists in the database
  static Future<bool> emailExists(String email) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where('email', isEqualTo: email.toLowerCase().trim())
          .get();
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking email existence: $e');
      return false; // Return false to allow the process to continue and let Firebase handle the error
    }
  }

  /// Enhanced sign up method with email existence check
  static Future<UserCredential?> enhancedSignUpWithEmailPassword({
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      // First, check if email already exists in our database
      final emailAlreadyExists = await emailExists(email);
      if (emailAlreadyExists) {
        throw FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'An account with this email already exists.',
        );
      }

      // Create user with Firebase Auth
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: email.toLowerCase().trim(),
        password: password,
      );

      // Send email verification
      await userCredential.user?.sendEmailVerification();

      // Create user document in Firestore
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(userCredential.user?.uid)
          .set({
        'user_id': userCredential.user?.uid,
        'email': email.toLowerCase().trim(),
        'role': role,
        'created_at': FieldValue.serverTimestamp(),
        'app_email_verified': false,
        'username': '', // Will be updated later
        'name': '', // Will be updated later
        'profile_photo': '', // Will be updated later
        'password': '', // Never store actual password
      });

      return userCredential;
    } catch (e) {
      debugPrint('Error in enhancedSignUpWithEmailPassword: $e');
      rethrow;
    }
  }
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static const String _emailKey = 'pending_email';

  /// Returns the current Firebase user, or null if not signed in.
  static User? get currentUser => _auth.currentUser;

  /// Stream of authentication state changes.
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign up with email and password, and store user data in Firestore.
  static Future<UserCredential?> signUpWithEmailPassword({
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      // Validate email and password before making Firebase call
      if (email.isEmpty) {
        throw AppConstants.emailRequiredError;
      }
      if (!RegExp(AppConstants.emailRegex).hasMatch(email)) {
        throw AppConstants.invalidEmailError;
      }
      if (password.isEmpty) {
        throw AppConstants.passwordRequiredError;
      }
      if (password.length < AppConstants.minPasswordLength) {
        throw AppConstants.passwordLengthError;
      }

      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Send email verification
      await userCredential.user?.sendEmailVerification();
      debugPrint('Verification email sent to new user: ${userCredential.user?.email}');

      // Store additional user data (like role) in Firestore
      if (userCredential.user != null) {
        await storeUserData(
          userCredential.user!.uid,
          email,
          role,
          appEmailVerified: false,
        );
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      // Use constants for error messages
      if (e.code == 'email-already-in-use') {
        throw AppConstants.authEmailAlreadyInUse;
      } else if (e.code == 'invalid-email') {
        throw AppConstants.authInvalidEmail;
      } else if (e.code == 'weak-password') {
        throw AppConstants.authWeakPassword;
      } else if (e.code == 'network-request-failed') {
        throw AppConstants.authNetworkRequestFailed;
      } else if (e.code == 'too-many-requests') {
        throw AppConstants.authTooManyRequests;
      } else if (e.code == 'user-disabled') {
        throw AppConstants.authUserDisabled;
      } else if (e.code == 'operation-not-allowed') {
        throw AppConstants.authOperationNotAllowed;
      } else {
        throw _handleAuthException(e);
      }
    } catch (e) {
      // If the error is a string from our manual validation, just throw it
      if (e is String) {
        rethrow;
      }
      throw AppConstants.authUnexpectedError(e.toString());
    }
  }

  /// Sign in with email and password.
  static Future<UserCredential?> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Ensure user document exists in Firestore
      if (userCredential.user != null) {
        await _ensureUserDocumentExists(userCredential.user!);
      }
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AppConstants.authUnexpectedError(e.toString());
    }
  }

  /// Google Sign-In method with proper web and mobile support.
  static Future<UserCredential?> signInWithGoogle() async {
    try {
      UserCredential userCredential;
      
      if (kIsWeb) {
        // Web-specific implementation using popup
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        googleProvider.setCustomParameters({'prompt': 'select_account'});

        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        // Mobile implementation
        final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) return null;

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await _auth.signInWithCredential(credential);
      }

      // Handle post-authentication setup
      if (userCredential.user != null) {
        await _handlePostAuthentication(userCredential);
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AppConstants.authGoogleSignInFailed(e.toString());
    }
  }

  /// Handle post-authentication tasks (ensure document exists, handle verification)
  static Future<void> _handlePostAuthentication(UserCredential userCredential) async {
    final user = userCredential.user!;
    final isNewUser = userCredential.additionalUserInfo?.isNewUser ?? false;

    try {
      // First, ensure the user document exists
      await _ensureUserDocumentExists(user, isNewUser: isNewUser);

      // Then handle email verification
      await user.reload();
      final updatedUser = _auth.currentUser;
      
      if (updatedUser != null) {
        final needsVerification = isNewUser || !updatedUser.emailVerified;
        
        if (needsVerification) {
          // Send verification email
          await updatedUser.sendEmailVerification(
            ActionCodeSettings(
              url: AppConstants.authActionUrl,
              handleCodeInApp: true,
              androidInstallApp: true,
              androidMinimumVersion: '12',
            ),
          );
          debugPrint('Verification email sent to: ${updatedUser.email}');
        }
        
        // Update the app_email_verified field safely
        await setAppEmailVerified(user.uid, value: updatedUser.emailVerified);
      }
    } catch (e) {
      debugPrint('Error in post-authentication setup: $e');
      // Don't throw here - authentication succeeded, just log the error
    }
  }

  /// Ensure user document exists in Firestore before any operations
  static Future<void> _ensureUserDocumentExists(User user, {bool isNewUser = false}) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('Users').doc(user.uid);
      final doc = await docRef.get();
      
      if (!doc.exists) {
        // Document doesn't exist, create it
        debugPrint('Creating missing user document for ${user.uid}');
        await storeUserData(
          user.uid,
          user.email ?? '',
          '', // No role, force selection
          username: user.displayName ?? '',
          appEmailVerified: user.emailVerified,
        );
      } else if (isNewUser) {
        // Document exists but this is a new user - update with current info
        await storeUserData(
          user.uid,
          user.email ?? '',
          '', // No role, force selection
          username: user.displayName ?? '',
          appEmailVerified: user.emailVerified,
        );
      }
    } catch (e) {
      debugPrint('Error ensuring user document exists: $e');
      rethrow; // Re-throw since this is critical
    }
  }

  /// Public wrapper for _ensureUserDocumentExists for use in other services
  static Future<void> ensureUserDocumentExists(User user, {bool isNewUser = false}) async {
    return _ensureUserDocumentExists(user, isNewUser: isNewUser);
  }

  /// Store user data in Firestore.
  static Future<void> storeUserData(
    String uid,
    String email,
    String role, {
    String? username,
    String? password,
    bool appEmailVerified = false,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('Users').doc(uid).set({
        'user_id': uid,
        'role': role,
        'username': username ?? '',
        'email': email,
        'password': password ?? '',
        'created_at': FieldValue.serverTimestamp(),
        'app_email_verified': appEmailVerified,
      }, SetOptions(merge: true));
      debugPrint('User data stored/updated for $uid');
    } catch (e) {
      debugPrint('Error storing user data: $e');
      rethrow; // Re-throw for proper error handling
    }
  }

  /// Update app_email_verified field in Firestore - ENHANCED VERSION
  static Future<void> setAppEmailVerified(String uid, {bool value = true}) async {
    try {
      final docRef = FirebaseFirestore.instance.collection('Users').doc(uid);
      final user = _auth.currentUser;
      // Use a transaction to safely check and update
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final doc = await transaction.get(docRef);
        if (!doc.exists) {
          // Document doesn't exist - create it with all required fields
          debugPrint('Creating user document during email verification update for $uid');
          transaction.set(docRef, {
            'user_id': uid,
            'role': 'Tourist',
            'username': user?.displayName ?? '',
            'email': user?.email ?? '',
            'password': '',
            'created_at': FieldValue.serverTimestamp(),
            'app_email_verified': value,
            // Add any other required fields here as needed
          });
        } else {
          // Document exists - update the field
          transaction.update(docRef, {'app_email_verified': value});
        }
      });
      debugPrint('app_email_verified updated to $value for $uid');
    } catch (e) {
      debugPrint('Error updating app_email_verified: $e');
      // Don't throw here - this is often called in background and shouldn't break the flow
    }
  }

  /// Alternative method for web using redirect (if popup doesn't work).
  static Future<UserCredential?> signInWithGoogleRedirect() async {
    if (!kIsWeb) {
      throw AppConstants.authRedirectWebOnly;
    }

    try {
      GoogleAuthProvider googleProvider = GoogleAuthProvider();
      googleProvider.addScope('email');
      googleProvider.addScope('profile');

      await _auth.signInWithRedirect(googleProvider);
      final userCredential = await _auth.getRedirectResult();
      
      if (userCredential.user != null) {
        await _handlePostAuthentication(userCredential);
      }
      
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AppConstants.authGoogleSignInRedirectFailed(e.toString());
    }
  }

  /// Anonymous Sign In (Guest Account).
  static Future<UserCredential?> signInAnonymously({
    String role = AppConstants.authGuestRole,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInAnonymously();
      
      // Store guest user data in Firestore
      if (userCredential.user != null) {
        await storeUserData(userCredential.user!.uid, '', role, appEmailVerified: true);
      }
      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AppConstants.authUnexpectedError(e.toString());
    }
  }

  /// Send password reset email with provider check (no Cloud Functions needed)
  static Future<Map<String, dynamic>> sendPasswordResetEmail(String email) async {
    try {
      // Validate email format first
      if (email.trim().isEmpty) {
        throw 'Please enter your email address.';
      }
      
      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
      if (!emailRegex.hasMatch(email.trim())) {
        throw 'Please enter a valid email address.';
      }

      debugPrint('Email validation passed for: ${email.trim()}');

      // Check user provider information
      final providerInfo = await checkUserProviderInfo(email);
      debugPrint('Provider info: $providerInfo');
      
      if (!providerInfo['exists']) {
        throw 'No account found with this email address.';
      }

      // Handle different provider scenarios
      if (providerInfo['hasEmailProvider']) {
        // User has email/password provider - send Firebase password reset
        await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
        debugPrint('Firebase password reset email sent to: ${email.trim()}');
        return {
          'success': true,
          'message': 'Password reset email sent successfully.',
          'type': 'email_provider'
        };
      } else if (providerInfo['hasGoogleProvider']) {
        // User has Google provider - log request and return instructions
        await FirebaseFirestore.instance
            .collection('password_reset_requests')
            .add({
          'email': email.trim(),
          'type': 'google_instructions',
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'instructions_provided'
        });
        
        debugPrint('Google password reset request logged for: ${email.trim()}');
        return {
          'success': true,
          'message': 'This account uses Google Sign-In. To reset your password, go to Google Account settings and change your Google password.',
          'type': 'google_provider',
          'instructions': 'Visit https://myaccount.google.com/security to change your Google password.'
        };
      } else {
        // Unknown provider
        throw 'Unable to reset password for this account type.';
      }
      
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException in sendPasswordResetEmail: ${e.code} - ${e.message}');
      switch (e.code) {
        case 'user-not-found':
          throw 'No account found with this email address.';
        case 'invalid-email':
          throw 'Please enter a valid email address.';
        case 'user-disabled':
          throw 'This account has been disabled.';
        case 'too-many-requests':
          throw 'Too many requests. Please try again later.';
        default:
          throw 'Failed to send password reset email. Please try again.';
      }
    } catch (e) {
      debugPrint('Error in sendPasswordResetEmail: $e');
      if (e is String) {
        rethrow; // Re-throw our custom error messages
      }
      throw 'Failed to send password reset email. Please try again.';
    }
  }

  /// Helper method to handle Firebase Auth exceptions
  static String _handleAuthException(FirebaseAuthException e) {
    debugPrint('FirebaseAuthException: ${e.code} - ${e.message}');
    
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      case 'weak-password':
        return 'Password should be at least 6 characters long.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'operation-not-allowed':
        return 'This operation is not allowed. Please contact support.';
      case 'invalid-credential':
        return 'Invalid credentials. Please check your email and password.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  /// Sign out the current user.
  static Future<void> signOut() async {
    try {
      if (kIsWeb) {
        await _auth.signOut();
      } else {
        await Future.wait([_auth.signOut(), GoogleSignIn().signOut()]);
      }
      await _clearStoredEmail();
    } catch (e) {
      throw AppConstants.authFailedToSignOut(e.toString());
    }
  }

  /// Delete the current user account.
  static Future<void> deleteUser() async {
    try {
      final uid = currentUser?.uid;
      await currentUser?.delete();
      if (uid != null) {
        await deleteUserData(uid);
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AppConstants.authFailedToDeleteAccount(e.toString());
    }
  }

  /// Reload user data from Firebase.
  static Future<void> reloadUser() async {
    try {
      await currentUser?.reload();
    } catch (e) {
      debugPrint('Error reloading user: $e');
    }
  }

  /// Returns true if the current user's email is verified.
  static bool get isEmailVerified => currentUser?.emailVerified ?? false;

  /// Send email verification to the current user.
  static Future<void> sendEmailVerification({String? url}) async {
    try {
      if (url != null) {
        await currentUser?.sendEmailVerification(ActionCodeSettings(url: url));
      } else {
        await currentUser?.sendEmailVerification();
      }
      debugPrint('Verification email sent to: {currentUser?.email}');
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AppConstants.authFailedToSendVerification(e.toString());
    }
  }

  /// Link email/password credential to existing account.
  static Future<UserCredential?> linkWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      return await currentUser?.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AppConstants.authFailedToLinkCredential(e.toString());
    }
  }

  /// Link email link credential to existing account.
  static Future<UserCredential?> linkWithEmailLink({
    required String email,
    required String emailLink,
  }) async {
    try {
      final credential = EmailAuthProvider.credentialWithLink(
        email: email,
        emailLink: emailLink,
      );
      return await currentUser?.linkWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AppConstants.authFailedToLinkEmailLink(e.toString());
    }
  }

  /// Re-authenticate with email/password.
  static Future<UserCredential?> reauthenticateWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );
      return await currentUser?.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AppConstants.authFailedToReauthenticate(e.toString());
    }
  }

  /// Re-authenticate with email link.
  static Future<UserCredential?> reauthenticateWithEmailLink({
    required String email,
    required String emailLink,
  }) async {
    try {
      final credential = EmailAuthProvider.credentialWithLink(
        email: email,
        emailLink: emailLink,
      );
      return await currentUser?.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw AppConstants.authFailedToReauthenticateWithEmailLink(e.toString());
    }
  }

  // Helper methods for email storage

  static Future<void> _clearStoredEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_emailKey);
    } catch (e) {
      debugPrint('Error clearing stored email: $e');
    }
  }

  static Future<String?> getStoredEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_emailKey);
    } catch (e) {
      debugPrint('Error getting stored email: $e');
      return null;
    }
  }

  /// Get user data from Firestore.
  static Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc =
          await FirebaseFirestore.instance.collection('Users').doc(uid).get();
      return doc.data() as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('Error getting user data: $e');
      return null;
    }
  }

  /// Update user data in Firestore.
  static Future<void> updateUserData(
    String uid, {
    String? email,
    String? role,
    String? username,
    String? password,
    String? municipality,
    String? status,
    String? profilePhoto,
  }) async {
    try {
      await FirebaseFirestore.instance.collection('Users').doc(uid).set({
        'user_id': uid,
        'role': role,
        'username': username ?? '',
        'email': email,
        'password': password ?? '',
        'municipality': municipality ?? '',
        'status': status ?? '',
        'profile_photo': profilePhoto ?? '',
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating user data: $e');
    }
  }

  /// Delete user data from Firestore.
  static Future<void> deleteUserData(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('Users').doc(uid).delete();
    } catch (e) {
      debugPrint('Error deleting user data: $e');
    }
  }

  /// Log unhandled errors.
  static void logError(dynamic error, StackTrace stackTrace) {
    if (kDebugMode) {
      print('Unhandled error: $error');
      print('Stack trace: $stackTrace');
    }
  }
}
