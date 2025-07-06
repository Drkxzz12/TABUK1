// ===========================================
// lib/screens/tourist_module/profile/profile_screen.dart
// ===========================================
// Profile screen with improved UI and proper auth state handling

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:capstone_app/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../login_screen.dart';
import '../../../utils/constants.dart';
import '../../../utils/colors.dart';
import '../../../models/users.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Profile screen for the tourist user.  
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? userProfile;
  bool _loading = true;
  String? _error;
  StreamSubscription<User?>? _authStateSubscription;
  
  // Check if current user is a guest
  bool get _isGuest => userProfile?.role.toLowerCase() == 'guest';

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  void _initializeProfile() {
    // Listen to auth state changes
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      debugPrint('Auth state changed: ${user?.uid}');
      if (user != null) {
        _fetchUserProfile();
      } else {
        // Redirect to login if user is not authenticated
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          // Use addPostFrameCallback to ensure context is valid after async gap
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: const [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Signed out successfully'),
                  ],
                ),
                backgroundColor: AppColors.primaryTeal,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            );
          });
        }
      }
    });
  }

  Future<void> _fetchUserProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Wait a bit for auth to be fully ready
      await Future.delayed(const Duration(milliseconds: 100));
      
      final user = FirebaseAuth.instance.currentUser;
      debugPrint('Current user: ${user?.uid}');
      
      if (user == null) {
        setState(() {
          _loading = false;
          _error = 'User not authenticated';
          userProfile = null;
        });
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .get();
      
      debugPrint('Document exists: ${doc.exists}');
      debugPrint('Document data: ${doc.data()}');
      
      if (doc.exists && doc.data() != null) {
        userProfile = UserProfile.fromMap(doc.data()!, user.uid);
        debugPrint('UserProfile created: ${userProfile?.name}');
        setState(() {
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
          _error = 'No profile data found';
          userProfile = null;
        });
      }
    } catch (e) {
      debugPrint('Error fetching user profile: $e');
      setState(() {
        _loading = false;
        _error = 'Error loading profile: $e';
        userProfile = null;
      });
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text(
          AppConstants.profileTitle,
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: AppColors.backgroundColor,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryTeal),
            ),
            SizedBox(height: 24),
            Text(
              'Loading profile...',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textLight,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Colors.red[400],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Something went wrong',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.red[600],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _fetchUserProfile,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Try Again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await AuthService.signOut();
                      if (mounted) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                            (route) => false,
                          );
                        });
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign Out'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textLight,
                      side: BorderSide(color: AppColors.textLight.withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (userProfile == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.person_off,
                size: 64,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No profile data found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please try refreshing or sign out and back in',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // User info with avatar and card
            if (userProfile != null) ...[
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: Column(
                    children: [
                      // Profile picture with border and shadow
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryTeal.withOpacity(0.18),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                          border: Border.all(
                            color: AppColors.primaryTeal.withOpacity(0.25),
                            width: 3,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: AppColors.imagePlaceholder,
                          backgroundImage: userProfile!.profilePhoto.isNotEmpty
                              ? NetworkImage(userProfile!.profilePhoto)
                              : null,
                          child: userProfile!.profilePhoto.isEmpty
                              ? const Icon(Icons.person, size: 48, color: AppColors.textLight)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 22),
                      // Name with icon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.person, color: AppColors.primaryTeal, size: 22),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              userProfile!.name.isNotEmpty ? userProfile!.name : 'No name set',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDark),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // Email with icon
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.email_rounded, color: AppColors.primaryTeal, size: 20),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              userProfile!.email.isNotEmpty ? userProfile!.email : 'No email set',
                              style: const TextStyle(fontSize: 16, color: AppColors.textLight, fontWeight: FontWeight.w500),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Role badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isGuest ? Colors.orange.withOpacity(0.9) : AppColors.primaryTeal.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.admin_panel_settings_rounded, size: 16, color: Colors.black54),
                            const SizedBox(width: 6),
                            Text(
                              userProfile!.role.isNotEmpty ? userProfile!.role.toUpperCase() : 'NO ROLE SET',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _isGuest ? Colors.white : AppColors.primaryTeal,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
            // Action Buttons
            Column(
              children: [
                if (!_isGuest) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.edit_rounded, size: 20),
                      label: const Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryTeal,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 2,
                      ),
                      onPressed: () async {
                        final result = await showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => EditProfileSheet(userProfile: userProfile!),
                        );
                        if (result == true) {
                          _fetchUserProfile();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.logout_rounded, size: 20),
                    label: const Text(
                      AppConstants.signOut,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.profileSignOutButtonColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    onPressed: () async {
                      await AuthService.signOut();
                      if (mounted) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (context) => const LoginScreen()),
                            (route) => false,
                          );
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            if (_isGuest) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.orange.withOpacity(0.1),
                      Colors.orange.withOpacity(0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          color: Colors.orange[700],
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Guest Account',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You\'re using a guest account with limited features. Create a full account to unlock profile editing and additional features.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange[600],
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ================= ViewOnlyProfileSheet for Guests =================
class ViewOnlyProfileSheet extends StatelessWidget {
  final UserProfile userProfile;
  
  const ViewOnlyProfileSheet({super.key, required this.userProfile});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            const Center(
              child: Text(
                'Profile Information',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            Center(
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(48),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 44,
                  backgroundColor: AppColors.imagePlaceholder,
                  backgroundImage: userProfile.profilePhoto.isNotEmpty
                      ? NetworkImage(userProfile.profilePhoto)
                      : null,
                  child: userProfile.profilePhoto.isEmpty
                      ? const Icon(Icons.person, size: 44, color: AppColors.textLight)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            _buildInfoRow(Icons.person_rounded, 'Name', userProfile.name.isNotEmpty ? userProfile.name : 'Not set'),
            const SizedBox(height: 20),
            _buildInfoRow(Icons.email_rounded, 'Email', userProfile.email.isNotEmpty ? userProfile.email : 'Not set'),
            const SizedBox(height: 20),
            _buildInfoRow(Icons.admin_panel_settings_rounded, 'Role', userProfile.role.isNotEmpty ? userProfile.role : 'Not set'),
            const SizedBox(height: 32),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.orange.withOpacity(0.1),
                    Colors.orange.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded, color: Colors.orange[700], size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This profile is view-only for guest users. Create a full account to edit your information.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.orange[700],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[600],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryTeal.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: AppColors.primaryTeal),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textLight,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================= EditProfileSheet =================
class EditProfileSheet extends StatefulWidget {
  final UserProfile userProfile;
  
  const EditProfileSheet({super.key, required this.userProfile});

  @override
  State<EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _profilePhotoController;
  XFile? _pickedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userProfile.name);
    _emailController = TextEditingController(text: widget.userProfile.email);
    _profilePhotoController = TextEditingController(text: widget.userProfile.profilePhoto);
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (image != null) {
        setState(() {
          _pickedImage = image;
        });
        String? url;
        if (kIsWeb) {
          // Web: use bytes
          final bytes = await image.readAsBytes();
          url = await _uploadToImgBBWeb(bytes);
        } else {
          // Mobile: use file path
          url = await _uploadToImgBB(image.path);
        }
        if (url != null) {
          setState(() {
            _profilePhotoController.text = url!;
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to upload image. Please try again.'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // For web: upload using bytes
  Future<String?> _uploadToImgBBWeb(Uint8List bytes) async {
    try {
      const apiKey = 'aae8c93b12878911b39dd9abc8c73376';
      final url = Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey');
      final base64Image = base64Encode(bytes);
      final response = await http.post(
        url,
        body: {
          'image': base64Image,
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data']['url'] as String?;
      } else {
        debugPrint('ImgBB upload failed: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading to ImgBB (web): $e');
      return null;
    }
  }

  Future<String?> _uploadToImgBB(String filePath) async {
    try {
      const apiKey = 'aae8c93b12878911b39dd9abc8c73376'; // Example key, replace with your own
      final url = Uri.parse('https://api.imgbb.com/1/upload?key=$apiKey');
      final bytes = await File(filePath).readAsBytes();
      final base64Image = base64Encode(bytes);
      final response = await http.post(
        url,
        body: {
          'image': base64Image,
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data']['url'] as String?;
      } else {
        debugPrint('ImgBB upload failed: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error uploading to ImgBB: $e');
      return null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _profilePhotoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Edit Profile',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Profile Picture Section
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(48),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 44,
                          backgroundColor: AppColors.imagePlaceholder,
                          backgroundImage: _profilePhotoController.text.isNotEmpty
                              ? (_profilePhotoController.text.startsWith('http')
                                  ? NetworkImage(_profilePhotoController.text)
                                  : FileImage(File(_profilePhotoController.text)) as ImageProvider)
                              : null,
                          child: _profilePhotoController.text.isEmpty
                              ? const Icon(Icons.person, size: 44, color: AppColors.textLight)
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          child: InkWell(
                            onTap: _pickImage,
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primaryTeal,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryTeal.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.edit, size: 18, color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Name Field
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name cannot be empty';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                // Email Field (read-only)
                TextFormField(
                  controller: _emailController,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(Icons.email),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save_rounded),
                    label: const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryTeal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                    ),
                    onPressed: () async {
                      if (!mounted) return;
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      if (_formKey.currentState?.validate() ?? false) {
                        try {
                          final user = FirebaseAuth.instance.currentUser;
                          if (user == null) throw Exception('User not authenticated');
                          String photoUrl = widget.userProfile.profilePhoto;
                          if (_pickedImage != null) {
                            // If picked image, use the imgbb url if available
                            photoUrl = _profilePhotoController.text;
                          }

                          await FirebaseFirestore.instance.collection('Users').doc(user.uid).update({
                            'name': _nameController.text.trim(),
                            'profilePhoto': photoUrl,
                          });
                          if (!mounted) return;
                          navigator.pop(true);
                        } catch (e) {
                          if (!mounted) return;
                          scaffoldMessenger.showSnackBar(
                            SnackBar(
                              content: Text('Failed to update profile: $e'),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // Cancel Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.close_rounded),
                    label: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textLight,
                      side: BorderSide(color: AppColors.textLight.withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context, false);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}