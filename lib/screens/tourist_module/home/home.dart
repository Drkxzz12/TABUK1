import 'package:flutter/material.dart';
import 'package:capstone_app/models/hotspots_model.dart';
import 'package:capstone_app/services/recommender_system.dart';
import 'package:capstone_app/screens/tourist_module/hotspot_details_screen.dart';
import '../../../utils/constants.dart';
import '../../../utils/colors.dart';
import 'search_bar.dart';

/// Enhanced home screen with improved UI/UX for tourists
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late AnimationController _headerAnimationController;
  late AnimationController _carouselAnimationController;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;
  
  String _greeting = '';
  IconData _greetingIcon = Icons.wb_sunny;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _setGreeting();
  }

  void _initializeAnimations() {
    _headerAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _carouselAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _headerFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.easeInOut,
    ));

    _headerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _headerAnimationController,
      curve: Curves.elasticOut,
    ));

    _headerAnimationController.forward();
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

  @override
  void dispose() {
    _headerAnimationController.dispose();
    _carouselAnimationController.dispose();
    super.dispose();
  }

  /// Fetches all home recommendations for the user.
  Future<Map<String, List<Hotspot>>> getHomeRecommendations() async {
    return {
      'forYou': await TouristRecommendationService.getPersonalizedRecommendations(limit: AppConstants.homeForYouLimit),
      'trending': await getTrendingHotspots(limit: AppConstants.homeTrendingLimit),
      'nearby': await getNearbyRecommendations(limit: AppConstants.homeNearbyLimit),
      'seasonal': await getSeasonalRecommendations(limit: AppConstants.homeSeasonalLimit),
    };
  }

  /// Fetches trending hotspots based on user interactions in the last 30 days.
  Future<List<Hotspot>> getTrendingHotspots({int limit = 5}) async {
    // TEMPORARY: Return empty list until Firestore index is created.
    return [];
  }

  /// Fetches nearby recommendations (currently uses personalized recommendations).
  Future<List<Hotspot>> getNearbyRecommendations({int limit = 5}) async {
    return await TouristRecommendationService.getPersonalizedRecommendations(limit: limit);
  }

  /// Fetches seasonal recommendations based on the current month.
  Future<List<Hotspot>> getSeasonalRecommendations({int limit = 3}) async {
    final currentMonth = DateTime.now().month;
    String seasonKeyword = '';
    if (currentMonth >= 12 || currentMonth <= 2) {
      seasonKeyword = AppConstants.seasonChristmas;
    } else if (currentMonth >= 3 && currentMonth <= 5) {
      seasonKeyword = AppConstants.seasonSummer;
    } else {
      seasonKeyword = AppConstants.seasonFestival;
    }
    return await TouristRecommendationService.searchHotspots(seasonKeyword, limit: limit);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: CustomScrollView(
        slivers: [
          // Enhanced App Bar with gradient
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryOrange.withOpacity(0.8),
                      AppColors.primaryTeal.withOpacity(0.6),
                      AppColors.backgroundColor.withOpacity(0.4),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: AnimatedBuilder(
                    animation: _headerAnimationController,
                    builder: (context, child) {
                      return FadeTransition(
                        opacity: _headerFadeAnimation,
                        child: SlideTransition(
                          position: _headerSlideAnimation,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _greetingIcon,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _greeting,
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'Discover amazing places around you',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.white70,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  // Quick stats row
                                  const SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      // Add your quick stats widgets here
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          // Search Bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SearchBarWidget(),
            ),
          ),
          // Recommendations Content
          SliverToBoxAdapter(
            child: FutureBuilder<Map<String, List<Hotspot>>>(
              future: getHomeRecommendations(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const _LoadingShimmer();
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const _EmptyState();
                }
                final data = snapshot.data!;
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _AnimatedRecommendationCarousel(
                        title: 'Just For You',
                        subtitle: 'Personalized recommendations',
                        hotspots: data['forYou'] ?? [],
                        color: AppColors.homeForYouColor,
                        icon: Icons.person_outline,
                        delay: 0,
                      ),
                      _AnimatedRecommendationCarousel(
                        title: 'Trending Now',
                        subtitle: 'What others are exploring',
                        hotspots: data['trending'] ?? [],
                        color: AppColors.homeTrendingColor,
                        icon: Icons.trending_up,
                        delay: 200,
                      ),
                      _AnimatedRecommendationCarousel(
                        title: 'Nearby Places',
                        subtitle: 'Close to your location',
                        hotspots: data['nearby'] ?? [],
                        color: AppColors.homeNearbyColor,
                        icon: Icons.location_on,
                        delay: 400,
                      ),
                      _AnimatedRecommendationCarousel(
                        title: 'Seasonal Picks',
                        subtitle: 'Perfect for this time of year',
                        hotspots: data['seasonal'] ?? [],
                        color: AppColors.homeSeasonalColor,
                        icon: Icons.wb_sunny,
                        delay: 600,
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// (SearchBar widget moved to search_bar.dart)

/// Animated recommendation carousel widget
class _AnimatedRecommendationCarousel extends StatefulWidget {
  final String title;
  final String subtitle;
  final List<Hotspot> hotspots;
  final Color color;
  final IconData icon;
  final int delay;

  const _AnimatedRecommendationCarousel({
    required this.title,
    required this.subtitle,
    required this.hotspots,
    required this.color,
    required this.icon,
    required this.delay,
  });

  @override
  State<_AnimatedRecommendationCarousel> createState() => _AnimatedRecommendationCarouselState();
}

class _AnimatedRecommendationCarouselState extends State<_AnimatedRecommendationCarousel>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    // Start animation with delay
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
    if (widget.hotspots.isEmpty) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Container(
              margin: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: widget.color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            widget.icon,
                            color: widget.color,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                widget.subtitle,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => _ViewAllScreen(
                                  title: widget.title,
                                  hotspots: widget.hotspots,
                                  color: widget.color,
                                  icon: widget.icon,
                                ),
                              ),
                            );
                          },
                          child: const Text('View All'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Horizontal List
                  SizedBox(
                    height: 220,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: widget.hotspots.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 16),
                      itemBuilder: (context, index) {
                        return _EnhancedHotspotCard(
                          hotspot: widget.hotspots[index],
                          color: widget.color,
                          index: index,
                        );
                      },
                    ),
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

/// Enhanced hotspot card with better visuals
class _EnhancedHotspotCard extends StatefulWidget {
  final Hotspot hotspot;
  final Color color;
  final int index;

  const _EnhancedHotspotCard({
    required this.hotspot,
    required this.color,
    required this.index,
  });

  @override
  State<_EnhancedHotspotCard> createState() => _EnhancedHotspotCardState();
}

class _EnhancedHotspotCardState extends State<_EnhancedHotspotCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HotspotDetailsScreen(hotspot: widget.hotspot),
          ),
        );
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
        child: Container(
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
                // Background Image
                Positioned.fill(
                  child: widget.hotspot.images.isNotEmpty
                      ? Image.network(
                          widget.hotspot.images.first,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.image, size: 40, color: Colors.grey),
                          ),
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.image, size: 40, color: Colors.grey),
                        ),
                ),
                // Gradient Overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                ),
                // Content
                Positioned(
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
                            Icon(
                              Icons.location_on,
                              color: widget.color,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                widget.hotspot.location,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --- Top-level widgets below ---

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < 3; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 200,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: 3,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (_, __) => Container(
                      width: 160,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
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
          Icon(
            Icons.explore_off,
            size: 80,
            color: Colors.grey[400],
          ),
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
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryOrange,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Explore Now',
              style: TextStyle(color: Colors.white),
            ),
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
  final IconData icon;

  const _ViewAllScreen({
    required this.title,
    required this.hotspots,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: color,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: hotspots.length,
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final hotspot = hotspots[index];
          return GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => HotspotDetailsScreen(hotspot: hotspot),
                ),
              );
            },
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
                            errorBuilder: (_, __, ___) => Container(
                              width: 100,
                              height: 80,
                              color: Colors.grey[300],
                              child: const Icon(Icons.image, size: 40, color: Colors.grey),
                            ),
                          )
                        : Container(
                            width: 100,
                            height: 80,
                            color: Colors.grey[300],
                            child: const Icon(Icons.image, size: 40, color: Colors.grey),
                          ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hotspot.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
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
        },
      ),
    );
  }
}