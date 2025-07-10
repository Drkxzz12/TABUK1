import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:capstone_app/services/hotspot_service.dart';
import 'package:capstone_app/models/hotspots_model.dart';
import '../../../utils/constants.dart';

/// Map screen for tourists to explore hotspots in Bukidnon with search, filter, and details.
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
  bool _locationPermissionGranted = false;
  bool _isCheckingLocation = false;
  Set<Marker> _hotspotMarkers = {};
  StreamSubscription<List<Hotspot>>? _hotspotSubscription;
  
  // Custom marker icons
  Map<String, BitmapDescriptor> _markerIcons = {};
  bool _markersInitialized = false;

  // Search/filter state
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedCategories = {};
  List<Hotspot> _allHotspots = [];
  bool _isSearching = false;

  // If AppConstants.mapCategories is not defined, define locally:
  final List<String> _categories = [
    'All',
    'Natural Attraction',
    'Cultural Site',
    'Adventure Spot',
    'Restaurant',
    'Accommodation',
    'Shopping',
    'Entertainment',
  ];
  final LatLng bukidnonCenter = AppConstants.bukidnonCenter;
  final LatLngBounds bukidnonBounds = AppConstants.bukidnonBounds;

  @override
  void initState() {
    super.initState();
    _initializeMarkerIcons();
    _checkLocationPermission();
    _initializeHotspotStream();
  }


  /// Initialize category-specific styled marker icons (no default marker)
  Future<void> _initializeMarkerIcons() async {
    try {
      // Backend-aligned categories
      final Map<String, IconData> categoryIcons = {
        'Natural Attraction': Icons.park, 
        'Cultural Site': Icons.museum, 
        'Adventure Spot': Icons.forest, 
        'Restaurant': Icons.brunch_dining, 
        'Accommodation': Icons.cottage, 
        'Shopping': Icons.shopping_cart_checkout, 
        'Entertainment': Icons.theater_comedy, 

      };
      final Map<String, Color> categoryColors = {
        'Natural Attraction': Colors.green,
        'Cultural Site': Colors.purple,
        'Adventure Spot': Colors.orange,
        'Restaurant': Colors.red,
        'Accommodation': Colors.teal,
        'Shopping': Colors.blue,
        'Entertainment': Colors.pink,
      };
      for (final entry in categoryIcons.entries) {
        final category = entry.key;
        final icon = entry.value;
        final color = categoryColors[category]!;
        final bitmapDescriptor = await _createCategoryStyledMarker(category, icon, color);
        _markerIcons[category] = bitmapDescriptor;
      }
      setState(() {
        _markersInitialized = true;
      });
    } catch (e) {
      debugPrint('Error initializing marker icons: $e');
      setState(() {
        _markersInitialized = true;
      });
    }
  }

  /// Category-specific styled marker creation (no default marker)
  Future<BitmapDescriptor> _createCategoryStyledMarker(String category, IconData iconData, Color color) async {
    switch (category) {
      case 'Natural Attraction':
        return await _createNatureMarker(iconData, color);
      case 'Cultural Site':
        return await _createCultureMarker(iconData, color);
      case 'Adventure Spot':
        return await _createAdventureMarker(iconData, color);
      case 'Restaurant':
        return await _createFoodMarker(iconData, color);
      case 'Shopping':
        return await _createShoppingMarker(iconData, color);
      case 'Entertainment':
        return await _createEntertainmentMarker(iconData, color);
      default:
        throw Exception('Unknown category: $category');
    }
  }

  // --- Marker style implementations ---
  Future<BitmapDescriptor> _createNatureMarker(IconData iconData, Color color) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final size = 120.0;
    final radius = size / 2;
    // Leaf pattern background
    final leafPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 8; i++) {
      final angle = (i * 45) * (3.14159 / 180);
      final leafPath = Path();
      final startX = radius + (radius * 0.85) * math.cos(angle);
      final startY = radius + (radius * 0.85) * math.sin(angle);
      leafPath.moveTo(startX, startY);
      leafPath.quadraticBezierTo(
        startX + 12 * math.cos(angle + 0.3),
        startY + 12 * math.sin(angle + 0.3),
        startX + 8 * math.cos(angle),
        startY + 8 * math.sin(angle),
      );
      leafPath.quadraticBezierTo(
        startX + 12 * math.cos(angle - 0.3),
        startY + 12 * math.sin(angle - 0.3),
        startX,
        startY,
      );
      canvas.drawPath(leafPath, leafPaint);
    }
    // Main circle
    final paint = Paint()..color = color;
    canvas.drawCircle(Offset(radius, radius), radius - 6, paint);
    // Icon
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: size * 0.5,
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    final iconOffset = Offset(radius - textPainter.width / 2, radius - textPainter.height / 2);
    textPainter.paint(canvas, iconOffset);
    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = byteData!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(uint8List);
  }

  Future<BitmapDescriptor> _createCultureMarker(IconData iconData, Color color) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final size = 120.0;
    final radius = size / 2;
    // Architectural columns
    final columnPaint = Paint()
      ..color = color.withOpacity(0.25)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 4; i++) {
      final angle = (i * 90) * (3.14159 / 180);
      final columnX = radius + (radius * 0.9) * math.cos(angle);
      final columnY = radius + (radius * 0.9) * math.sin(angle);
      final baseRect = Rect.fromCenter(center: Offset(columnX, columnY + 8), width: 12, height: 4);
      canvas.drawRect(baseRect, columnPaint);
      final shaftRect = Rect.fromCenter(center: Offset(columnX, columnY), width: 8, height: 20);
      canvas.drawRect(shaftRect, columnPaint);
      final capitalRect = Rect.fromCenter(center: Offset(columnX, columnY - 8), width: 14, height: 5);
      canvas.drawRect(capitalRect, columnPaint);
    }
    // Main circle
    final paint = Paint()..color = color;
    canvas.drawCircle(Offset(radius, radius), radius - 6, paint);
    // Icon
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: size * 0.5,
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    final iconOffset = Offset(radius - textPainter.width / 2, radius - textPainter.height / 2);
    textPainter.paint(canvas, iconOffset);
    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = byteData!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(uint8List);
  }

  Future<BitmapDescriptor> _createAdventureMarker(IconData iconData, Color color) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final size = 120.0;
    final radius = size / 2;
    // Mountain silhouette
    final mountainPaint = Paint()
      ..color = color.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    final mountainPath = Path();
    mountainPath.moveTo(20, radius + 30);
    mountainPath.lineTo(40, radius - 10);
    mountainPath.lineTo(60, radius + 10);
    mountainPath.lineTo(80, radius - 20);
    mountainPath.lineTo(100, radius + 20);
    mountainPath.lineTo(120, radius + 30);
    mountainPath.close();
    canvas.drawPath(mountainPath, mountainPaint);
    // Main circle
    final paint = Paint()..color = color;
    canvas.drawCircle(Offset(radius, radius), radius - 6, paint);
    // Icon
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: size * 0.5,
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    final iconOffset = Offset(radius - textPainter.width / 2, radius - textPainter.height / 2);
    textPainter.paint(canvas, iconOffset);
    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = byteData!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(uint8List);
  }

  Future<BitmapDescriptor> _createFoodMarker(IconData iconData, Color color) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final size = 120.0;
    final radius = size / 2;
    // Plate-like outer ring
    final platePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8.0;
    canvas.drawCircle(Offset(radius, radius), radius - 6, platePaint);
    // Main circle
    final paint = Paint()..color = color;
    canvas.drawCircle(Offset(radius, radius), radius - 14, paint);
    // Icon
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: size * 0.5,
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    final iconOffset = Offset(radius - textPainter.width / 2, radius - textPainter.height / 2);
    textPainter.paint(canvas, iconOffset);
    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = byteData!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(uint8List);
  }

  Future<BitmapDescriptor> _createShoppingMarker(IconData iconData, Color color) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final size = 120.0;
    final radius = size / 2;
    // Shopping bag handles
    final handlePaint = Paint()
      ..color = color.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0;
    // Left handle
    canvas.drawArc(
      Rect.fromCenter(center: Offset(radius - 15, radius - 10), width: 20, height: 20),
      0,
      3.14159,
      false,
      handlePaint,
    );
    // Right handle
    canvas.drawArc(
      Rect.fromCenter(center: Offset(radius + 15, radius - 10), width: 20, height: 20),
      0,
      3.14159,
      false,
      handlePaint,
    );
    // Main circle
    final paint = Paint()..color = color;
    canvas.drawCircle(Offset(radius, radius), radius - 6, paint);
    // Icon
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: size * 0.5,
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    final iconOffset = Offset(radius - textPainter.width / 2, radius - textPainter.height / 2);
    textPainter.paint(canvas, iconOffset);
    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = byteData!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(uint8List);
  }

  Future<BitmapDescriptor> _createEntertainmentMarker(IconData iconData, Color color) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final size = 120.0;
    final radius = size / 2;
    // Star sparkles
    final sparkPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.fill;
    for (int i = 0; i < 6; i++) {
      final angle = (i * 60) * (3.14159 / 180);
      final sparkPath = Path();
      final centerX = radius + (radius * 0.8) * math.cos(angle);
      final centerY = radius + (radius * 0.8) * math.sin(angle);
      sparkPath.moveTo(centerX, centerY - 6);
      sparkPath.lineTo(centerX + 2, centerY - 2);
      sparkPath.lineTo(centerX + 6, centerY);
      sparkPath.lineTo(centerX + 2, centerY + 2);
      sparkPath.lineTo(centerX, centerY + 6);
      sparkPath.lineTo(centerX - 2, centerY + 2);
      sparkPath.lineTo(centerX - 6, centerY);
      sparkPath.lineTo(centerX - 2, centerY - 2);
      sparkPath.close();
      canvas.drawPath(sparkPath, sparkPaint);
    }
    // Main circle
    final paint = Paint()..color = color;
    canvas.drawCircle(Offset(radius, radius), radius - 6, paint);
    // Icon
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(iconData.codePoint),
      style: TextStyle(
        fontSize: size * 0.5,
        fontFamily: iconData.fontFamily,
        package: iconData.fontPackage,
        color: Colors.white,
      ),
    );
    textPainter.layout();
    final iconOffset = Offset(radius - textPainter.width / 2, radius - textPainter.height / 2);
    textPainter.paint(canvas, iconOffset);
    final picture = pictureRecorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final uint8List = byteData!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(uint8List);
  }

  // _createDefaultMarker is now unused and has been removed.

  /// Create custom marker icon from IconData


  /// Get marker icon based on hotspot category (no default fallback)
  BitmapDescriptor? _getMarkerIcon(String category) {
    // Normalize category for robust lookup
    String normalized = category.trim();
    if (_markerIcons.containsKey(normalized)) {
      return _markerIcons[normalized];
    }
    // Try fallback: case-insensitive match
    for (final key in _markerIcons.keys) {
      if (key.toLowerCase() == normalized.toLowerCase()) {
        return _markerIcons[key];
      }
    }
    return null;
  }

  void _initializeHotspotStream() {
    _hotspotSubscription = HotspotService.getHotspotsStream().listen(
      (hotspots) {
        if (mounted && _markersInitialized) {
          setState(() {
            _allHotspots = hotspots;
            _updateHotspotMarkers(hotspots);
          });
        }
      },
      onError: (error) {
        debugPrint('Error listening to hotspots stream: $error');
      },
    );
  }

  /// Update hotspot markers with custom icons (skip if no icon available)
  void _updateHotspotMarkers(List<Hotspot> hotspots) {
    _hotspotMarkers = hotspots
        .where((hotspot) => _getMarkerIcon(hotspot.category) != null)
        .map((hotspot) => Marker(
              markerId: MarkerId(hotspot.hotspotId),
              position: LatLng(hotspot.latitude ?? 0.0, hotspot.longitude ?? 0.0),
              icon: _getMarkerIcon(hotspot.category)!,
              onTap: () => _showHotspotDetailsSheet(hotspot),
              infoWindow: InfoWindow(
                title: hotspot.name,
                snippet: hotspot.category,
              ),
            ))
        .toSet();
  }

  void _onSearch() {
    if (!mounted) return;
    setState(() => _isSearching = true);
    final query = _searchController.text.trim().toLowerCase();
    final bool showAll = _selectedCategories.contains('All') || _selectedCategories.isEmpty;
    final filteredHotspots = _allHotspots.where((hotspot) {
      final matchesQuery = query.isEmpty ||
          hotspot.name.toLowerCase().contains(query) ||
          hotspot.description.toLowerCase().contains(query);
      final matchesCategory = showAll || _selectedCategories.contains(hotspot.category);
      return matchesQuery && matchesCategory;
    }).toList();
    
    if (mounted) {
      setState(() {
        _updateHotspotMarkers(filteredHotspots);
        _isSearching = false;
      });
    }
  }

  Widget _buildFilterChips(List<String> options, Set<String> selected) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = selected.contains(option);
        return FilterChip(
          label: Text(option),
          selected: isSelected,
          onSelected: (_) {
            setState(() {
              if (option == 'All') {
                if (isSelected) {
                  selected.clear();
                } else {
                  selected.clear();
                  selected.add('All');
                }
              } else {
                selected.remove('All');
                if (isSelected) {
                  selected.remove(option);
                } else {
                  selected.add(option);
                }
              }
            });
            // Do not call _onSearch() here; only update selection
          },
        );
      }).toList(),
    );
  }

  @override
  void dispose() {
    _hotspotSubscription?.cancel();
    _searchController.dispose();
    
    // Don't manually dispose the map controller on web
    // The GoogleMap widget handles its own disposal
    _mapController = null;
    
    super.dispose();
  }

  Future<bool> _checkLocationService() async {
    try {
      final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled()
          .timeout(AppConstants.kServiceCheckTimeout);

      if (!serviceEnabled && mounted) {
        _showGpsDisabledDialog();
      }
      return serviceEnabled;
    } catch (e) {
      debugPrint('Error checking location service: $e');
      return false;
    }
  }

  void _showGpsDisabledDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('GPS is Disabled'),
          content: const Text(
            'Please enable GPS to use location features.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await geo.Geolocator.openLocationSettings();
              },
              child: const Text('Enable GPS'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkLocationPermission() async {
    try {
      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        if (permission == geo.LocationPermission.denied) {
          if (mounted) {
            setState(() => _locationPermissionGranted = false);
          }
          return;
        }
      }

      if (permission == geo.LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _locationPermissionGranted = false);
        }
        return;
      }

      if (mounted) {
        setState(() => _locationPermissionGranted = true);
      }
    } catch (e) {
      debugPrint('Error checking location permission: $e');
      if (mounted) {
        setState(() => _locationPermissionGranted = false);
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    if (!mounted) return;

    _mapController = controller;
    _controller.complete(controller);
    
    setState(() {
      _isMapLoading = false;
    });

    // Only set map style if non-empty and valid
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

  bool _isLocationInBukidnon(LatLng location) {
    return location.latitude >= bukidnonBounds.southwest.latitude &&
        location.latitude <= bukidnonBounds.northeast.latitude &&
        location.longitude >= bukidnonBounds.southwest.longitude &&
        location.longitude <= bukidnonBounds.northeast.longitude;
  }

  Future<void> _goToMyLocation() async {
    if (_isCheckingLocation || !mounted) return;
    
    setState(() => _isCheckingLocation = true);

    try {
      // First check if GPS is enabled
      final serviceEnabled = await _checkLocationService();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() => _isCheckingLocation = false);
        }
        return;
      }

      // Then check permission
      if (!_locationPermissionGranted) {
        await _checkLocationPermission();
        if (!_locationPermissionGranted) {
          _showPermissionDeniedDialog();
          if (mounted) {
            setState(() => _isCheckingLocation = false);
          }
          return;
        }
      }

      // Get current position
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
        timeLimit: AppConstants.kLocationTimeout,
      );

      if (!mounted) return;

      final userLocation = LatLng(position.latitude, position.longitude);

      if (!_isLocationInBukidnon(userLocation)) {
        _showLocationOutOfBoundsDialog();
        if (mounted) {
          setState(() => _isCheckingLocation = false);
        }
        return;
      }

      // Use the controller from the completer only if still mounted
      if (mounted && _controller.isCompleted) {
        final GoogleMapController controller = await _controller.future;
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: userLocation, zoom: AppConstants.kLocationZoom),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      if (mounted) {
        // Only show location error if GPS is on but we failed to get location
        final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          _showLocationErrorDialog();
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingLocation = false);
      }
    }
  }

  void _showPermissionDeniedDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Permission Required'),
          content: const Text(
            'Please grant location permission in settings to use this feature.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await geo.Geolocator.openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _goToBukidnonCenter() async {
    try {
      if (mounted && _controller.isCompleted) {
        final GoogleMapController controller = await _controller.future;
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: bukidnonCenter, zoom: AppConstants.kInitialZoom),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error going to Bukidnon center: $e');
    }
  }

  void _showLocationOutOfBoundsDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Outside Bukidnon'),
          content: const Text('Your location is outside the Bukidnon region.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _goToBukidnonCenter();
              },
              child: const Text('Go to Center'),
            ),
          ],
        );
      },
    );
  }

  void _showLocationErrorDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Error'),
          content: const Text(
            'Unable to get your current location. Please try again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _toggleMapType() {
    setState(() {
      _currentMapType = _currentMapType == MapType.normal
          ? MapType.satellite
          : MapType.normal;
    });
  }

  void _showHotspotDetailsSheet(Hotspot hotspot) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
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
                      // Image section
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
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      color: Colors.grey[300],
                                      child: const Center(
                                        child: Icon(
                                          Icons.image_not_supported,
                                          size: 50,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    );
                                  },
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      color: Colors.grey[300],
                                      child: const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: Colors.grey[300],
                                  child: const Center(
                                    child: Icon(
                                      Icons.image,
                                      size: 50,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      // Content section
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
                            _buildInfoRow('Transportation Available', 
                                hotspot.transportation.isNotEmpty
                                    ? hotspot.transportation.join(", ") 
                                    : "Unknown"),
                            _buildInfoRow('Operating Hours', 
                                hotspot.operatingHours.isNotEmpty
                                    ? hotspot.operatingHours 
                                    : "Unknown"),
                            _buildInfoRow('Safety Tips & Warnings', 
                                (hotspot.safetyTips != null && hotspot.safetyTips!.isNotEmpty)
                                    ? hotspot.safetyTips!.join(", ") 
                                    : "Unknown"),
                            _buildInfoRow('Entrance Fee', 
                                hotspot.entranceFee != null 
                                    ? '₱${hotspot.entranceFee}' 
                                    : "Unknown"),
                            _buildInfoRow('Contact Info', 
                                hotspot.contactInfo.isNotEmpty
                                    ? hotspot.contactInfo 
                                    : "Unknown"),
                            _buildInfoRow('Local Guide', 
                                (hotspot.localGuide != null && hotspot.localGuide!.isNotEmpty)
                                    ? hotspot.localGuide! 
                                    : "Unknown"),
                            _buildInfoRow('Restroom', 
                                hotspot.restroom ? "Available" : "Not Available"),
                            _buildInfoRow('Food Access', 
                                hotspot.foodAccess ? "Available" : "Not Available"),
                            _buildInfoRow('Suggested to Bring', 
                                (hotspot.suggestions != null && hotspot.suggestions!.isNotEmpty)
                                    ? hotspot.suggestions!.join(", ") 
                                    : "Unknown"),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Close button
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double bottomPadding = MediaQuery.of(context).padding.bottom;
    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () async {
            await showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) {
                return DraggableScrollableSheet(
                  initialChildSize: 0.5,
                  minChildSize: 0.3,
                  maxChildSize: 0.9,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        children: [
                          TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Search hotspots',
                              border: InputBorder.none,
                            ),
                            autofocus: true,
                            onSubmitted: (_) {
                              Navigator.pop(context);
                              _onSearch();
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Filters',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Categories',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          _buildFilterChips(_categories, _selectedCategories),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isSearching ? null : () {
                                Navigator.pop(context);
                                _onSearch();
                              },
                              child: _isSearching
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Apply Filters'),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
          child: AbsorbPointer(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search hotspots',
                border: InputBorder.none,
              ),
              enabled: false,
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          // Map section
          Positioned.fill(
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: bukidnonCenter,
                zoom: AppConstants.kInitialZoom,
              ),
              mapType: _currentMapType,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
              zoomControlsEnabled: false,
              indoorViewEnabled: false,
              trafficEnabled: false,
              buildingsEnabled: true,
              liteModeEnabled: false,
              zoomGesturesEnabled: true,
              scrollGesturesEnabled: true,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
              minMaxZoomPreference: MinMaxZoomPreference(
                AppConstants.kMinZoom,
                AppConstants.kMaxZoom,
              ),
              cameraTargetBounds: CameraTargetBounds(bukidnonBounds),
              padding: EdgeInsets.only(bottom: 80 + bottomPadding),
              markers: _hotspotMarkers,
            ),
          ),
          // Loading overlay
          if (_isMapLoading || !_markersInitialized)
            Container(
              color: Colors.white,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          // Custom location button
          Positioned(
            bottom: 16 + bottomPadding,
            right: 16,
            child: FloatingActionButton(
              heroTag: "location",
              backgroundColor: Colors.white,
              foregroundColor: Colors.blue,
              elevation: 4,
              onPressed: _isCheckingLocation ? null : _goToMyLocation,
              child: _isCheckingLocation
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.blue,
                      ),
                    )
                  : const Icon(Icons.my_location),
            ),
          ),
          // Map type toggle button
          Positioned(
            bottom: 80 + bottomPadding,
            right: 16,
            child: FloatingActionButton(
              heroTag: "mapType",
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 4,
              onPressed: _toggleMapType,
              child: const Icon(Icons.layers),
            ),
          ),
        ],
      ),
    );
  }
}