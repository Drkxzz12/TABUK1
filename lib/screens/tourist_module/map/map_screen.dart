import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'search_screen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:capstone_app/services/hotspot_service.dart';
import 'package:capstone_app/models/hotspots_model.dart';
import '../../../utils/constants.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeMarkerIcons();
    _checkLocationPermission();
    _initializeHotspotStream();
  }

  @override
  void dispose() {
    _hotspotSubscription?.cancel();
    super.dispose();
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

  Future<BitmapDescriptor> _createOptimizedMarker(IconData iconData, Color color) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final radius = _markerSize / 2;

    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawCircle(Offset(radius + 1, radius + 1), radius - 4, shadowPaint);

    final mainPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(radius, radius), radius - 4, mainPaint);

    final borderPaint = Paint()
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
    final image = await picture.toImage(_markerSize.toInt(), _markerSize.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  BitmapDescriptor? _getMarkerIcon(String category) {
    return _markerIcons[category.trim()] ?? 
           _markerIcons.entries
               .firstWhere((entry) => entry.key.toLowerCase() == category.toLowerCase(),
                         orElse: () => MapEntry('', BitmapDescriptor.defaultMarker))
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
      onError: (error) => debugPrint('Error listening to hotspots stream: $error'),
    );
  }

  void _updateHotspotMarkers(List<Hotspot> hotspots) {
    _hotspotMarkers = hotspots
        .where((hotspot) => (hotspot.isArchived != true) && 
                           _getMarkerIcon(hotspot.category) != null)
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

  // Location methods
  Future<void> _checkLocationPermission() async {
    try {
      var permission = await geo.Geolocator.checkPermission();
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
      }
      
      if (mounted) {
        setState(() => _locationPermissionGranted = 
            permission != geo.LocationPermission.denied && 
            permission != geo.LocationPermission.deniedForever);
      }
    } catch (e) {
      debugPrint('Error checking location permission: $e');
      if (mounted) setState(() => _locationPermissionGranted = false);
    }
  }

  Future<void> _goToMyLocation() async {
    if (_isCheckingLocation || !mounted) return;
    
    setState(() => _isCheckingLocation = true);

    try {
      if (!await geo.Geolocator.isLocationServiceEnabled()) {
        _showDialog('GPS Disabled', 'Please enable GPS to use location features.');
        return;
      }

      if (!_locationPermissionGranted) {
        await _checkLocationPermission();
        if (!_locationPermissionGranted) {
          _showDialog('Permission Required', 'Location permission is required.');
          return;
        }
      }

      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
        timeLimit: AppConstants.kLocationTimeout,
      );

      if (!mounted) return;

      final userLocation = LatLng(position.latitude, position.longitude);

      if (!_isLocationInBukidnon(userLocation)) {
        _showDialog('Location Outside Bukidnon', 'Your location is outside the Bukidnon region.');
        return;
      }

      if (_controller.isCompleted) {
        final controller = await _controller.future;
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: userLocation, zoom: AppConstants.kLocationZoom),
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

  bool _isLocationInBukidnon(LatLng location) {
    return location.latitude >= bukidnonBounds.southwest.latitude &&
        location.latitude <= bukidnonBounds.northeast.latitude &&
        location.longitude >= bukidnonBounds.southwest.longitude &&
        location.longitude <= bukidnonBounds.northeast.longitude;
  }

  void _showDialog(String title, String content) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
      builder: (context) => Dialog(
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
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: hotspot.images.isNotEmpty
                            ? Image.network(
                                hotspot.images.first,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                                loadingBuilder: (_, child, progress) =>
                                    progress == null ? child : const Center(child: CircularProgressIndicator()),
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
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            hotspot.description,
                            style: const TextStyle(fontSize: 14, color: Colors.black87),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'Open',
                                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                hotspot.category,
                                style: const TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          ...[
                            _buildInfoRow('Transportation', hotspot.transportation.isNotEmpty ? hotspot.transportation.join(", ") : "Unknown"),
                            _buildInfoRow('Operating Hours', hotspot.operatingHours.isNotEmpty ? hotspot.operatingHours : "Unknown"),
                            _buildInfoRow('Entrance Fee', hotspot.entranceFee != null ? '₱${hotspot.entranceFee}' : "Unknown"),
                            _buildInfoRow('Contact Info', hotspot.contactInfo.isNotEmpty ? hotspot.contactInfo : "Unknown"),
                            _buildInfoRow('Restroom', hotspot.restroom ? "Available" : "Not Available"),
                            _buildInfoRow('Food Access', hotspot.foodAccess ? "Available" : "Not Available"),
                          ],
                          const SizedBox(height: 20),
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
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
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
                    pageBuilder: (context, animation, secondaryAnimation) => const SearchScreen(),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      final fade = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
                      final slide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero)
                          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
                      return FadeTransition(
                        opacity: fade,
                        child: SlideTransition(position: slide, child: child),
                      );
                    },
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      'Search  Destinations...',
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
                _MapControlButton(
                  icon: Icons.layers,
                  onPressed: () => setState(() {
                    _currentMapType = _currentMapType == MapType.normal ? MapType.satellite : MapType.normal;
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
        child: loading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
            : Icon(icon, color: iconColor ?? Colors.black87),
      ),
    );
  }
}