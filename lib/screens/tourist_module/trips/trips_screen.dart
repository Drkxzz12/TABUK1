// ===========================================
// lib/screens/tourist_module/trips/trips_screen.dart
// ===========================================
// Enhanced interactive screen for displaying and managing user trips.

import 'package:flutter/material.dart';
import 'package:capstone_app/utils/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import 'trip_basic_info_screen.dart';
import '../../../services/trip_service.dart';
import '../../../services/auth_service.dart';
import '../../../models/trip_model.dart' as firestoretrip;

/// Enhanced interactive screen for displaying and managing user trips.
class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen>
    with SingleTickerProviderStateMixin {
  // UI and label constants
  static const int _tabCount = 2;
  static const String _collectionName = 'trip_planning';
  static const String _archivedStatus = 'Archived';
  static const String _planningStatus = 'Planning';
  static const String _myTripsLabel = 'My Adventures';
  static const String _activeTabLabel = 'Plans';
  static const String _archivedTabLabel = 'Archived';
  static const String _tripAddedMsg = 'Trip to {destination} added successfully!';
  static const String _tripArchivedMsg = 'Trip to {destination} archived';
  static const String _tripRestoredMsg = 'Trip to {destination} restored';
  static const String _tripDeletedMsg = 'Trip deleted';
  static const double _snackBarMargin = 16.0;
  static const double _snackBarBorderRadius = 8.0;
  static const int _snackBarDurationSec = 2;

  late TabController _tabController;
  late Stream<QuerySnapshot> _tripStream;
  String? _userId;

  /// Gets the current user ID from AuthService.
  String getUserId() {
    return AuthService.currentUser?.uid ?? '';
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _tabController.addListener(_handleTabChange);
    _userId = getUserId();
    _tripStream = FirebaseFirestore.instance
        .collection(_collectionName)
        .where('user_id', isEqualTo: _userId)
        .snapshots();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChange() {
    if (!_tabController.indexIsChanging) {
      setState(() {});
    }
  }

  /// Gets transportation icon based on transportation type
  IconData _getTransportationIcon(String transportation) {
    switch (transportation.toLowerCase()) {
      case 'car':
        return Icons.directions_car;
      case 'plane':
        return Icons.flight;
      case 'bus':
        return Icons.directions_bus;
      case 'boat':
        return Icons.directions_boat;
      case 'train':
        return Icons.train;
      default:
        return Icons.explore;
    }
  }

  /// Gets status color based on trip status
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'planning':
        return AppColors.primaryOrange;
      case 'active':
        return AppColors.homeNearbyColor;
      case 'archived':
        return AppColors.textLight;
      case 'completed':
        return AppColors.primaryTeal;
      default:
        return AppColors.textLight;
    }
  }

  /// Gets urgency color based on days until trip
  Color _getUrgencyColor(int daysUntil) {
    if (daysUntil == 0) return AppColors.errorRed;
    if (daysUntil <= 3) return AppColors.primaryOrange;
    if (daysUntil <= 7) return AppColors.homeTrendingColor;
    return AppColors.homeForYouColor;
  }

  /// Calculates days until trip start
  int _getDaysUntilTrip(DateTime startDate) {
    final now = DateTime.now();
    final difference = startDate.difference(now).inDays;
    return difference;
  }

  /// Gets trip duration in days
  int _getTripDuration(DateTime startDate, DateTime endDate) {
    return endDate.difference(startDate).inDays + 1;
  }

  /// Adds a new trip to Firestore and shows a success message
  Future<void> _addNewTrip(firestoretrip.Trip trip) async {
    try {
      final newTrip = firestoretrip.Trip(
        tripPlanId: trip.tripPlanId.isNotEmpty ? trip.tripPlanId : const Uuid().v4(),
        title: trip.title,
        startDate: trip.startDate,
        endDate: trip.endDate,
        transportation: trip.transportation,
        spots: trip.spots,
        userId: _userId ?? '',
        status: trip.status,
      );
      await TripService.saveTrip(newTrip);
      _showSnackBar(_tripAddedMsg.replaceFirst('{destination}', trip.title), AppColors.homeNearbyColor);
    } catch (e) {
      _showSnackBar('Failed to add trip: $e', AppColors.errorRed);
    }
  }

  /// Archives a trip and shows a message
  Future<void> _archiveTrip(firestoretrip.Trip trip) async {
    try {
      final archivedTrip = firestoretrip.Trip(
        tripPlanId: trip.tripPlanId,
        title: trip.title,
        startDate: trip.startDate,
        endDate: trip.endDate,
        transportation: trip.transportation,
        spots: trip.spots,
        userId: trip.userId,
        status: _archivedStatus,
      );
      await TripService.saveTrip(archivedTrip);
      _showSnackBar(_tripArchivedMsg.replaceFirst('{destination}', trip.title), AppColors.primaryTeal);
    } catch (e) {
      _showSnackBar('Failed to archive trip: $e', AppColors.errorRed);
    }
  }

  /// Restores an archived trip and shows a message
  Future<void> _restoreTrip(firestoretrip.Trip trip) async {
    try {
      final restoredTrip = firestoretrip.Trip(
        tripPlanId: trip.tripPlanId,
        title: trip.title,
        startDate: trip.startDate,
        endDate: trip.endDate,
        transportation: trip.transportation,
        spots: trip.spots,
        userId: trip.userId,
        status: _planningStatus,
      );
      await TripService.saveTrip(restoredTrip);
      _showSnackBar(_tripRestoredMsg.replaceFirst('{destination}', trip.title), AppColors.homeNearbyColor);
    } catch (e) {
      _showSnackBar('Failed to restore trip: $e', AppColors.errorRed);
    }
  }

  /// Deletes a trip with confirmation dialog
  Future<void> _deleteTrip(String tripPlanId, String tripTitle) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: AppColors.errorRed, size: 28),
            const SizedBox(width: 12),
            Text(
              'Delete Trip',
              style: TextStyle(
                color: AppColors.textDark,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "$tripTitle"? This action cannot be undone.',
          style: TextStyle(color: AppColors.textLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textLight,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorRed,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await TripService.deleteTrip(tripPlanId);
        _showSnackBar(_tripDeletedMsg, AppColors.errorRed);
      } catch (e) {
        _showSnackBar('Failed to delete trip: $e', AppColors.errorRed);
      }
    }
  }

  /// Shows a SnackBar with the given message and color
  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              color == AppColors.homeNearbyColor ? Icons.check_circle_rounded : 
              color == AppColors.errorRed ? Icons.error_rounded : Icons.info_rounded,
              color: AppColors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(_snackBarMargin),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_snackBarBorderRadius),
        ),
        duration: const Duration(seconds: _snackBarDurationSec),
        elevation: 4,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _tripStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.backgroundGradient,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryTeal),
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Loading your adventures...',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.backgroundGradient,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: AppColors.errorRed,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Something went wrong',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Error: ${snapshot.error}',
                      style: TextStyle(color: AppColors.textLight),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => setState(() {}),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryTeal,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        
        final trips = snapshot.data?.docs
                .map((doc) {
                  final data = doc.data();
                  if (data is Map<String, dynamic>) {
                    return firestoretrip.Trip.fromMap(data);
                  }
                  return null;
                })
                .whereType<firestoretrip.Trip>()
                .toList() ??
            [];
        
        final myTrips = trips.where((t) => t.status != _archivedStatus).toList();
        final archivedTrips = trips.where((t) => t.status == _archivedStatus).toList();
        
        return DefaultTabController(
          length: _tabCount,
          child: Scaffold(
            appBar: AppBar(
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.luggage_rounded,
                      size: 24,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _myTripsLabel,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryTeal,
                      AppColors.primaryTeal.withOpacity(0.8),
                    ],
                  ),
                ),
              ),
              elevation: 0,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.primaryTeal,
                        AppColors.primaryTeal.withOpacity(0.8),
                      ],
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicatorColor: AppColors.white,
                    indicatorWeight: 3,
                    labelColor: AppColors.white,
                    unselectedLabelColor: AppColors.white.withOpacity(0.7),
                    tabs: [
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.explore_rounded, size: 18),
                            const SizedBox(width: 6),
                            const Text(_activeTabLabel),
                            if (myTrips.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryOrange,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${myTrips.length}',
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.archive_rounded, size: 18),
                            const SizedBox(width: 6),
                            const Text(_archivedTabLabel),
                            if (archivedTrips.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.textLight,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${archivedTrips.length}',
                                  style: const TextStyle(
                                    color: AppColors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            body: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.backgroundGradient,
              ),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTripList(myTrips, false),
                  _buildTripList(archivedTrips, true),
                ],
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TripBasicInfoScreen(
                      destination: "New Destination",
                    ),
                  ),
                );
                if (result != null && result is Map<String, dynamic>) {
                  final trip = firestoretrip.Trip.fromMap(result);
                  if (result['fromDestinationSelection'] == true) {
                    await TripService.saveTrip(trip);
                    _showSnackBar(_tripAddedMsg.replaceFirst('{destination}', trip.title), AppColors.homeNearbyColor);
                  } else {
                    _addNewTrip(trip);
                  }
                  if (_tabController.index != 0) {
                    _tabController.animateTo(0);
                  }
                }
              },
              icon: const Icon(Icons.add_rounded, size: 24),
              label: const Text(
                'New Plan',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              backgroundColor: AppColors.primaryOrange,
              foregroundColor: AppColors.white,
              elevation: 4,
            ),
          ),
        );
      },
    );
  }

  /// Shows the edit trip form/modal and saves changes
  Future<void> _editTrip(firestoretrip.Trip trip) async {
    final TextEditingController nameController = TextEditingController(text: trip.title);
    DateTime startDate = trip.startDate;
    DateTime endDate = trip.endDate;
    String transportation = trip.transportation;
    List<String> spots = List<String>.from(trip.spots);
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: AppColors.cardBackground,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.homeForYouColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.edit_rounded,
                      color: AppColors.homeForYouColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Edit Trip',
                    style: TextStyle(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Destination',
                          labelStyle: TextStyle(color: AppColors.textLight),
                          prefixIcon: Icon(Icons.location_on_rounded, color: AppColors.primaryTeal),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.inputBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.primaryTeal, width: 2),
                          ),
                        ),
                        validator: (value) => value == null || value.isEmpty ? 'Please enter a destination' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: startDate,
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime(2100),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: ColorScheme.light(
                                          primary: AppColors.primaryTeal,
                                          onPrimary: AppColors.white,
                                          onSurface: AppColors.textDark,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null) {
                                  setState(() {
                                    startDate = picked;
                                    if (endDate.isBefore(startDate)) {
                                      endDate = startDate.add(const Duration(days: 1));
                                    }
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Start Date',
                                  labelStyle: TextStyle(color: AppColors.textLight),
                                  prefixIcon: Icon(Icons.calendar_today_rounded, color: AppColors.primaryOrange),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: AppColors.inputBorder),
                                  ),
                                ),
                                child: Text(
                                  DateFormat('MMM dd, yyyy').format(startDate),
                                  style: TextStyle(color: AppColors.textDark),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: endDate,
                                  firstDate: startDate,
                                  lastDate: DateTime(2100),
                                  builder: (context, child) {
                                    return Theme(
                                      data: Theme.of(context).copyWith(
                                        colorScheme: ColorScheme.light(
                                          primary: AppColors.primaryTeal,
                                          onPrimary: AppColors.white,
                                          onSurface: AppColors.textDark,
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );
                                if (picked != null) {
                                  setState(() {
                                    endDate = picked;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'End Date',
                                  labelStyle: TextStyle(color: AppColors.textLight),
                                  prefixIcon: Icon(Icons.event_rounded, color: AppColors.primaryOrange),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(color: AppColors.inputBorder),
                                  ),
                                ),
                                child: Text(
                                  DateFormat('MMM dd, yyyy').format(endDate),
                                  style: TextStyle(color: AppColors.textDark),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: transportation.isNotEmpty ? transportation : null,
                        items: ['Car', 'Plane', 'Bus', 'Boat', 'Train']
                            .map((t) => DropdownMenuItem(
                                  value: t,
                                  child: Row(
                                    children: [
                                      Icon(
                                        _getTransportationIcon(t),
                                        color: AppColors.primaryTeal,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        t,
                                        style: TextStyle(color: AppColors.textDark),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              transportation = val;
                            });
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Transportation',
                          labelStyle: TextStyle(color: AppColors.textLight),
                          prefixIcon: Icon(Icons.directions_rounded, color: AppColors.homeTrendingColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.inputBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.primaryTeal, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: spots.join(', '),
                        decoration: InputDecoration(
                          labelText: 'Spots (comma separated)',
                          labelStyle: TextStyle(color: AppColors.textLight),
                          prefixIcon: Icon(Icons.place_rounded, color: AppColors.homeSeasonalColor),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.inputBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: AppColors.primaryTeal, width: 2),
                          ),
                        ),
                        maxLines: 3,
                        onChanged: (val) {
                          spots = val.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textLight,
                  ),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState?.validate() ?? false) {
                      try {
                        final updatedTrip = firestoretrip.Trip(
                          tripPlanId: trip.tripPlanId,
                          title: nameController.text.trim(),
                          startDate: startDate,
                          endDate: endDate,
                          transportation: transportation,
                          spots: spots,
                          userId: _userId ?? '',
                          status: trip.status,
                        );
                        await TripService.saveTrip(updatedTrip);
                        
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                        
                        if (mounted) {
                          _showSnackBar('Trip updated successfully!', AppColors.homeNearbyColor);
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to update trip: $e'),
                              backgroundColor: AppColors.errorRed,
                            ),
                          );
                        }
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Save Changes'),
                ),
              ],
            );
          },
        );
      },
    );
  }

    /// Builds the trip list for active or archived trips
  Widget _buildTripList(List<firestoretrip.Trip> trips, bool isArchived) {
    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                isArchived ? Icons.archive_outlined : Icons.explore_outlined,
                size: 64,
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isArchived ? 'No archived trips' : 'No active trips',
              style: TextStyle(
                fontSize: 18,
                color: AppColors.textLight,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isArchived
                  ? 'Your archived trips will appear here.'
                  : 'Start planning your next adventure!',
              style: TextStyle(
                color: AppColors.textLight.withOpacity(0.8),
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        final daysUntil = _getDaysUntilTrip(trip.startDate);
        final duration = _getTripDuration(trip.startDate, trip.endDate);

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          color: AppColors.cardBackground,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            onTap: () => _editTrip(trip),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTeal.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.location_on,
                          color: AppColors.primaryTeal,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              trip.title,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textDark,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  _getTransportationIcon(trip.transportation),
                                  size: 16,
                                  color: AppColors.textLight,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  trip.transportation,
                                  style: TextStyle(
                                    color: AppColors.textLight,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(trip.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          trip.status,
                          style: TextStyle(
                            color: _getStatusColor(trip.status),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 16, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Text(
                        '${DateFormat('MMM dd').format(trip.startDate)} - ${DateFormat('MMM dd, yyyy').format(trip.endDate)}',
                        style: TextStyle(color: AppColors.textLight),
                      ),
                      const Spacer(),
                      if (!isArchived && daysUntil >= 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getUrgencyColor(daysUntil).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            daysUntil == 0 ? 'Today!' :
                            daysUntil == 1 ? 'Tomorrow' :
                            '$daysUntil days to go',
                            style: TextStyle(
                              color: _getUrgencyColor(daysUntil),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 16, color: AppColors.textLight),
                      const SizedBox(width: 4),
                      Text(
                        '$duration day${duration != 1 ? 's' : ''}',
                        style: TextStyle(color: AppColors.textLight),
                      ),
                      if (trip.spots.isNotEmpty) ...[
                        const SizedBox(width: 16),
                        Icon(Icons.place, size: 16, color: AppColors.textLight),
                        const SizedBox(width: 4),
                        Text(
                          '${trip.spots.length} spot${trip.spots.length != 1 ? 's' : ''}',
                          style: TextStyle(color: AppColors.textLight),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (!isArchived) ...[
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _editTrip(trip),
                          tooltip: 'Edit Trip',
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.homeForYouColor.withOpacity(0.1),
                            foregroundColor: AppColors.homeForYouColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.archive_outlined),
                          onPressed: () => _archiveTrip(trip),
                          tooltip: 'Archive Trip',
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.primaryOrange.withOpacity(0.1),
                            foregroundColor: AppColors.primaryOrange,
                          ),
                        ),
                      ] else ...[
                        IconButton(
                          icon: const Icon(Icons.restore_outlined),
                          onPressed: () => _restoreTrip(trip),
                          tooltip: 'Restore Trip',
                          style: IconButton.styleFrom(
                            backgroundColor: AppColors.homeNearbyColor.withOpacity(0.1),
                            foregroundColor: AppColors.homeNearbyColor,
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteTrip(trip.tripPlanId, trip.title),
                        tooltip: 'Delete Trip',
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.errorRed.withOpacity(0.1),
                          foregroundColor: AppColors.errorRed,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  }