// ===========================================
// lib/screens/tourist_module/profile/profile_screen.dart
// ===========================================
// Profile screen with proper auth state handling

import 'package:flutter/material.dart';
import 'package:capstone_app/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Add this import
import '../../login_screen.dart';
import '../../../utils/constants.dart';
import '../../../utils/colors.dart';
import '../../../models/users.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:async'; // Add this import

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

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  void _initializeProfile() {
    // Listen to auth state changes
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      debugPrint('Auth state changed: \\${user?.uid}');
      if (user != null) {
        _fetchUserProfile();
      } else {
        // Redirect to login if user is not authenticated
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          // Use addPostFrameCallback to ensure context is valid after async gap
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Signed out successfully.'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
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
      appBar: AppBar(
        title: const Text(AppConstants.profileTitle),
        backgroundColor: AppColors.backgroundColor,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        elevation: 0,
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
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading profile...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(fontSize: 16, color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchUserProfile,
              child: const Text('Retry'),
            ),
            const SizedBox(height: 8),
            TextButton(
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
              child: const Text('Sign Out'),
            ),
          ],
        ),
      );
    }

    if (userProfile == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No profile data found',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Profile avatar
            CircleAvatar(
              radius: 48,
              backgroundColor: AppColors.imagePlaceholder,
              backgroundImage: userProfile!.profilePhoto.isNotEmpty
                  ? NetworkImage(userProfile!.profilePhoto)
                  : null,
              child: userProfile!.profilePhoto.isEmpty
                  ? const Icon(Icons.person, size: 48, color: AppColors.textLight)
                  : null,
            ),
            const SizedBox(height: 16),
            
            // name
            Text(
              userProfile!.name.isNotEmpty 
                  ? userProfile!.name 
                  : 'No name set',
              style: const TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // Email
            Text(
              userProfile!.email.isNotEmpty 
                  ? userProfile!.email 
                  : 'No email set',
              style: const TextStyle(
                fontSize: 16, 
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 8),
            
            // Role
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryTeal.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                userProfile!.role.isNotEmpty 
                    ? userProfile!.role 
                    : 'No role set',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.primaryTeal,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Edit Profile Button
            ElevatedButton.icon(
              icon: const Icon(Icons.person),
              label: const Text('View/Edit Profile'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () async {
                final result = await showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: AppColors.cardBackground,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  builder: (context) => EditProfileSheet(userProfile: userProfile!),
                );
                
                // Refresh profile after editing
                if (result == true) {
                  _fetchUserProfile();
                }
              },
            ),
            const SizedBox(height: 16),
            
            // Sign Out Button
            ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text(AppConstants.signOut),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.profileSignOutButtonColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
          ],
        ),
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
  late TextEditingController _municipalityController;
  late TextEditingController _profilePhotoController;
  XFile? _pickedImage;
  final ImagePicker _picker = ImagePicker();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userProfile.name);
    _emailController = TextEditingController(text: widget.userProfile.email);
    _municipalityController = TextEditingController(text: widget.userProfile.municipality);
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
          _profilePhotoController.text = image.path;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final updatedProfile = widget.userProfile.copyWith(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        municipality: _municipalityController.text.trim(),
        profilePhoto: _profilePhotoController.text.trim(),
      );
      
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .set(updatedProfile.toMap(), SetOptions(merge: true));
      
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _municipalityController.dispose();
    _profilePhotoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppConstants.defaultPadding,
        right: AppConstants.defaultPadding,
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
              const Center(
                child: Text(
                  'Edit Profile',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 24),
              
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.imagePlaceholder,
                      backgroundImage: _pickedImage != null
                          ? FileImage(File(_pickedImage!.path))
                          : (widget.userProfile.profilePhoto.isNotEmpty
                              ? NetworkImage(widget.userProfile.profilePhoto) as ImageProvider
                              : null),
                      child: (_pickedImage == null && widget.userProfile.profilePhoto.isEmpty)
                          ? const Icon(Icons.person, size: 40, color: AppColors.textLight)
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.primaryTeal,
                          child: const Icon(Icons.edit, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) => 
                    value == null || value.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _municipalityController,
                decoration: const InputDecoration(
                  labelText: 'Municipality',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city),
                ),
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _profilePhotoController,
                decoration: const InputDecoration(
                  labelText: 'Profile Photo URL',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.image),
                ),
                validator: (value) {
                  if (value != null && value.trim().isNotEmpty && !value.startsWith('http')) {
                    return 'Please enter a valid URL';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _saving ? null : _saveProfile,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}