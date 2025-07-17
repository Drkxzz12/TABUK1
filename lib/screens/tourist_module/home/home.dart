import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:capstone_app/models/hotspots_model.dart';
import 'package:capstone_app/services/recommender_system.dart';
import '../../../utils/constants.dart';
import '../../../utils/colors.dart';
import 'search_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  Position? _userPosition;
  bool _locationLoading = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  final _recommendations = <String, List<Hotspot>>{};
  String _greeting = '';
  IconData _greetingIcon = Icons.wb_sunny;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setGreeting();
    _fetchLocationAndRecommendations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    
    _slideAnimation = Tween<Offset>(begin: const Offset(0, -0.5), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.elasticOut));
    
    _animationController.forward();
  }

  void _setGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = 'Good Morning! ☀️';
      _greetingIcon = Icons.wb_sunny;
    } else if (hour < 18) {
      _greeting = 'Good Afternoon! 🌤️';
      _greetingIcon = Icons.wb_cloudy;
    } else {
      _greeting = 'Good Evening! 🌙';
      _greetingIcon = Icons.nightlight_round;
    }
  }

  Future<void> _fetchLocationAndRecommendations() async {
    setState(() => _locationLoading = true);
    
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      _userPosition = await Geolocator.getCurrentPosition();
    } catch (e) {
      _userPosition = null;
    }
    
    await _loadRecommendations();
    setState(() => _locationLoading = false);
  }

  Future<void> _loadRecommendations() async {
    final futures = await Future.wait([
      TouristRecommendationService.getJustForYouRecommendations(limit: AppConstants.homeForYouLimit),
      TouristRecommendationService.getTrendingHotspots(limit: AppConstants.homeTrendingLimit),
      _getNearbyRecommendations(),
      TouristRecommendationService.getHiddenGemsRecommendations(limit: 5),
    ]);
    
    _recommendations.addAll({
      'forYou': futures[0],
      'trending': futures[1],
      'nearby': futures[2],
      'discover': futures[3],
    });
  }

  Future<List<Hotspot>> _getNearbyRecommendations() async {
    try {
      if (_userPosition != null) {
        final lat = _userPosition!.latitude;
        final lng = _userPosition!.longitude;
        
        if (lat.isFinite && lng.isFinite) {
          return await TouristRecommendationService.getNearbyRecommendations(
            userLat: lat,
            userLng: lng,
            limit: AppConstants.homeNearbyLimit,
            maxDistanceKm: 30.0,
          );
        }
      }
      
      return await TouristRecommendationService.getJustForYouRecommendations(
        limit: AppConstants.homeNearbyLimit,
      );
    } catch (e) {
      if (kDebugMode) print('Error getting nearby recommendations: $e');
      return await TouristRecommendationService.getJustForYouRecommendations(
        limit: AppConstants.homeNearbyLimit,
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: _locationLoading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _fetchLocationAndRecommendations,
            child: CustomScrollView(
              slivers: [
                _buildAppBar(),
                _buildSearchBar(),
                _buildRecommendations(),
              ],
            ),
          ),
    );
  }

  SliverAppBar _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primaryOrange.withOpacity(0.8),
                AppColors.primaryTeal.withOpacity(0.6),
              ],
            ),
          ),
          child: SafeArea(
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) => FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(_greetingIcon, color: Colors.white, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _greeting,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Discover amazing places around you',
                          style: TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SearchBarWidget(),
      ),
    );
  }

  SliverToBoxAdapter _buildRecommendations() {
    if (_recommendations.isEmpty) {
      return const SliverToBoxAdapter(child: _EmptyState());
    }

    final sections = [
      _SectionConfig('Just For You', 'Personalized recommendations', 'forYou', 
          AppColors.homeForYouColor, Icons.person_outline),
      _SectionConfig('Trending Hotspots', 'What others are exploring', 'trending', 
          AppColors.homeTrendingColor, Icons.trending_up),
      _SectionConfig('Nearby Hotspots', 'Close to your location', 'nearby', 
          AppColors.homeNearbyColor, Icons.location_on),
      _SectionConfig('Discover Hidden Gems', 'Lesser-known spots', 'discover', 
          AppColors.homeSeasonalColor, Icons.visibility_off),
    ];

    return SliverToBoxAdapter(
      child: Column(
        children: [
          ...sections.asMap().entries.map((entry) {
            final config = entry.value;
            final hotspots = _recommendations[config.key] ?? [];
            return hotspots.isNotEmpty 
              ? _RecommendationSection(
                  config: config,
                  hotspots: hotspots,
                  delay: entry.key * 200,
                )
              : const SizedBox.shrink();
          }),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SectionConfig {
  final String title;
  final String subtitle;
  final String key;
  final Color color;
  final IconData icon;

  const _SectionConfig(this.title, this.subtitle, this.key, this.color, this.icon);
}

class _RecommendationSection extends StatefulWidget {
  final _SectionConfig config;
  final List<Hotspot> hotspots;
  final int delay;

  const _RecommendationSection({
    required this.config,
    required this.hotspots,
    required this.delay,
  });

  @override
  State<_RecommendationSection> createState() => _RecommendationSectionState();
}

class _RecommendationSectionState extends State<_RecommendationSection>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Container(
            margin: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 16),
                _buildHotspotsList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.config.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(widget.config.icon, color: widget.config.color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.config.title,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.config.subtitle,
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _navigateToViewAll(),
            child: const Text('View All'),
          ),
        ],
      ),
    );
  }

  Widget _buildHotspotsList() {
    return SizedBox(
      height: 220,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.hotspots.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) => _HotspotCard(
          hotspot: widget.hotspots[index],
          color: widget.config.color,
        ),
      ),
    );
  }

  void _navigateToViewAll() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ViewAllScreen(
          title: widget.config.title,
          hotspots: widget.hotspots,
          color: widget.config.color,
        ),
      ),
    );
  }
}

class _HotspotCard extends StatefulWidget {
  final Hotspot hotspot;
  final Color color;

  const _HotspotCard({required this.hotspot, required this.color});

  @override
  State<_HotspotCard> createState() => _HotspotCardState();
}

class _HotspotCardState extends State<_HotspotCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () => _showHotspotDetailsDialog(context, widget.hotspot),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
        width: 160,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              _buildImage(),
              _buildGradientOverlay(),
              _buildContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    return Positioned.fill(
      child: widget.hotspot.images.isNotEmpty
          ? Image.network(
              widget.hotspot.images.first,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildPlaceholder(),
            )
          : _buildPlaceholder(),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[300],
      child: const Icon(Icons.image, size: 40, color: Colors.grey),
    );
  }

  Widget _buildGradientOverlay() {
    return Positioned.fill(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.hotspot.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, color: widget.color, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.hotspot.location,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.explore_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No recommendations yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start exploring to get personalized recommendations',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Explore Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _ViewAllScreen extends StatelessWidget {
  final String title;
  final List<Hotspot> hotspots;
  final Color color;

  const _ViewAllScreen({
    required this.title,
    required this.hotspots,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: color,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: hotspots.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) => _ViewAllCard(
          hotspot: hotspots[index],
          color: color,
        ),
      ),
    );
  }
}

class _ViewAllCard extends StatelessWidget {
  final Hotspot hotspot;
  final Color color;

  const _ViewAllCard({required this.hotspot, required this.color});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showHotspotDetailsDialog(context, hotspot),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: hotspot.images.isNotEmpty
                  ? Image.network(
                      hotspot.images.first,
                      width: 100,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hotspot.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, color: color, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          hotspot.location,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 100,
      height: 80,
      color: Colors.grey[300],
      child: const Icon(Icons.image, size: 40, color: Colors.grey),
    );
  }
}

// Global function for showing hotspot details dialog
void _showHotspotDetailsDialog(BuildContext context, Hotspot hotspot) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (context) => Dialog(
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
                  _buildDialogImage(hotspot),
                  _buildDialogContent(hotspot),
                ],
              ),
            ),
            _buildCloseButton(context),
          ],
        ),
      ),
    ),
  );
}

Widget _buildDialogImage(Hotspot hotspot) {
  return ClipRRect(
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
              errorBuilder: (_, __, ___) => _buildDialogPlaceholder(),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: Colors.grey[300],
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
            )
          : _buildDialogPlaceholder(),
    ),
  );
}

Widget _buildDialogPlaceholder() {
  return Container(
    color: Colors.grey[300],
    child: const Center(
      child: Icon(Icons.image, size: 50, color: Colors.grey),
    ),
  );
}

Widget _buildDialogContent(Hotspot hotspot) {
  return Padding(
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
        ..._buildInfoRows(hotspot),
        const SizedBox(height: 20),
      ],
    ),
  );
}

List<Widget> _buildInfoRows(Hotspot hotspot) {
  return [
    _buildInfoRow('Transportation Available', 
        hotspot.transportation.isNotEmpty ? hotspot.transportation.join(", ") : "Unknown"),
    _buildInfoRow('Operating Hours', 
        hotspot.operatingHours.isNotEmpty ? hotspot.operatingHours : "Unknown"),
    _buildInfoRow('Safety Tips & Warnings', 
        (hotspot.safetyTips?.isNotEmpty ?? false) ? hotspot.safetyTips!.join(", ") : "Unknown"),
    _buildInfoRow('Entrance Fee', 
        hotspot.entranceFee != null ? '₱${hotspot.entranceFee}' : "Unknown"),
    _buildInfoRow('Contact Info', 
        hotspot.contactInfo.isNotEmpty ? hotspot.contactInfo : "Unknown"),
    _buildInfoRow('Local Guide', 
        (hotspot.localGuide?.isNotEmpty ?? false) ? hotspot.localGuide! : "Unknown"),
    _buildInfoRow('Restroom', hotspot.restroom ? "Available" : "Not Available"),
    _buildInfoRow('Food Access', hotspot.foodAccess ? "Available" : "Not Available"),
    _buildInfoRow('Suggested to Bring', 
        (hotspot.suggestions?.isNotEmpty ?? false) ? hotspot.suggestions!.join(", ") : "Unknown"),
  ];
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

Widget _buildCloseButton(BuildContext context) {
  return Positioned(
    top: 16,
    right: 16,
    child: Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: const Icon(Icons.close, color: Colors.white, size: 24),
        onPressed: () => Navigator.pop(context),
        tooltip: 'Close',
      ),
    ),
  );
}