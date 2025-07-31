// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'dart:ui' as ui;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'search_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:capstone_app/services/hotspot_service.dart';
import 'package:capstone_app/services/favorites_service.dart';
import 'package:capstone_app/models/hotspots_model.dart';
import '../../../utils/constants.dart';
import '../../../api/api.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:capstone_app/services/arrival_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  final Completer<GoogleMapController> _controller = Completer();
  MapType _currentMapType = MapType.normal;
  bool _isMapLoading = true;
  bool _isCheckingLocation = false;
  Set<Marker> _hotspotMarkers = {};
  StreamSubscription<List<Hotspot>>? _hotspotSubscription;

  // New variables for directions
  final Set<Polyline> _polylines = {};
  bool _isLoadingDirections = false;
  LatLng? _currentUserLocation;

  // Favorites functionality
  Set<String> _favoriteHotspotIds = {};
  StreamSubscription<Set<String>>? _favoritesSubscription;

  final Map<String, BitmapDescriptor> _markerIcons = {};
  bool _markersInitialized = false;
  static const double _markerSize = 80.0;

  static const Map<String, IconData> _categoryIcons = {
    'Natural Attraction': Icons.park,
    'Cultural Site': Icons.museum,
    'Adventure Spot': Icons.forest,
    'Restaurant': Icons.restaurant,
    'Accommodation': Icons.hotel,
    'Shopping': Icons.shopping_cart,
    'Entertainment': Icons.theater_comedy,
  };

  static const Map<String, Color> _categoryColors = {
    'Natural Attraction': Colors.green,
    'Cultural Site': Colors.purple,
    'Adventure Spot': Colors.orange,
    'Restaurant': Colors.red,
    'Accommodation': Colors.teal,
    'Shopping': Colors.blue,
    'Entertainment': Colors.pink,
  };

  final LatLng bukidnonCenter = AppConstants.bukidnonCenter;
  final LatLngBounds bukidnonBounds = AppConstants.bukidnonBounds;

  bool _isDetectingArrival = false;
  final Set<String> _arrivedHotspotIdsToday = {};

  @override
  void initState() {
    super.initState();
    _initializeMarkerIcons().then((_) {
      _initializeHotspotStream();
    });
    _initializeFavoritesStream();
    _checkLocationPermission();
    _getCurrentLocation();
    _startArrivalDetection();
  }

  @override
  void dispose() {
    _hotspotSubscription?.cancel();
    _favoritesSubscription?.cancel();
    super.dispose();
  }

  // Get current user location
  Future<void> _getCurrentLocation() async {
    try {
      if (!await geo.Geolocator.isLocationServiceEnabled()) return;

      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }

      if (permission != geo.LocationPermission.denied &&
          permission != geo.LocationPermission.deniedForever) {
        final position = await geo.Geolocator.getCurrentPosition(
          desiredAccuracy: geo.LocationAccuracy.high,
        );

        if (mounted) {
          setState(() {
            _currentUserLocation = LatLng(
              position.latitude,
              position.longitude,
            );
          });
        }
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
    }
  }

  // Helper to check if a location is within Bukidnon bounds
  bool _isLocationInBukidnon(LatLng location) {
    return location.latitude >= bukidnonBounds.southwest.latitude &&
        location.latitude <= bukidnonBounds.northeast.latitude &&
        location.longitude >= bukidnonBounds.southwest.longitude &&
        location.longitude <= bukidnonBounds.northeast.longitude;
  }

  // Get directions from Google Directions API
  Future<void> _getDirections(LatLng destination) async {
    // Always check/request permission and get the latest location before requesting directions
    try {
      if (!await geo.Geolocator.isLocationServiceEnabled()) {
        _showDialog(
          'GPS Disabled',
          'Please enable GPS to use location features.',
        );
        return;
      }

      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }

      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        _showDialog(
          'Permission Required',
          'Location permission is required to get directions from your current location.',
        );
        return;
      }

      // Always get the latest location
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
        timeLimit: AppConstants.kLocationTimeout,
      );
      if (!mounted) return;
      _currentUserLocation = LatLng(position.latitude, position.longitude);
    } catch (e) {
      _showDialog(
        'Location Error',
        'Unable to get your current location for directions. Please check your device settings and try again.',
      );
      return;
    }

    if (_currentUserLocation == null) {
      _showDialog(
        'Location Required',
        'Please enable location services to get directions.',
      );
      return;
    }

    // Restrict to Bukidnon
    if (!_isLocationInBukidnon(_currentUserLocation!)) {
      _showDialog(
        'Location Restricted',
        'Directions are only available within Bukidnon.',
      );
      setState(() => _isLoadingDirections = false);
      return;
    }

    // Debug: Print the actual origin used for directions
    debugPrint(
      'Origin for directions: ${_currentUserLocation!.latitude},${_currentUserLocation!.longitude}',
    );

    setState(() {
      _isLoadingDirections = true;
      _polylines.clear();
    });

    try {
      final String url = ApiEnvironment.getDirectionsUrl(
        '${_currentUserLocation!.latitude},${_currentUserLocation!.longitude}',
        '${destination.latitude},${destination.longitude}',
      );

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          final polylinePoints = route['overview_polyline']['points'];

          // Use PolylinePoints to decode
          PolylinePoints polylinePointsDecoder = PolylinePoints();
          List<PointLatLng> result = polylinePointsDecoder.decodePolyline(
            polylinePoints,
          );

          List<LatLng> decodedPoints =
              result
                  .map((point) => LatLng(point.latitude, point.longitude))
                  .toList();

          setState(() {
            _polylines.add(
              Polyline(
                polylineId: const PolylineId('route'),
                points: decodedPoints,
                color: Colors.blue,
                width: 5,
              ),
            );
          });

          await _fitCameraToRoute(decodedPoints);
          final duration = route['legs'][0]['duration']['text'];
          final distance = route['legs'][0]['distance']['text'];
          _showRouteInfo(duration, distance);
        } else {
          _showDialog('Error', 'No route found.');
        }
      } else {
        _showDialog('Error', 'Failed to fetch directions.');
      }
    } catch (e) {
      _showDialog('Error', 'An error occurred: $e');
    } finally {
      setState(() {
        _isLoadingDirections = false;
      });
    }
  }

  // Fit camera to show the entire route
  Future<void> _fitCameraToRoute(List<LatLng> points) async {
    if (points.isEmpty || !_controller.isCompleted) return;

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (LatLng point in points) {
      minLat = minLat > point.latitude ? point.latitude : minLat;
      maxLat = maxLat < point.latitude ? point.latitude : maxLat;
      minLng = minLng > point.longitude ? point.longitude : minLng;
      maxLng = maxLng < point.longitude ? point.longitude : maxLng;
    }

    final controller = await _controller.future;
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        100.0, // padding
      ),
    );
  }

  // Enhanced route info display
  void _showRouteInfo(String duration, String distance) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.directions, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text('Route: $distance, $duration')),
            TextButton(
              onPressed: _clearRoute,
              child: const Text('Clear', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: Colors.blue,
        duration: const Duration(seconds: 6),
      ),
    );
  }

  // Clear the current route
  void _clearRoute() {
    setState(() {
      _polylines.clear();
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    // Show a brief confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Route cleared', style: TextStyle(fontSize: 14)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).padding.bottom + 90,
          left: 16,
          right: 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _toggleFavorite(Hotspot hotspot) async {
    try {
      final isCurrentlyFavorite = _favoriteHotspotIds.contains(hotspot.hotspotId);
      
      bool success;
      if (isCurrentlyFavorite) {
        success = await FavoritesService.removeFromFavorites(hotspot.hotspotId);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.favorite_border, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text('${hotspot.name} removed from favorites'),
                ],
              ),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      } else {
        success = await FavoritesService.addToFavorites(hotspot);
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.favorite, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text('${hotspot.name} added to favorites'),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          );
        }
      }

      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isCurrentlyFavorite 
                ? 'Failed to remove from favorites'
                : 'Failed to add to favorites'
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _initializeMarkerIcons() async {
    try {
      for (final entry in _categoryIcons.entries) {
        final category = entry.key;
        final icon = entry.value;
        final color = _categoryColors[category]!;
        final bitmapDescriptor = await _createOptimizedMarker(icon, color);
        _markerIcons[category] = bitmapDescriptor;
      }
      if (mounted) setState(() => _markersInitialized = true);
    } catch (e) {
      debugPrint('Error initializing marker icons: $e');
      if (mounted) setState(() => _markersInitialized = true);
    }
  }

  Future<BitmapDescriptor> _createOptimizedMarker(
    IconData iconData,
    Color color,
  ) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final radius = _markerSize / 2;

    final shadowPaint =
        Paint()
          ..color = Colors.black.withOpacity(0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(Offset(radius + 1, radius + 1), radius - 4, shadowPaint);

    final mainPaint =
        Paint()
          ..color = color
          ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(radius, radius), radius - 4, mainPaint);

    final borderPaint =
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3;
    canvas.drawCircle(Offset(radius, radius), radius - 4, borderPaint);

    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: _markerSize * 0.4,
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    final iconOffset = Offset(
      radius - textPainter.width / 2,
      radius - textPainter.height / 2,
    );
    textPainter.paint(canvas, iconOffset);

    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(
      _markerSize.toInt(),
      _markerSize.toInt(),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  BitmapDescriptor? _getMarkerIcon(String category) {
    return _markerIcons[category.trim()] ??
        _markerIcons.entries
            .firstWhere(
              (entry) => entry.key.toLowerCase() == category.toLowerCase(),
              orElse: () => MapEntry('', BitmapDescriptor.defaultMarker),
            )
            .value;
  }

  void _initializeHotspotStream() {
    _hotspotSubscription = HotspotService.getHotspotsStream().listen(
      (hotspots) {
        if (mounted && _markersInitialized) {
          setState(() {
            _updateHotspotMarkers(hotspots);
          });
        }
      },
      onError:
          (error) => debugPrint('Error listening to hotspots stream: $error'),
    );
  }

  void _initializeFavoritesStream() {
    _favoritesSubscription = FavoritesService.getFavoriteHotspotIds().listen(
      (favoriteIds) {
        if (mounted) {
          setState(() {
            _favoriteHotspotIds = favoriteIds;
          });
        }
      },
      onError: (error) => debugPrint('Error listening to favorites stream: $error'),
    );
  }

  void _updateHotspotMarkers(List<Hotspot> hotspots) {
    _hotspotMarkers =
        hotspots
            .where(
              (hotspot) =>
                  (hotspot.isArchived != true) &&
                  _getMarkerIcon(hotspot.category) != null,
            )
            .map(
              (hotspot) => Marker(
                markerId: MarkerId(hotspot.hotspotId),
                position: LatLng(
                  hotspot.latitude ?? 0.0,
                  hotspot.longitude ?? 0.0,
                ),
                icon: _getMarkerIcon(hotspot.category)!,
                onTap: () => _showHotspotDetailsSheet(hotspot),
                infoWindow: InfoWindow(
                  title: hotspot.name,
                  snippet: hotspot.category,
                ),
              ),
            )
            .toSet();
  }

  // Location methods
  Future<void> _checkLocationPermission() async {
    try {
      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }

      // Remove any references to _locationPermissionGranted
      // (No longer needed, permission logic is handled inline)
    } catch (e) {
      debugPrint('Error checking location permission: $e');
      // Remove any references to _locationPermissionGranted
      // (No longer needed, permission logic is handled inline)
    }
  }

  Future<void> _goToMyLocation() async {
    if (_isCheckingLocation || !mounted) return;

    setState(() => _isCheckingLocation = true);

    try {
      if (!await geo.Geolocator.isLocationServiceEnabled()) {
        _showDialog(
          'GPS Disabled',
          'Please enable GPS to use location features.',
        );
        return;
      }

      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }

      if (permission == geo.LocationPermission.denied ||
          permission == geo.LocationPermission.deniedForever) {
        _showDialog(
          'Permission Required',
          'Location permission is required to show your current location.',
        );
        return;
      }

      // Always get the latest location
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
        timeLimit: AppConstants.kLocationTimeout,
      );

      if (!mounted) return;

      final userLocation = LatLng(position.latitude, position.longitude);

      // Restrict to Bukidnon
      if (!_isLocationInBukidnon(userLocation)) {
        _showDialog(
          'Location Restricted',
          'This app only works within Bukidnon.',
        );
        setState(() => _isCheckingLocation = false);
        return;
      }

      setState(() {
        _currentUserLocation = userLocation;
      });

      if (_controller.isCompleted) {
        final controller = await _controller.future;
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: userLocation,
              zoom: AppConstants.kLocationZoom,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        _showDialog('Location Error', 'Unable to get your current location.');
      }
    } finally {
      if (mounted) setState(() => _isCheckingLocation = false);
    }
  }

  void _startArrivalDetection() async {
    // Listen to location changes
    geo.Geolocator.getPositionStream(
      locationSettings: geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 10, // meters
      ),
    ).listen((position) async {
      if (!mounted || _isDetectingArrival) return;
      _isDetectingArrival = true;
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;
        final userLatLng = LatLng(position.latitude, position.longitude);
        // Check each hotspot
        for (final marker in _hotspotMarkers) {
          final hotspotId = marker.markerId.value;
          final markerLatLng = marker.position;
          final distance = geo.Geolocator.distanceBetween(
            userLatLng.latitude,
            userLatLng.longitude,
            markerLatLng.latitude,
            markerLatLng.longitude,
          );
          if (distance <= 50 && !_arrivedHotspotIdsToday.contains(hotspotId)) {
            final alreadyArrived = await ArrivalService.hasArrivedToday(hotspotId);
            if (!alreadyArrived) {
              await ArrivalService.saveArrival(
                hotspotId: hotspotId,
                latitude: userLatLng.latitude,
                longitude: userLatLng.longitude,
              );
              _arrivedHotspotIdsToday.add(hotspotId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Arrival at ${marker.infoWindow.title ?? 'hotspot'} saved!'),
                    backgroundColor: Colors.green,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            }
          }
        }
      } catch (e) {
        // Optionally log error
      } finally {
        _isDetectingArrival = false;
      }
    });
  }

  void _showDialog(String title, String content) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  void _onMapCreated(GoogleMapController controller) {
    if (!mounted) return;

    _mapController = controller;
    _controller.complete(controller);
    setState(() => _isMapLoading = false);

    if (AppConstants.kMapStyle.trim().isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 100), () async {
        if (mounted && _mapController != null) {
          try {
            await _mapController!.setMapStyle(AppConstants.kMapStyle);
          } catch (e) {
            debugPrint('Map style error: $e');
          }
        }
      });
    }
  }

  void _showHotspotDetailsSheet(Hotspot hotspot) {
    showDialog(
      context: context,
      builder:
          (context) => Dialog(
            insetPadding: const EdgeInsets.all(16),
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.9,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Stack(
                children: [
                  SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(12),
                          ),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child:
                                hotspot.images.isNotEmpty
                                    ? Image.network(
                                      hotspot.images.first,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (_, __, ___) =>
                                              _buildPlaceholderImage(),
                                      loadingBuilder:
                                          (_, child, progress) =>
                                              progress == null
                                                  ? child
                                                  : const Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  ),
                                    )
                                    : _buildPlaceholderImage(),
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
                              ...[
                                _buildInfoRow(
                                  'Transportation',
                                  hotspot.transportation.isNotEmpty
                                      ? hotspot.transportation.join(", ")
                                      : "Unknown",
                                ),
                                _buildInfoRow(
                                  'Operating Hours',
                                  hotspot.operatingHours.isNotEmpty
                                      ? hotspot.operatingHours
                                      : "Unknown",
                                ),
                                _buildInfoRow(
                                  'Entrance Fee',
                                  hotspot.entranceFee != null
                                      ? '₱${hotspot.entranceFee}'
                                      : "Unknown",
                                ),
                                _buildInfoRow(
                                  'Contact Info',
                                  hotspot.contactInfo.isNotEmpty
                                      ? hotspot.contactInfo
                                      : "Unknown",
                                ),
                                _buildInfoRow(
                                  'Restroom',
                                  hotspot.restroom
                                      ? "Available"
                                      : "Not Available",
                                ),
                                _buildInfoRow(
                                  'Food Access',
                                  hotspot.foodAccess
                                      ? "Available"
                                      : "Not Available",
                                ),
                              ],
                              const SizedBox(height: 20),
                              // Action Buttons Row
                              Row(
                                children: [
                                  // Add to Favorites Button
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _toggleFavorite(hotspot),
                                      icon: Icon(
                                        _favoriteHotspotIds.contains(hotspot.hotspotId)
                                            ? Icons.favorite
                                            : Icons.favorite_border,
                                        color: _favoriteHotspotIds.contains(hotspot.hotspotId)
                                            ? Colors.red
                                            : Colors.grey,
                                      ),
                                      label: Text(
                                        _favoriteHotspotIds.contains(hotspot.hotspotId)
                                            ? 'Remove from Favorites'
                                            : 'Add to Favorites',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.black87,
                                        side: BorderSide(color: Colors.grey.shade300),
                                        padding: const EdgeInsets.symmetric(vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Get Directions Button
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          _isLoadingDirections
                                              ? null
                                              : () {
                                                Navigator.pop(context);
                                                _getDirections(
                                                  LatLng(
                                                    hotspot.latitude ?? 0.0,
                                                    hotspot.longitude ?? 0.0,
                                                  ),
                                                );
                                              },
                                      icon:
                                          _isLoadingDirections
                                              ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                              : const Icon(Icons.directions),
                                      label: Text(
                                        _isLoadingDirections
                                            ? 'Getting Directions...'
                                            : 'Get Directions',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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

  Widget _buildPlaceholderImage() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.image, size: 50, color: Colors.grey),
      ),
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

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: bukidnonCenter,
              zoom: AppConstants.kInitialZoom,
            ),
            mapType: _currentMapType,
            markers: _hotspotMarkers,
            polylines: _polylines, // Add polylines to the map
            myLocationEnabled: true,
            myLocationButtonEnabled: false, // (since you have a custom button)
            compassEnabled: false,
            mapToolbarEnabled: false,
            zoomControlsEnabled: false,
            minMaxZoomPreference: MinMaxZoomPreference(
              AppConstants.kMinZoom,
              AppConstants.kMaxZoom,
            ),
            cameraTargetBounds: CameraTargetBounds(bukidnonBounds),
            padding: EdgeInsets.only(bottom: 80 + bottomPadding),
          ),
          if (_isMapLoading || !_markersInitialized)
            Container(
              color: Colors.white,
              child: const Center(child: CircularProgressIndicator()),
            ),
          // Search button (top bar) with fade/slide transition
          Positioned(
            top: 40,
            left: 16,
            right: 16,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder:
                        (context, animation, secondaryAnimation) =>
                            const SearchScreen(),
                    transitionsBuilder: (
                      context,
                      animation,
                      secondaryAnimation,
                      child,
                    ) {
                      final fade = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeInOut,
                      );
                      final slide = Tween<Offset>(
                        begin: const Offset(0, 0.1),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      );
                      return FadeTransition(
                        opacity: fade,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey.shade500),
                    const SizedBox(width: 12),
                    Text(
                      'Search Destinations...',
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Optimized map controls (bottom right)
          Positioned(
            bottom: 16 + bottomPadding,
            right: 16,
            child: Column(
              children: [
                // Clear route button (only show if there's a route)
                if (_polylines.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _MapControlButton(
                      icon: Icons.clear,
                      onPressed: _clearRoute,
                      tooltip: 'Clear route',
                      iconColor: Colors.red,
                    ),
                  ),
                _MapControlButton(
                  icon: Icons.layers,
                  onPressed:
                      () => setState(() {
                        _currentMapType =
                            _currentMapType == MapType.normal
                                ? MapType.satellite
                                : MapType.normal;
                      }),
                  tooltip: 'Toggle map type',
                ),
                const SizedBox(height: 8),
                _MapControlButton(
                  icon: Icons.my_location,
                  onPressed: _isCheckingLocation ? null : _goToMyLocation,
                  tooltip: 'Go to my location',
                  loading: _isCheckingLocation,
                  iconColor: Colors.blue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Short, optimized map control button widget
class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final bool loading;
  final Color? iconColor;
  const _MapControlButton({
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.loading = false,
    this.iconColor,
  });
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: FloatingActionButton(
        heroTag: tooltip ?? icon.toString(),
        backgroundColor: Colors.white,
        onPressed: onPressed,
        mini: true,
        child:
            loading
                ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                : Icon(icon, color: iconColor ?? Colors.black87),
      ),
    );
  }
}
