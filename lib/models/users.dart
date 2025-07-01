// ===========================================
// lib/models/user_profile_model.dart
// ===========================================
// Model for user profile data.

/// Represents a user profile in the system.
class UserProfile {
  /// Unique user ID.
  final String userId;
  /// User's role (e.g., admin, tourist).
  final String role;
  /// name of the user.
  final String name;
  /// Email address of the user.
  final String email;
  /// Password (should be securely stored/hashed in production).
  final String password;
  /// Municipality of the user.
  final String municipality;
  /// Status of the user (e.g., active, inactive).
  final String status;
  /// Profile photo URL.
  final String profilePhoto;
  /// Date and time when the profile was created.
  final DateTime createdAt;
  /// List of image URLs for the tourist (profile, gallery, etc.).
  final List<String> images;

  /// Creates a [UserProfile] instance.
  const UserProfile({
    required this.userId,
    required this.role,
    required this.name,
    required this.email,
    required this.password,
    required this.municipality,
    required this.status,
    required this.profilePhoto,
    required this.createdAt,
    required this.images,
  });

  /// Creates a [UserProfile] from a map (e.g., from Firestore).
  factory UserProfile.fromMap(Map<String, dynamic> map, String documentId) {

    
    // Handle name - check multiple possible field names
    String name = '';
    if (map['name'] != null && (map['name'] as String).trim().isNotEmpty) {
      name = map['name'];
    } else if (map['name'] != null && (map['name'] as String).trim().isNotEmpty) {
      name = map['name'];
    } else if (map['name'] != null && (map['name'] as String).trim().isNotEmpty) {
      name = map['name'];
    }
    
    // Handle profile photo - check multiple possible field names
    String profilePhoto = '';
    if (map['profile_photo'] != null && (map['profile_photo'] as String).trim().isNotEmpty) {
      profilePhoto = map['profile_photo'];
    } else if (map['profilePhoto'] != null && (map['profilePhoto'] as String).trim().isNotEmpty) {
      profilePhoto = map['profilePhoto'];
    } else if (map['profileImageUrl'] != null && (map['profileImageUrl'] as String).trim().isNotEmpty) {
      profilePhoto = map['profileImageUrl'];
    }
    
    // Only use valid URLs, never local file paths
    if (profilePhoto.isNotEmpty && !profilePhoto.startsWith('http')) {
      profilePhoto = '';
    }
    
    // Handle created_at field
    DateTime createdAt;
    if (map['created_at'] != null) {
      if (map['created_at'] is DateTime) {
        createdAt = map['created_at'];
      } else if (map['created_at'] is String) {
        createdAt = DateTime.tryParse(map['created_at']) ?? DateTime.now();
      } else {
        createdAt = DateTime.now();
      }
    } else if (map['createdAt'] != null) {
      // Handle alternative field name
      if (map['createdAt'] is DateTime) {
        createdAt = map['createdAt'];
      } else if (map['createdAt'] is String) {
        createdAt = DateTime.tryParse(map['createdAt']) ?? DateTime.now();
      } else {
        createdAt = DateTime.now();
      }
    } else {
      createdAt = DateTime.now();
    }
    
    // Handle images array
    List<String> images = [];
    if (map['images'] != null && map['images'] is List) {
      images = List<String>.from(map['images']);
    }
    
    return UserProfile(
      userId: documentId, // Use the document ID as the user ID
      role: map['role']?.toString() ?? '',
      name: name,
      email: map['email']?.toString() ?? '',
      password: map['password']?.toString() ?? '',
      municipality: map['municipality']?.toString() ?? '',
      status: map['status']?.toString() ?? '',
      profilePhoto: profilePhoto,
      createdAt: createdAt,
      images: images,
    );
  }

  /// Converts the [UserProfile] to a map for storage.
  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'role': role,
      'name': name,
      'email': email,
      'password': password,
      'municipality': municipality,
      'status': status,
      'profile_photo': profilePhoto,
      'created_at': createdAt.toIso8601String(),
      'images': images,
    };
  }
  
  /// Creates a copy of this UserProfile with updated fields
  UserProfile copyWith({
    String? userId,
    String? role,
    String? name,
    String? email,
    String? password,
    String? municipality,
    String? status,
    String? profilePhoto,
    DateTime? createdAt,
    List<String>? images,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      role: role ?? this.role,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      municipality: municipality ?? this.municipality,
      status: status ?? this.status,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      createdAt: createdAt ?? this.createdAt,
      images: images ?? this.images,
    );
  }
}