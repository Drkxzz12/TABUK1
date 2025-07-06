// ===========================================
// lib/models/event_model.dart
// ===========================================
// Model for events, matching Firestore schema and ERD.

/// Event model representing an event in the system.
class Event {
  /// Unique identifier for the event.
  final String eventId;
  /// Title of the event.
  final String title;
  /// Description of the event.
  final String description;
  /// Location where the event takes place.
  final String location;
  /// Start startdate and time of the event.
  final DateTime startdate;
  /// End startdate and time of the event.
  final DateTime? endstartDate;
  /// startDate and time when the event was created.
  final DateTime createdAt;
  /// Status of the event (e.g., active, cancelled) or duration.
  final String status;
  /// List of image URLs for the event.
  final List<String>? images;

  /// Creates an [Event] instance.
  const Event({
    required this.eventId,
    required this.title,
    required this.description,
    required this.location,
    required this.startdate,
    this.endstartDate,
    required this.createdAt,
    required this.status,
    this.images,
  });

  /// Creates an [Event] from a map (e.g., from Firestore).
  factory Event.fromMap(Map<String, dynamic> map, String id) {
    return Event(
      eventId: id,
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      location: map['location'] ?? '',
      startdate: map['startdate'] is DateTime
          ? map['startdate']
          : DateTime.tryParse(map['startdate'] ?? '') ?? DateTime.now(),
      endstartDate: map['end_startdate'] != null
          ? (map['end_startdate'] is DateTime
              ? map['end_startdate']
              : DateTime.tryParse(map['end_startdate'] ?? ''))
          : null,
      createdAt: map['created_at'] is DateTime
          ? map['created_at']
          : DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      status: map['status'] ?? '',
      images: map['images'] != null
          ? List<String>.from(map['images'] as List)
          : [],
    );
  }

  /// Converts the [Event] to a map for storage.
  Map<String, dynamic> toMap() {
    return {
      'event_id': eventId,
      'title': title,
      'description': description,
      'location': location,
      'startdate': startdate.toIso8601String(),
      'end_startdate': endstartDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'status': status,
      'images': images ?? [],
    };
  }
}
