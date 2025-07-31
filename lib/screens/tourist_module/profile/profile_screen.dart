// ===========================================
// lib/screens/tourist_module/profile/profile_screen.dart
// ===========================================
// Profile screen with improved UI and proper auth state handling

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:capstone_app/services/auth_service.dart';
import 'package:capstone_app/services/favorites_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../login_screen.dart';
import '../../../utils/constants.dart';
import '../../../utils/colors.dart';
import '../../../models/users.dart';
import '../../../models/favorite_model.dart';
import '../../../models/hotspots_model.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:capstone_app/services/arrival_service.dart';

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
  
  // Favorites functionality
  List<Favorite> _favorites = [];
  StreamSubscription<List<Favorite>>? _favoritesSubscription;
  
  // Check if current user is a guest
  bool get _isGuest => userProfile?.role.toLowerCase() == 'guest';

  // Add to _ProfileScreenState:
  List<Map<String, dynamic>> _arrivals = [];
  bool _loadingArrivals = false;
  Map<String, String> _hotspotNames = {};

  @override
  void initState() {
    super.initState();
    _initializeProfile();
    _fetchArrivals();
  }

  void _initializeProfile() {
    // Listen to auth state changes
    _authStateSubscription = FirebaseAuth.instance.authStateChanges().listen((User? user) {
      debugPrint('Auth state changed: ${user?.uid}');
      if (user != null) {
        _fetchUserProfile();
        _initializeFavoritesStream();
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

  void _initializeFavoritesStream() {
    _favoritesSubscription?.cancel();
    _favoritesSubscription = FavoritesService.getUserFavorites().listen(
      (favorites) {
        if (mounted) {
          setState(() {
            _favorites = favorites;
          });
        }
      },
      onError: (error) => debugPrint('Error listening to favorites: $error'),
    );
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

  Future<void> _fetchArrivals() async {
    setState(() => _loadingArrivals = true);
    try {
      final arrivals = await ArrivalService.getUserArrivals();
      // Fetch all hotspots and build a map of id -> name
      final hotspotSnapshot = await FirebaseFirestore.instance.collection('Hotspots').get();
      final hotspotNames = <String, String>{};
      for (final doc in hotspotSnapshot.docs) {
        hotspotNames[doc.id] = doc.data()['name'] ?? doc.id;
      }
      setState(() {
        _arrivals = arrivals;
        _hotspotNames = hotspotNames;
        _loadingArrivals = false;
      });
    } catch (e) {
      setState(() => _loadingArrivals = false);
    }
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _favoritesSubscription?.cancel();
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
                  // Favorites Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.favorite, color: Colors.white, size: 20),
                      label: const Text(
                        'My Favorites',
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
                      onPressed: () => _showAllFavorites(),
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
            if (!_isGuest) ...[
              const SizedBox(height: 24),
              _buildArrivalHistorySection(),
            ],
            const SizedBox(height: 32),
            // Remove the old inline favorites section and its conditional display
            // ... existing code ...
          ],
        ),
      ),
    );
  }




  void _showAllFavorites() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _AllFavoritesScreen(favorites: _favorites),
      ),
    );
  }

  // Add this widget to _ProfileScreenState:
  Widget _buildArrivalHistorySection() {
    if (_loadingArrivals) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_arrivals.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: const [
              Icon(Icons.location_on, color: Colors.grey, size: 24),
              SizedBox(width: 12),
              Text('No arrival history yet', style: TextStyle(fontSize: 16)),
            ],
          ),
        ),
      );
    }
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.location_on, color: Colors.green, size: 24),
                SizedBox(width: 12),
                Text('Arrival History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ..._arrivals.take(5).map((arrival) {
              final hotspotId = arrival['hotspotId'] ?? '';
              final hotspotName = _hotspotNames[hotspotId] ?? hotspotId;
              final timestamp = arrival['timestamp'] as Timestamp?;
              final date = timestamp?.toDate();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.place, size: 18, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hotspotName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (date != null)
                      Text(
                        '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                  ],
                ),
              );
            }),
            if (_arrivals.length > 5)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('+${_arrivals.length - 5} more...', style: const TextStyle(color: Colors.grey)),
              ),
          ],
        ),
      ),
    );
  }
}

// ================= AllFavoritesScreen =================
class _AllFavoritesScreen extends StatelessWidget {
  final List<Favorite> favorites;

  const _AllFavoritesScreen({required this.favorites});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Favorites'),
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: favorites.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No favorites yet',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start exploring hotspots and add them to your favorites!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final favorite = favorites[index];
                final hotspot = favorite.hotspot;
                if (hotspot == null) return const SizedBox.shrink();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: hotspot.images.isNotEmpty
                              ? Image.network(
                                  hotspot.images.first,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                                )
                              : _buildPlaceholderImage(),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                hotspot.name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                hotspot.category,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                hotspot.location,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Added on ${_formatDate(favorite.addedAt)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            IconButton(
                              onPressed: () => _removeFromFavorites(context, favorite),
                              icon: Icon(Icons.favorite, color: Colors.red[400], size: 24),
                              tooltip: 'Remove from favorites',
                            ),
                            const SizedBox(height: 8),
                            IconButton(
                              onPressed: () => _showHotspotDetails(context, hotspot),
                              icon: Icon(Icons.info_outline, color: AppColors.primaryTeal, size: 24),
                              tooltip: 'View details',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 80,
      height: 80,
      color: Colors.grey[300],
      child: Icon(Icons.image, size: 32, color: Colors.grey[400]),
    );
  }

  Future<void> _removeFromFavorites(BuildContext context, Favorite favorite) async {
    try {
      final success = await FavoritesService.removeFromFavorites(favorite.hotspotId);
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.favorite_border, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text('${favorite.hotspot?.name ?? 'Hotspot'} removed from favorites'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing from favorites: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showHotspotDetails(BuildContext context, Hotspot hotspot) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          child: Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: hotspot.images.isNotEmpty
                            ? Image.network(
                                hotspot.images.first,
                                width: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildDialogPlaceholder(),
                              )
                            : _buildDialogPlaceholder(),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hotspot.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 22,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            hotspot.description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Open',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                hotspot.category,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow('Location', hotspot.location),
                          _buildInfoRow('District', hotspot.district),
                          _buildInfoRow('Municipality', hotspot.municipality),
                          _buildInfoRow('Transportation', hotspot.transportation.join(", ")),
                          _buildInfoRow('Operating Hours', hotspot.operatingHours),
                          _buildInfoRow('Entrance Fee', hotspot.formattedEntranceFee),
                          _buildInfoRow('Contact Info', hotspot.contactInfo),
                          _buildInfoRow('Restroom', hotspot.restroom ? "Available" : "Not Available"),
                          _buildInfoRow('Food Access', hotspot.foodAccess ? "Available" : "Not Available"),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: const Center(child: Icon(Icons.image, size: 50, color: Colors.grey)),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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