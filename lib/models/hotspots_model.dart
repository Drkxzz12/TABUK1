// ===========================================
// lib/models/hotspots_model.dart
// ===========================================
// Model for tourist hotspots, including details for recommendations and display.

/// Hotspot model representing a tourist hotspot in the system.
class Hotspot {
  /// Unique identifier for the hotspot.
  final String hotspotId;
  /// Name of the hotspot.
  final String name;
  /// Description of the hotspot.
  final String description;
  /// Category of the hotspot (e.g., Natural Attraction, Restaurant).
  final String category;
  /// Location/address of the hotspot.
  final String location;
  /// District where the hotspot is located.
  final String district;
  /// Municipality where the hotspot is located.
  final String municipality;
  /// List of image URLs for the hotspot.
  final List<String> images;
  /// List of transportation options available.
  final List<String> transportation;
  /// Operating hours of the hotspot.
  final String operatingHours;
  /// Entrance fee (null if free).
  final double? entranceFee;
  /// Contact information for the hotspot.
  final String contactInfo;
  /// Whether a restroom is available.
  final bool restroom;
  /// Whether food access is available.
  final bool foodAccess;
  /// Date and time when the hotspot was created.
  final DateTime createdAt;
  /// Whether the hotspot is archived (hidden from users).
  final bool? isArchived;
  // Optional fields for extended features
  /// List of safety tips for the hotspot.
  final List<String>? safetyTips;
  /// Name of the local guide (if any).
  final String? localGuide;
  /// Suggestions for the hotspot.
  final List<String>? suggestions;
  /// Latitude coordinate.
  final double? latitude;
  /// Longitude coordinate.
  final double? longitude;

  /// Creates a [Hotspot] instance.
  const Hotspot({
    required this.hotspotId,
    required this.name,
    required this.description,
    required this.category,
    required this.location,
    required this.district,
    required this.municipality,
    required this.images,
    required this.transportation,
    required this.operatingHours,
    this.entranceFee,
    required this.contactInfo,
    required this.restroom,
    required this.foodAccess,
    required this.createdAt,
    this.safetyTips,
    this.localGuide,
    this.suggestions,
    this.latitude,
    this.longitude,
    this.isArchived,
  });

  /// Factory constructor for creating [Hotspot] from JSON.
  factory Hotspot.fromJson(Map<String, dynamic> json) {
    return Hotspot(
      hotspotId: json['hotspot_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      location: json['location'] ?? '',
      district: json['district'] ?? '',
      municipality: json['municipality'] ?? '',
      images: List<String>.from(json['images'] ?? []),
      transportation: List<String>.from(json['transportation'] ?? []),
      operatingHours: json['operating_hours'] ?? '',
      entranceFee: json['entrance_fee'] != null ? (json['entrance_fee'] as num).toDouble() : null,
      contactInfo: json['contact_info'] ?? '',
      restroom: json['restroom'] ?? false,
      foodAccess: json['food_access'] ?? false,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      safetyTips: json['safety_tips'] != null ? List<String>.from(json['safety_tips']) : null,
      localGuide: json['local_guide'],
      suggestions: json['suggestions'] != null ? List<String>.from(json['suggestions']) : null,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      isArchived: json['isArchived'],
    );
  }

  /// Factory constructor for creating [Hotspot] from Firestore Map.
  factory Hotspot.fromMap(Map<String, dynamic> map, String id) {
    return Hotspot(
      hotspotId: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      location: map['location'] ?? '',
      district: map['district'] ?? '',
      municipality: map['municipality'] ?? '',
      images: List<String>.from(map['images'] ?? []),
      transportation: List<String>.from(map['transportation'] ?? []),
      operatingHours: map['operating_hours'] ?? '',
      entranceFee: map['entrance_fee'] != null ? (map['entrance_fee'] as num).toDouble() : null,
      contactInfo: map['contact_info'] ?? '',
      restroom: map['restroom'] ?? false,
      foodAccess: map['food_access'] ?? false,
      createdAt: map['created_at'] is DateTime ? map['created_at'] : (map['created_at'] != null ? DateTime.tryParse(map['created_at']) ?? DateTime.now() : DateTime.now()),
      safetyTips: map['safety_tips'] != null ? List<String>.from(map['safety_tips']) : null,
      localGuide: map['local_guide'],
      suggestions: map['suggestions'] != null ? List<String>.from(map['suggestions']) : null,
      latitude: map['latitude'] != null ? (map['latitude'] as num).toDouble() : null,
      longitude: map['longitude'] != null ? (map['longitude'] as num).toDouble() : null,
      isArchived: map['isArchived'],
    );
  }

  /// Converts [Hotspot] to JSON.
  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'hotspot_id': hotspotId,
      'name': name,
      'description': description,
      'category': category,
      'location': location,
      'district': district,
      'municipality': municipality,
      'images': images,
      'transportation': transportation,
      'operating_hours': operatingHours,
      'entrance_fee': entranceFee,
      'contact_info': contactInfo,
      'restroom': restroom,
      'food_access': foodAccess,
      'created_at': createdAt.toIso8601String(),
    };
    if (safetyTips != null) data['safety_tips'] = safetyTips;
    if (localGuide != null) data['local_guide'] = localGuide;
    if (suggestions != null) data['suggestions'] = suggestions;
    if (latitude != null) data['latitude'] = latitude;
    if (longitude != null) data['longitude'] = longitude;
    if (isArchived != null) data['isArchived'] = isArchived;
    return data;
  }

  /// Returns a copy of this [Hotspot] with updated fields.
  Hotspot copyWith({
    String? hotspotId,
    String? name,
    String? description,
    String? category,
    String? location,
    String? district,
    String? municipality,
    List<String>? images,
    List<String>? transportation,
    String? operatingHours,
    double? entranceFee,
    String? contactInfo,
    bool? restroom,
    bool? foodAccess,
    List<String>? safetyTips,
    String? localGuide,
    List<String>? suggestions,
    DateTime? createdAt,
    double? latitude,
    double? longitude,
    bool? isArchived,
  }) {
    return Hotspot(
      hotspotId: hotspotId ?? this.hotspotId,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      location: location ?? this.location,
      district: district ?? this.district,
      municipality: municipality ?? this.municipality,
      images: images ?? this.images,
      transportation: transportation ?? this.transportation,
      operatingHours: operatingHours ?? this.operatingHours,
      entranceFee: entranceFee ?? this.entranceFee,
      contactInfo: contactInfo ?? this.contactInfo,
      restroom: restroom ?? this.restroom,
      foodAccess: foodAccess ?? this.foodAccess,
      safetyTips: safetyTips ?? this.safetyTips,
      localGuide: localGuide ?? this.localGuide,
      suggestions: suggestions ?? this.suggestions,
      createdAt: createdAt ?? this.createdAt,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  @override
  String toString() {
    return 'Hotspot{hotspotId: $hotspotId, name: $name, category: $category, lat: $latitude, lng: $longitude}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Hotspot && other.hotspotId == hotspotId;
  }

  @override
  int get hashCode => hotspotId.hashCode;

  /// Returns true if the hotspot is free to enter.
  bool get isFree => entranceFee == null || entranceFee == 0;

  /// Returns true if the hotspot has any amenities.
  bool get hasAmenities => restroom || foodAccess;

  /// Returns a formatted entrance fee string.
  String get formattedEntranceFee {
    if (isFree) return 'Free';
    return '₱${entranceFee!.toStringAsFixed(2)}';
  }
}
