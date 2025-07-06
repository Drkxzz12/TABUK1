import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/event_model.dart';

/// Service class for managing events in Firestore.
class EventService {
  static const String _collection = 'events';
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Gets a stream of all events ordered by date.
  static Stream<List<Event>> getEventsStream() {
    return _firestore
        .collection(_collection)
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return Event.fromMap(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Gets all events as a future.
  static Future<List<Event>> getAllEvents() async {
    final snapshot = await _firestore
        .collection(_collection)
        .orderBy('date', descending: false)
        .get();
    
    return snapshot.docs.map((doc) {
      return Event.fromMap(doc.data(), doc.id);
    }).toList();
  }

  /// Gets events for a specific date.
  static Future<List<Event>> getEventsForDate(DateTime date) async {
    final startOfDay = Timestamp.fromDate(DateTime(date.year, date.month, date.day));
    final endOfDay = Timestamp.fromDate(DateTime(date.year, date.month, date.day, 23, 59, 59));
    final snapshot = await _firestore
        .collection(_collection)
        .where('date', isGreaterThanOrEqualTo: startOfDay)
        .where('date', isLessThanOrEqualTo: endOfDay)
        .orderBy('date')
        .get();
    return snapshot.docs.map((doc) {
      return Event.fromMap(doc.data(), doc.id);
    }).toList();
  }

  /// Gets events for a specific month.
  static Future<List<Event>> getEventsForMonth(DateTime month) async {
    final startOfMonth = Timestamp.fromDate(DateTime(month.year, month.month, 1));
    final endOfMonth = Timestamp.fromDate(DateTime(month.year, month.month + 1, 0, 23, 59, 59));
    final snapshot = await _firestore
        .collection(_collection)
        .where('date', isGreaterThanOrEqualTo: startOfMonth)
        .where('date', isLessThanOrEqualTo: endOfMonth)
        .orderBy('date')
        .get();
    return snapshot.docs.map((doc) {
      return Event.fromMap(doc.data(), doc.id);
    }).toList();
  }

  /// Gets upcoming events (from today onwards).
  static Future<List<Event>> getUpcomingEvents({int limit = 10}) async {
    final now = Timestamp.fromDate(DateTime.now());
    final snapshot = await _firestore
        .collection(_collection)
        .where('date', isGreaterThanOrEqualTo: now)
        .where('status', isEqualTo: 'active')
        .orderBy('date')
        .limit(limit)
        .get();
    return snapshot.docs.map((doc) {
      return Event.fromMap(doc.data(), doc.id);
    }).toList();
  }

  /// Gets a single event by ID.
  static Future<Event?> getEventById(String eventId) async {
    final doc = await _firestore.collection(_collection).doc(eventId).get();
    
    if (doc.exists) {
      return Event.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  /// Adds a new event.
  static Future<String> addEvent(Event event) async {
    final docRef = await _firestore.collection(_collection).add(event.toMap());
    return docRef.id;
  }

  /// Updates an existing event.
  static Future<void> updateEvent(Event event) async {
    await _firestore
        .collection(_collection)
        .doc(event.eventId)
        .update(event.toMap());
  }

  /// Deletes an event.
  static Future<void> deleteEvent(String eventId) async {
    await _firestore.collection(_collection).doc(eventId).delete();
  }

  /// Searches events by title or description.
  static Future<List<Event>> searchEvents(String query) async {
    // For scalability, use Firestore queries for prefix search on title (if needed, add indexes)
    final snapshot = await _firestore
        .collection(_collection)
        .where('status', isEqualTo: 'active')
        .orderBy('title')
        .startAt([query])
        .endAt(['$query\uf8ff'])
        .get();
    // Fallback to in-memory filter for description (Firestore doesn't support OR queries well)
    final events = snapshot.docs.map((doc) => Event.fromMap(doc.data(), doc.id)).toList();
    return events.where((event) =>
        event.title.toLowerCase().contains(query.toLowerCase()) ||
        event.description.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  /// Gets events by status.
  static Future<List<Event>> getEventsByStatus(String status) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('status', isEqualTo: status)
        .orderBy('date')
        .get();
    
    return snapshot.docs.map((doc) {
      return Event.fromMap(doc.data(), doc.id);
    }).toList();
  }

  /// Gets events count by status.
  static Future<Map<String, int>> getEventsCountByStatus() async {
    final snapshot = await _firestore.collection(_collection).get();
    final events = snapshot.docs.map((doc) => Event.fromMap(doc.data(), doc.id)).toList();
    
    final counts = <String, int>{};
    for (final event in events) {
      counts[event.status] = (counts[event.status] ?? 0) + 1;
    }
    
    return counts;
  }
}