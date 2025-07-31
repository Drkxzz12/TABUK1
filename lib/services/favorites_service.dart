// ===========================================
// lib/services/favorites_service.dart
// ===========================================
// Service for managing user favorites in Firestore.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/favorite_model.dart';
import '../models/hotspots_model.dart';

/// Service for managing user favorites.
class FavoritesService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collectionName = 'favorites';

  /// Add a hotspot to user's favorites.
  static Future<bool> addToFavorites(Hotspot hotspot) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Check if already in favorites
      final existingDoc =
          await _firestore
              .collection(_collectionName)
              .where('user_id', isEqualTo: user.uid)
              .where('hotspot_id', isEqualTo: hotspot.hotspotId)
              .get();

      if (existingDoc.docs.isNotEmpty) {
        // Already in favorites
        return true;
      }

      // Add to favorites
      final favorite = Favorite(
        favoriteId: '', // Will be set by Firestore
        userId: user.uid,
        hotspotId: hotspot.hotspotId,
        addedAt: DateTime.now(),
        hotspot: hotspot,
      );

      await _firestore.collection(_collectionName).add(favorite.toMap());

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error adding to favorites: $e');
      }
      return false;
    }
  }

  /// Remove a hotspot from user's favorites.
  static Future<bool> removeFromFavorites(String hotspotId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final doc =
          await _firestore
              .collection(_collectionName)
              .where('user_id', isEqualTo: user.uid)
              .where('hotspot_id', isEqualTo: hotspotId)
              .get();

      if (doc.docs.isNotEmpty) {
        await doc.docs.first.reference.delete();
        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Error removing from favorites: $e');
      }
      return false;
    }
  }

  /// Check if a hotspot is in user's favorites.
  static Future<bool> isFavorite(String hotspotId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return false;
      }

      final doc =
          await _firestore
              .collection(_collectionName)
              .where('user_id', isEqualTo: user.uid)
              .where('hotspot_id', isEqualTo: hotspotId)
              .get();

      return doc.docs.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking favorite status: $e');
      }
      return false;
    }
  }

  /// Get all favorites for the current user.
  static Stream<List<Favorite>> getUserFavorites() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return Stream.value([]);
      }

      return _firestore
          .collection(_collectionName)
          .where('user_id', isEqualTo: user.uid)
          .orderBy('added_at', descending: true)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs
                    .map((doc) => Favorite.fromMap(doc.data(), doc.id))
                    .toList(),
          );
    } catch (e) {
      if (kDebugMode) {
        print('Error getting user favorites: $e');
      }
      return Stream.value([]);
    }
  }

  /// Get favorite hotspot IDs for the current user.
  static Stream<Set<String>> getFavoriteHotspotIds() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return Stream.value({});
      }

      return _firestore
          .collection(_collectionName)
          .where('user_id', isEqualTo: user.uid)
          .snapshots()
          .map(
            (snapshot) =>
                snapshot.docs
                    .map((doc) => doc.data()['hotspot_id'] as String)
                    .toSet(),
          );
    } catch (e) {
      if (kDebugMode) {
        print('Error getting favorite hotspot IDs: $e');
      }
      return Stream.value({});
    }
  }

  /// Get count of user's favorites.
  static Stream<int> getFavoritesCount() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        return Stream.value(0);
      }

      return _firestore
          .collection(_collectionName)
          .where('user_id', isEqualTo: user.uid)
          .snapshots()
          .map((snapshot) => snapshot.docs.length);
    } catch (e) {
      if (kDebugMode) {
        print('Error getting favorites count: $e');
      }
      return Stream.value(0);
    }
  }

  /// Clear all favorites for the current user.
  static Future<bool> clearAllFavorites() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final batch = _firestore.batch();
      final docs =
          await _firestore
              .collection(_collectionName)
              .where('user_id', isEqualTo: user.uid)
              .get();

      for (final doc in docs.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error clearing favorites: $e');
      }
      return false;
    }
  }
}
