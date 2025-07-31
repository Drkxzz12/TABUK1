// ===========================================
// lib/services/recommender_system.dart
// ===========================================
// Optimized personalized recommendation service for tourists

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:capstone_app/models/hotspots_model.dart';
import 'package:capstone_app/models/tourist_preferences.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';
import '../utils/constants.dart';

/// Optimized service for generating personalized tourist recommendations
class TouristRecommendationService {
  /// Returns hotspots that are not matched to user preferences and are likely new, hidden, or lesser-known.
  /// Prioritizes hidden gems and newly added hotspots for the Discover section.
  static Future<List<Hotspot>> getDiscoverRecommendations({
    int limit = 10,
  }) async {
    final preferences = await getUserPreferences();
    if (preferences == null) return [];

    final allHotspots = await HotspotCache.getCachedHotspots();
    // Get hotspots already shown in other sections to avoid duplicates
    final personalized = await getPersonalizedRecommendations(limit: 50);
    final trending = await getTrendingHotspots(limit: 50);
    // Try to get user's location for nearby, but fallback to empty list if not possible
    List<Hotspot> nearby = [];
    try {
      // Dummy coordinates, as we don't have user location here. You may want to pass user location if available.
      nearby = await getNearbyRecommendations(
        userLat: 0,
        userLng: 0,
        limit: 50,
      );
    } catch (_) {}
    final shownIds = <String>{
      ...personalized.map((h) => h.hotspotId),
      ...trending.map((h) => h.hotspotId),
      ...nearby.map((h) => h.hotspotId),
    };

    // Helper: returns true if hotspot matches ANY user preference (category, description, etc)
    bool matchesAnyPreference(Hotspot h) {
      // Destination Types
      final matchesDestination = preferences.destinationTypes.any(
        (type) =>
            h.category.toLowerCase().contains(type.toLowerCase()) ||
            h.name.toLowerCase().contains(type.toLowerCase()) ||
            h.description.toLowerCase().contains(type.toLowerCase()),
      );
      // Vibe
      final matchesVibe =
          h.description.toLowerCase().contains(
            preferences.vibe.toLowerCase(),
          ) ||
          h.category.toLowerCase().contains(preferences.vibe.toLowerCase());
      // Companion
      final matchesCompanion =
          h.description.toLowerCase().contains(
            preferences.companion.toLowerCase(),
          ) ||
          h.category.toLowerCase().contains(
            preferences.companion.toLowerCase(),
          );
      // Timing
      final matchesTiming =
          h.description.toLowerCase().contains(
            preferences.travelTiming.toLowerCase(),
          ) ||
          h.category.toLowerCase().contains(
            preferences.travelTiming.toLowerCase(),
          );
      // Event
      final matchesEvent =
          h.description.toLowerCase().contains(
            preferences.eventRecommendation.toLowerCase(),
          ) ||
          h.category.toLowerCase().contains(
            preferences.eventRecommendation.toLowerCase(),
          );
      // Lesser Known
      final matchesLesserKnown =
          h.description.toLowerCase().contains(
            preferences.lesserKnown.toLowerCase(),
          ) ||
          h.category.toLowerCase().contains(
            preferences.lesserKnown.toLowerCase(),
          );
      return matchesDestination ||
          matchesVibe ||
          matchesCompanion ||
          matchesTiming ||
          matchesEvent ||
          matchesLesserKnown;
    }

    // Helper: returns true if hotspot is a hidden gem
    bool isHiddenGem(Hotspot h) {
      return ['hidden', 'secret', 'undiscovered', 'local'].any(
        (keyword) =>
            h.category.toLowerCase().contains(keyword) ||
            h.description.toLowerCase().contains(keyword),
      );
    }

    // Step 1: Strict filter (hidden gems that do NOT match any preferences)
    final discoverCandidates =
        allHotspots
            .where(
              (h) =>
                  !matchesAnyPreference(h) &&
                  !shownIds.contains(h.hotspotId) &&
                  (h.isArchived == true ? false : true), // Exclude archived
            )
            .toList();
    final hiddenGems = discoverCandidates.where(isHiddenGem).toList();
    hiddenGems.shuffle();
    if (hiddenGems.length >= limit) {
      return hiddenGems.take(limit).toList();
    }

    // Step 2: If not enough, fill with other hidden gems (even if they match preferences, but not shown elsewhere)
    final allHiddenGems =
        allHotspots
            .where(
              (h) =>
                  isHiddenGem(h) &&
                  !shownIds.contains(h.hotspotId) &&
                  (h.isArchived == true ? false : true), // Exclude archived
            )
            .toList();
    allHiddenGems.shuffle();
    final result = <Hotspot>[];
    result.addAll(hiddenGems);
    for (final h in allHiddenGems) {
      if (!result.contains(h) && result.length < limit) {
        result.add(h);
      }
    }
    if (result.length >= limit) {
      return result.take(limit).toList();
    }

    // Step 3: If still not enough, fill with any not-shown, not-archived hotspots (new/lesser-known, even if not hidden gems)
    final fallback =
        allHotspots
            .where(
              (h) =>
                  !shownIds.contains(h.hotspotId) &&
                  (h.isArchived == true ? false : true), // Exclude archived
            )
            .toList();
    fallback.shuffle();
    for (final h in fallback) {
      if (!result.contains(h) && result.length < limit) {
        result.add(h);
      }
    }
    return result.take(limit).toList();
  }

  // Scoring weights
  static const Map<String, double> _weights = {
    'base': 1.0,
    'destinationType': 3.0,
    'vibe': 2.5,
    'companion': 2.0,
    'timing': 1.5,
    'lesserKnown': 1.8,
    'event': 1.2,
  };

  // Consolidated keyword mappings
  static const Map<String, Map<String, List<String>>> _keywordMappings = {
    'destinationType': {
      'Waterfalls': ['waterfall', 'falls', 'cascade'],
      'Mountain Ranges': ['mountain', 'peak', 'summit', 'highland', 'range'],
      'Scenic Lakes': ['lake', 'lagoon', 'pond', 'reservoir'],
      'Caves': ['cave', 'cavern', 'grotto', 'underground'],
      'Nature Parks and Forests': [
        'park',
        'forest',
        'nature',
        'wildlife',
        'botanical',
      ],
      'Farms and Agricultural Tourism Sites': [
        'farm',
        'agriculture',
        'plantation',
        'agri',
      ],
      'Adventure Parks': ['adventure', 'zip', 'extreme', 'thrill', 'activity'],
      'Historical or Cultural Sites': [
        'historical',
        'cultural',
        'heritage',
        'museum',
        'monument',
      ],
    },
    'vibe': {
      'Peaceful & Relaxing': [
        'peaceful',
        'serene',
        'quiet',
        'tranquil',
        'relaxing',
      ],
      'Thrilling & Adventurous': [
        'adventure',
        'thrill',
        'extreme',
        'challenging',
        'exciting',
      ],
      'Educational & Cultural': [
        'educational',
        'cultural',
        'learning',
        'historical',
        'heritage',
      ],
      'Photo-Worthy / Instagrammable': [
        'scenic',
        'beautiful',
        'photogenic',
        'instagram',
        'stunning',
      ],
    },
    'companion': {
      'Solo': ['solo', 'individual', 'personal', 'meditation'],
      'With Friends': ['group', 'friends', 'social', 'party'],
      'With Family': ['family', 'kids', 'children', 'safe', 'accessible'],
      'With Partner': ['romantic', 'couple', 'intimate', 'date'],
    },
  };

  /// Get user preferences
  static Future<TouristPreferences?> getUserPreferences() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final doc =
          await FirebaseFirestore.instance
              .collection(AppConstants.touristPreferencesCollection)
              .doc(user.uid)
              .get();

      return doc.exists && doc.data() != null
          ? TouristPreferences.fromMap(doc.data()!, doc.id)
          : null;
    } catch (e) {
      if (kDebugMode) {
        print('${AppConstants.errorLoadingTouristPreferences}: $e');
      }
      return null;
    }
  }

  /// Get personalized recommendations
  static Future<List<Hotspot>> getPersonalizedRecommendations({
    int limit = 10,
  }) async {
    try {
      final preferences = await getUserPreferences();
      if (preferences == null) {
        throw RecommendationException(
          'No preferences found',
          RecommendationErrorType.noPreferences,
        );
      }

      final hotspots = await HotspotCache.getCachedHotspots();
      final scored = _scoreAndSortHotspots(hotspots, preferences);

      if (scored.isEmpty) {
        throw RecommendationException(
          'No recommendations found',
          RecommendationErrorType.noData,
        );
      }

      return scored.take(limit).toList();
    } catch (e) {
      if (kDebugMode) print('${AppConstants.errorGettingRecommendations}: $e');
      if (e is RecommendationException) rethrow;
      throw RecommendationException(
        'Network error',
        RecommendationErrorType.networkError,
      );
    }
  }

  /// Score and sort hotspots based on preferences
  static List<Hotspot> _scoreAndSortHotspots(
    List<Hotspot> hotspots,
    TouristPreferences preferences,
  ) {
    final scored =
        hotspots.map((hotspot) {
          final score = _calculateScore(hotspot, preferences);
          return ScoredHotspot(hotspot, score);
        }).toList();

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((s) => s.hotspot).toList();
  }

  /// Calculate recommendation score
  static double _calculateScore(
    Hotspot hotspot,
    TouristPreferences preferences,
  ) {
    return _weights['base']! +
        _scoreByKeywords(
              hotspot,
              preferences.destinationTypes,
              'destinationType',
            ) *
            _weights['destinationType']! +
        _scoreByKeywords(hotspot, [preferences.vibe], 'vibe') *
            _weights['vibe']! +
        _scoreByKeywords(hotspot, [preferences.companion], 'companion') *
            _weights['companion']! +
        _scoreCompanionSpecific(hotspot, preferences) * _weights['companion']! +
        _scoreTiming(hotspot, preferences.travelTiming) * _weights['timing']! +
        _scoreLesserKnown(hotspot, preferences.lesserKnown) *
            _weights['lesserKnown']! +
        _scoreEvent(hotspot, preferences.eventRecommendation) *
            _weights['event']!;
  }

  /// Generic keyword scoring
  static double _scoreByKeywords(
    Hotspot hotspot,
    List<String> selections,
    String mappingKey,
  ) {
    double score = 0.0;
    for (final selection in selections) {
      final keywords = _keywordMappings[mappingKey]?[selection] ?? [];
      score +=
          keywords
              .where((keyword) => _containsKeyword(hotspot, keyword))
              .length
              .toDouble();
    }
    return score;
  }

  /// Companion-specific scoring
  static double _scoreCompanionSpecific(
    Hotspot hotspot,
    TouristPreferences preferences,
  ) {
    switch (preferences.companion) {
      case 'With Family':
        return (hotspot.restroom && hotspot.foodAccess ? 0.5 : 0.0) +
            (hotspot.entranceFee != null && hotspot.entranceFee! <= 100
                ? 0.3
                : 0.0);
      case 'Solo':
        return hotspot.localGuide?.isNotEmpty == true ? 0.4 : 0.0;
      case 'With Friends':
        return hotspot.category.toLowerCase().contains('adventure') ? 0.6 : 0.0;
      case 'With Partner':
        return (hotspot.category.toLowerCase().contains('scenic') ||
                hotspot.category.toLowerCase().contains('romantic'))
            ? 0.5
            : 0.0;
      default:
        return 0.0;
    }
  }

  /// Timing-based scoring
  static double _scoreTiming(Hotspot hotspot, String timing) {
    switch (timing) {
      case 'Off-Season (Less crowded)':
        return [
              'hidden',
              'secret',
            ].any((keyword) => _containsKeyword(hotspot, keyword))
            ? 1.0
            : 0.0;
      case 'Festival Seasons':
        return [
              'festival',
              'event',
              'cultural',
            ].any((keyword) => _containsKeyword(hotspot, keyword))
            ? 1.0
            : 0.0;
      default:
        return 0.2;
    }
  }

  /// Lesser-known preference scoring
  static double _scoreLesserKnown(Hotspot hotspot, String preference) {
    switch (preference) {
      case 'Yes, I love discovering hidden gems':
        return [
              'hidden',
              'secret',
              'undiscovered',
              'local',
            ].any((keyword) => _containsKeyword(hotspot, keyword))
            ? 1.5
            : 0.0;
      case 'No, I prefer popular and established places':
        final popularBonus =
            [
                  'popular',
                  'famous',
                  'well-known',
                ].any((keyword) => _containsKeyword(hotspot, keyword))
                ? 1.0
                : 0.0;
        final hiddenPenalty =
            [
                  'hidden',
                  'secret',
                ].any((keyword) => _containsKeyword(hotspot, keyword))
                ? -0.5
                : 0.0;
        return popularBonus + hiddenPenalty;
      case 'Only if they are easy to access':
        return (_containsKeyword(hotspot, 'accessible') ||
                _containsKeyword(hotspot, 'easy') ||
                hotspot.transportation.isNotEmpty)
            ? 0.8
            : 0.0;
      default:
        return 0.0;
    }
  }

  /// Event-based scoring
  static double _scoreEvent(Hotspot hotspot, String eventPreference) {
    return (eventPreference == 'Yes' &&
            [
              'event',
              'festival',
              'cultural',
            ].any((keyword) => _containsKeyword(hotspot, keyword)))
        ? 1.0
        : 0.0;
  }

  /// Check if hotspot contains keyword
  static bool _containsKeyword(Hotspot hotspot, String keyword) {
    final lowerKeyword = keyword.toLowerCase();
    final searchText =
        [
          hotspot.name,
          hotspot.description,
          hotspot.category,
          ...(hotspot.safetyTips ?? []),
          ...(hotspot.suggestions ?? []),
        ].join(' ').toLowerCase();

    return searchText.contains(lowerKeyword);
  }

  /// Search hotspots with filters
  static Future<List<Hotspot>> searchHotspots(
    String query, {
    int limit = 20,
    List<String>? districts,
    List<String>? municipalities,
    List<String>? categories,
  }) async {
    try {
      final preferences = await getUserPreferences();

      // Use Firestore query if no text search and filters are provided
      if (query.trim().isEmpty &&
          _hasFilters(districts, municipalities, categories)) {
        return await _searchWithFirestore(
          limit,
          districts,
          municipalities,
          categories,
        );
      }

      // Otherwise use cached search
      return await _searchWithCache(
        query,
        limit,
        districts,
        municipalities,
        categories,
        preferences,
      );
    } catch (e) {
      if (kDebugMode) print('Error searching hotspots: $e');
      throw RecommendationException(
        'Search failed',
        RecommendationErrorType.networkError,
      );
    }
  }

  static bool _hasFilters(
    List<String>? districts,
    List<String>? municipalities,
    List<String>? categories,
  ) {
    return (districts?.isNotEmpty ?? false) ||
        (municipalities?.isNotEmpty ?? false) ||
        (categories?.isNotEmpty ?? false);
  }

  static Future<List<Hotspot>> _searchWithFirestore(
    int limit,
    List<String>? districts,
    List<String>? municipalities,
    List<String>? categories,
  ) async {
    var query =
        FirebaseFirestore.instance.collection(AppConstants.hotspotsCollection)
            as Query<Map<String, dynamic>>;

    if (categories?.isNotEmpty == true) {
      query = query.where('category', whereIn: categories!.take(10).toList());
    }
    if (districts?.isNotEmpty == true) {
      query = query.where('district', whereIn: districts!.take(10).toList());
    }
    if (municipalities?.isNotEmpty == true) {
      query = query.where(
        'municipality',
        whereIn: municipalities!.take(10).toList(),
      );
    }

    final snapshot = await query.limit(limit).get();
    return snapshot.docs
        .map((doc) => Hotspot.fromMap(doc.data(), doc.id))
        .toList();
  }

  static Future<List<Hotspot>> _searchWithCache(
    String query,
    int limit,
    List<String>? districts,
    List<String>? municipalities,
    List<String>? categories,
    TouristPreferences? preferences,
  ) async {
    final allHotspots = await HotspotCache.getCachedHotspots();
    final lowerQuery = query.toLowerCase();

    final filtered =
        allHotspots.where((hotspot) {
          return _matchesSearch(hotspot, lowerQuery) &&
              _matchesFilter(hotspot.district, districts) &&
              _matchesFilter(hotspot.municipality, municipalities) &&
              _matchesFilter(hotspot.category, categories);
        }).toList();

    return preferences != null
        ? _scoreAndSortHotspots(filtered, preferences).take(limit).toList()
        : filtered.take(limit).toList();
  }

  static bool _matchesSearch(Hotspot hotspot, String query) {
    return query.isEmpty ||
        [
          hotspot.name,
          hotspot.description,
          hotspot.category,
        ].any((field) => field.toLowerCase().contains(query));
  }

  static bool _matchesFilter(String value, List<String>? filters) {
    return filters?.isEmpty != false || filters!.contains(value);
  }

  /// Specialized recommendation methods
  static Future<List<Hotspot>> getJustForYouRecommendations({
    int limit = 10,
  }) async {
    final recommendations = await getPersonalizedRecommendations(limit: limit);
    return recommendations.where((h) => h.isArchived != true).toList();
  }

  /// Improved version of getNearbyRecommendations with better error handling and validation
  static Future<List<Hotspot>> getNearbyRecommendations({
    required double userLat,
    required double userLng,
    int limit = 10,
    double maxDistanceKm = 50.0, // Add maximum distance filter
  }) async {
    try {
      // Validate input coordinates
      if (!_isValidCoordinate(userLat, userLng)) {
        throw RecommendationException(
          'Invalid coordinates provided',
          RecommendationErrorType.unknown,
        );
      }

      final hotspots = await HotspotCache.getCachedHotspots();

      // Filter valid hotspots with coordinates
      final validHotspots =
          hotspots
              .where(
                (h) =>
                    h.isArchived != true &&
                    h.latitude != null &&
                    h.longitude != null &&
                    _isValidCoordinate(h.latitude!, h.longitude!),
              )
              .toList();

      if (validHotspots.isEmpty) {
        throw RecommendationException(
          'No nearby hotspots found',
          RecommendationErrorType.noData,
        );
      }

      // Calculate distances and filter by maximum distance
      final hotspotsWithDistance = <MapEntry<Hotspot, double>>[];

      for (final hotspot in validHotspots) {
        final distance = _calculateDistance(
          userLat,
          userLng,
          hotspot.latitude!,
          hotspot.longitude!,
        );

        // Only include hotspots within the maximum distance
        if (distance <= maxDistanceKm) {
          hotspotsWithDistance.add(MapEntry(hotspot, distance));
        }
      }

      // Sort by distance (closest first)
      hotspotsWithDistance.sort((a, b) => a.value.compareTo(b.value));

      // Return the closest hotspots up to the limit
      return hotspotsWithDistance
          .take(limit)
          .map((entry) => entry.key)
          .toList();
    } catch (e) {
      if (kDebugMode) print('Error getting nearby recommendations: $e');
      if (e is RecommendationException) rethrow;
      throw RecommendationException(
        'Failed to get nearby recommendations',
        RecommendationErrorType.unknown,
      );
    }
  }

  /// Helper method to validate coordinates
  static bool _isValidCoordinate(double lat, double lng) {
    return lat.isFinite &&
        lng.isFinite &&
        lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180;
  }

  static Future<List<Hotspot>> getHiddenGemsRecommendations({
    int limit = 10,
  }) async {
    final recommendations = await getPersonalizedRecommendations(limit: 50);
    return recommendations
        .where((h) => _isHiddenGem(h) && h.isArchived != true)
        .take(limit)
        .toList();
  }

  static bool _isHiddenGem(Hotspot hotspot) {
    return ['hidden', 'secret', 'undiscovered', 'local'].any(
      (keyword) =>
          hotspot.category.toLowerCase().contains(keyword) ||
          hotspot.description.toLowerCase().contains(keyword),
    );
  }

  static Future<List<Hotspot>> getTrendingHotspots({int limit = 10}) async {
    final hotspots = await HotspotCache.getCachedHotspots();
    final trending = hotspots.where((h) => h.isArchived != true).toList();
    trending.sort(
      (a, b) => a.name.compareTo(b.name),
    ); // Replace with actual trending logic
    return trending.take(limit).toList();
  }

  static Future<List<Hotspot>> getRecommendationsByCategory(
    String category, {
    int limit = 5,
  }) async {
    final preferences = await getUserPreferences();
    final snapshot =
        await FirebaseFirestore.instance
            .collection('hotspots')
            .where('category', isEqualTo: category)
            .limit(limit * 2)
            .get();

    final hotspots =
        snapshot.docs
            .map((doc) => Hotspot.fromMap(doc.data(), doc.id))
            .toList();
    return preferences != null
        ? _scoreAndSortHotspots(hotspots, preferences).take(limit).toList()
        : hotspots.take(limit).toList();
  }

  /// Distance calculation
  static double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const double R = 6371; // Earth radius in km
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _deg2rad(double deg) => deg * (pi / 180);
}

/// Exception handling
enum RecommendationErrorType {
  networkError,
  noPreferences,
  noData,
  authError,
  unknown,
}

class RecommendationException implements Exception {
  final String message;
  final RecommendationErrorType type;
  RecommendationException(this.message, this.type);
  @override
  String toString() => 'RecommendationException($type): $message';
}

/// Hotspot cache
class HotspotCache {
  static List<Hotspot>? _cachedHotspots;
  static DateTime? _lastFetch;
  static const Duration _cacheExpiry = Duration(hours: 1);

  static Future<List<Hotspot>> getCachedHotspots() async {
    if (_cachedHotspots == null ||
        _lastFetch == null ||
        DateTime.now().difference(_lastFetch!) > _cacheExpiry) {
      await _refreshCache();
    }
    return _cachedHotspots!;
  }

  static Future<void> _refreshCache() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection(AppConstants.hotspotsCollection)
            .get();
    _cachedHotspots =
        snapshot.docs
            .map((doc) => Hotspot.fromMap(doc.data(), doc.id))
            .toList();
    _lastFetch = DateTime.now();
  }

  static void clearCache() {
    _cachedHotspots = null;
    _lastFetch = null;
  }
}

/// Scored hotspot helper
class ScoredHotspot {
  final Hotspot hotspot;
  final double score;
  ScoredHotspot(this.hotspot, this.score);
}
