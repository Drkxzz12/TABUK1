import 'dart:async';
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

  // Search/filter state
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedCategories = {};
  List<Hotspot> _allHotspots = [];
  bool _isSearching = false;

  // If AppConstants.mapCategories is not defined, define locally:
  final List<String> _categories = ['All', 'Nature', 'Culture', 'Adventure', 'Food', 'Shopping', 'Entertainment'];
  final LatLng bukidnonCenter = AppConstants.bukidnonCenter;
  final LatLngBounds bukidnonBounds = AppConstants.bukidnonBounds;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _initializeHotspotStream();
  }

  void _initializeHotspotStream() {
    _hotspotSubscription = HotspotService.getHotspotsStream().listen(
      (hotspots) {
        if (mounted) {
          setState(() {
            _allHotspots = hotspots;
            _hotspotMarkers = hotspots
                .map((hotspot) => Marker(
                      markerId: MarkerId(hotspot.hotspotId),
                      position: LatLng(hotspot.latitude ?? 0.0, hotspot.longitude ?? 0.0),
                      onTap: () => _showHotspotDetailsSheet(hotspot),
                    ))
                .toSet();
          });
        }
      },
      onError: (error) {
        debugPrint('Error listening to hotspots stream: $error');
      },
    );
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
        _hotspotMarkers = filteredHotspots
            .map((hotspot) => Marker(
                  markerId: MarkerId(hotspot.hotspotId),
                  position: LatLng(hotspot.latitude ?? 0.0, hotspot.longitude ?? 0.0),
                  onTap: () => _showHotspotDetailsSheet(hotspot),
                ))
            .toSet();
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
          if (_isMapLoading)
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