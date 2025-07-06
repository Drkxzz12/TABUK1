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
  /// Profile photo URL.
  final String profilePhoto;
  /// Date and time when the profile was created.
  final DateTime createdAt;
  /// Creates a [UserProfile] instance.
  const UserProfile({
    required this.userId,
    required this.role,
    required this.name,
    required this.email,
    required this.password,
  
    required this.profilePhoto,
    required this.createdAt,

  });

  /// Creates a [UserProfile] from a map (e.g., from Firestore).
  factory UserProfile.fromMap(Map<String, dynamic> map, String documentId) {

    
    // Handle name - check multiple possible field names (future-proof, but only one is needed)
    String name = '';
    if (map['name'] != null && (map['name'] as String).trim().isNotEmpty) {
      name = map['name'];
    }

    // Handle profile photo - prefer 'profilePhoto' (camelCase), fallback to others
    String profilePhoto = '';
    if (map['profilePhoto'] != null && (map['profilePhoto'] as String).trim().isNotEmpty) {
      profilePhoto = map['profilePhoto'];
    } else if (map['profile_photo'] != null && (map['profile_photo'] as String).trim().isNotEmpty) {
      profilePhoto = map['profile_photo'];
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
  
    return UserProfile(
      userId: documentId, // Use the document ID as the user ID
      role: map['role']?.toString() ?? '',
      name: name,
      email: map['email']?.toString() ?? '',
      password: map['password']?.toString() ?? '',
      profilePhoto: profilePhoto,
      createdAt: createdAt,
      
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
      'profilePhoto': profilePhoto, // always camelCase
      'created_at': createdAt.toIso8601String(),
    };
  }
  
  /// Creates a copy of this UserProfile with updated fields
  UserProfile copyWith({
    String? userId,
    String? role,
    String? name,
    String? email,
    String? password,
    String? profilePhoto,
    DateTime? createdAt,

  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      role: role ?? this.role,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
 
      profilePhoto: profilePhoto ?? this.profilePhoto,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}