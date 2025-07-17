import 'dart:async';

import 'package:flutter/material.dart';
import 'package:capstone_app/models/hotspots_model.dart';
import 'package:capstone_app/services/hotspot_service.dart';
import 'package:capstone_app/utils/colors.dart';
// import 'package:capstone_app/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capstone_app/screens/tourist_module/hotspot_details_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<Hotspot> _allHotspots = [];
  List<Hotspot> _filteredHotspots = [];
  String _selectedCategory = 'All Categories';
  bool _isLoading = false;
  bool _hasSearched = false;
  bool _showRecentSearches = false;
  List<String> _recentSearches = [];
  List<String> _searchSuggestions = [];
  Timer? _searchTimer;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadHotspots();
    _loadRecentSearches();
    _setupSearchListener();
    
    // Auto-focus with slight delay for better UX
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _searchFocusNode.requestFocus();
        }
      });
    });
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  void _setupSearchListener() {
    _searchController.addListener(() {
      final query = _searchController.text.trim();
      final showRecent = query.isEmpty;
      if (_showRecentSearches != showRecent) {
        setState(() => _showRecentSearches = showRecent);
      }
      if (query.isNotEmpty) {
        _generateSuggestions(query);
      } else if (_searchSuggestions.isNotEmpty) {
        setState(() => _searchSuggestions.clear());
      }
    });
  }

  void _generateSuggestions(String query) {
    if (query.length < 2) {
      setState(() {
        _searchSuggestions.clear();
      });
      return;
    }

    final suggestions = <String>{};
    final queryLower = query.toLowerCase();

    // Add matching hotspot names
    for (final hotspot in _allHotspots) {
      if (hotspot.name.toLowerCase().contains(queryLower)) {
        suggestions.add(hotspot.name);
      }
      // Add matching locations
      if (hotspot.municipality.toLowerCase().contains(queryLower)) {
        suggestions.add('${hotspot.municipality} (Municipality)');
      }
      if (hotspot.district.toLowerCase().contains(queryLower)) {
        suggestions.add('${hotspot.district} (District)');
      }
      // Add matching categories
      if (hotspot.category.toLowerCase().contains(queryLower)) {
        suggestions.add('${hotspot.category} (Category)');
      }
    }

    // Add popular search terms
    final popularTerms = [
      'waterfalls', 'mountains', 'beaches', 'restaurants', 'hotels',
      'camping', 'hiking', 'adventure', 'cultural sites', 'museums'
    ];
    
    for (final term in popularTerms) {
      if (term.contains(queryLower)) {
        suggestions.add(term);
      }
    }

    setState(() {
      _searchSuggestions = suggestions.take(6).toList();
    });
  }

  static const String _recentSearchesKey = 'recent_searches';
  static const int _maxRecentSearches = 8;

  void _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentSearches = prefs.getStringList(_recentSearchesKey) ?? [];
      
      if (mounted) {
        setState(() {
          _recentSearches = recentSearches;
        });
      }
    } catch (e) {
      debugPrint('Error loading recent searches: $e');
      if (mounted) {
        setState(() {
          _recentSearches = [];
        });
      }
    }
  }

  void _saveRecentSearch(String searchTerm) async {
    if (searchTerm.trim().isEmpty) return;
    
    final trimmedTerm = searchTerm.trim();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      _recentSearches.remove(trimmedTerm);
      _recentSearches.insert(0, trimmedTerm);
      
      if (_recentSearches.length > _maxRecentSearches) {
        _recentSearches = _recentSearches.take(_maxRecentSearches).toList();
      }
      
      await prefs.setStringList(_recentSearchesKey, _recentSearches);
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error saving recent search: $e');
    }
  }

  void _clearRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentSearchesKey);
      
      if (mounted) {
        setState(() {
          _recentSearches.clear();
          _showRecentSearches = false;
        });
      }
    } catch (e) {
      debugPrint('Error clearing recent searches: $e');
    }
  }

  Future<void> _loadHotspots() async {
    setState(() => _isLoading = true);
    try {
      final hotspots = await HotspotService.getHotspotsStream().first;
      setState(() {
        _allHotspots = hotspots.where((h) => !(h.isArchived ?? false)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading hotspots: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _performSearch([String? searchTerm]) {
    final actualSearchTerm = searchTerm ?? _searchController.text;
    
    // Cancel any existing timer
    _searchTimer?.cancel();
    
    // Add debouncing for better performance
    _searchTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      
      if (actualSearchTerm.trim().isEmpty && _selectedCategory == 'All Categories') {
        setState(() {
          _filteredHotspots = [];
          _hasSearched = false;
          _showRecentSearches = true;
          _searchSuggestions.clear();
        });
        return;
      }

      // Save to recent searches if it's a manual search
      if (searchTerm == null && actualSearchTerm.trim().isNotEmpty) {
        _saveRecentSearch(actualSearchTerm);
      }

      // Update search controller if using suggestion/recent search
      if (searchTerm != null) {
        _searchController.text = searchTerm;
      }

      setState(() {
        _hasSearched = true;
        _showRecentSearches = false;
        _searchSuggestions.clear();
        _filteredHotspots = _allHotspots.where((hotspot) {
          final matchesSearch = actualSearchTerm.trim().isEmpty ||
              hotspot.name.toLowerCase().contains(actualSearchTerm.toLowerCase()) ||
              hotspot.description.toLowerCase().contains(actualSearchTerm.toLowerCase()) ||
              hotspot.district.toLowerCase().contains(actualSearchTerm.toLowerCase()) ||
              hotspot.municipality.toLowerCase().contains(actualSearchTerm.toLowerCase()) ||
              hotspot.category.toLowerCase().contains(actualSearchTerm.toLowerCase());

          final matchesCategory = _selectedCategory == 'All Categories' ||
              hotspot.category == _selectedCategory;

          return matchesSearch && matchesCategory;
        }).toList();
      });
    });
  }

  void _clearSearch() {
    _searchTimer?.cancel();
    setState(() {
      _searchController.clear();
      _selectedCategory = 'All Categories';
      _filteredHotspots = [];
      _hasSearched = false;
      _showRecentSearches = true;
      _searchSuggestions.clear();
    });
    _searchFocusNode.requestFocus();
  }

  void _onCategoryChanged(String? value) {
    setState(() {
      _selectedCategory = value!;
    });
    _performSearch();
  }

  void _applySuggestion(String suggestion) {
    // Handle different types of suggestions
    if (suggestion.contains('(Category)')) {
      final category = suggestion.replaceAll(' (Category)', '');
      setState(() {
        _selectedCategory = category;
        _searchController.clear();
      });
    } else if (suggestion.contains('(Municipality)') || suggestion.contains('(District)')) {
      final location = suggestion.replaceAll(' (Municipality)', '').replaceAll(' (District)', '');
      _performSearch(location);
    } else {
      _performSearch(suggestion);
    }
  }

  // Build the search bar matching MapScreen's design
  Widget _buildSearchBar() {
    return Container(
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
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: InputDecoration(
                hintText: 'Search Destinations...',
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 16,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => _performSearch(),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            GestureDetector(
              onTap: _clearSearch,
              child: Icon(
                Icons.close,
                color: Colors.grey.shade500,
                size: 20,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    return Stack(
      children: [
        // Animated background
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          color: Colors.black.withOpacity(0.4),
          width: double.infinity,
          height: double.infinity,
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
          ),
        ),
        // Slide up modal from bottom
        Align(
          alignment: Alignment.bottomCenter,
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: mediaQuery.size.width,
                  constraints: BoxConstraints(
                    maxHeight: mediaQuery.size.height * 0.92,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 24,
                        offset: const Offset(0, -8),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Drag handle
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 8),
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        // Search Bar (matching MapScreen design)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          child: _buildSearchBar(),
                        ),
                        // Category filter
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                          child: _buildCategoryDropdown(),
                        ),
                        const SizedBox(height: 4),
                        // Results Section
                        Expanded(
                          child: _buildResultsSection(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Category icon mapping (match MapScreen)
  static const Map<String, IconData> _categoryIcons = {
    'Natural Attraction': Icons.park,
    'Cultural Site': Icons.museum,
    'Adventure Spot': Icons.forest,
    'Restaurant': Icons.restaurant,
    'Accommodation': Icons.hotel,
    'Shopping': Icons.shopping_cart,
    'Entertainment': Icons.theater_comedy,
  };

  Widget _buildCategoryDropdown() {
    // Collect unique categories from _allHotspots
    final Set<String> categories = {'All Categories'};
    for (final h in _allHotspots) {
      final cat = h.category.trim();
      if (cat.isNotEmpty && cat != 'All Categories') {
        categories.add(cat);
      }
    }
    final sorted = categories.toList()..sort((a, b) {
      if (a == 'All Categories') return -1;
      if (b == 'All Categories') return 1;
      return a.compareTo(b);
    });
    return DropdownButton<String>(
      value: _selectedCategory,
      isExpanded: true,
      icon: const Icon(Icons.arrow_drop_down),
      underline: Container(height: 0),
      items: sorted.map((cat) => DropdownMenuItem(
        value: cat,
        child: Row(
          children: [
            if (cat == 'All Categories')
              const Icon(Icons.category, color: Colors.grey, size: 20)
            else if (_categoryIcons[cat] != null)
              Icon(_categoryIcons[cat], color: AppColors.primaryTeal, size: 20)
            else
              const Icon(Icons.label, color: Colors.grey, size: 20),
            const SizedBox(width: 8),
            Text(cat),
          ],
        ),
      )).toList(),
      onChanged: _onCategoryChanged,
    );
  }

  Widget _buildResultsSection() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading hotspots...'),
          ],
        ),
      );
    }

    // Show suggestions when typing
    if (_searchSuggestions.isNotEmpty && !_hasSearched) {
      return _buildSuggestions();
    }

    if (_showRecentSearches && _recentSearches.isNotEmpty) {
      return _buildRecentSearches();
    }

    if (!_hasSearched) {
      // Simple intro state
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.explore,
              size: 80,
              color: AppColors.primaryTeal.withOpacity(0.6),
            ),
            const SizedBox(height: 16),
            Text(
              'Discover Amazing Places',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Search for tourist attractions, restaurants,\nand more in Bukidnon',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_filteredHotspots.isEmpty) {
      return _buildNoResults();
    }

    return _buildSearchResults();
  }

  Widget _buildSuggestions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Suggestions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _searchSuggestions.length,
            itemBuilder: (context, index) {
              final suggestion = _searchSuggestions[index];
              return ListTile(
                leading: Icon(
                  suggestion.contains('(Category)') ? Icons.category :
                  suggestion.contains('(Municipality)') || suggestion.contains('(District)') ? Icons.location_on :
                  Icons.search,
                  color: AppColors.primaryTeal,
                ),
                title: Text(suggestion),
                trailing: const Icon(Icons.north_west, color: Colors.grey),
                onTap: () => _applySuggestion(suggestion),
                contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecentSearches() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              TextButton(
                onPressed: _clearRecentSearches,
                child: Text(
                  'Clear All',
                  style: TextStyle(
                    color: AppColors.primaryTeal,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _recentSearches.length,
            itemBuilder: (context, index) {
              final search = _recentSearches[index];
              return ListTile(
                leading: Icon(Icons.history, color: Colors.grey[500]),
                title: Text(search),
                trailing: Icon(Icons.north_west, color: Colors.grey[400]),
                onTap: () => _performSearch(search),
                contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try different keywords or check the category filter',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _clearSearch,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryTeal,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Clear Search'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    Widget buildHotspotCard(Hotspot hotspot) {
      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
        shadowColor: Colors.black.withOpacity(0.1),
        child: InkWell(
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => HotspotDetailsScreen(hotspot: hotspot),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hotspot Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: hotspot.images.isNotEmpty
                      ? Image.network(
                          hotspot.images.first,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildPlaceholderImage();
                          },
                        )
                      : _buildPlaceholderImage(),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name
                      Text(
                        hotspot.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Category
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTeal.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          hotspot.category,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryTeal,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Description
                      Text(
                        hotspot.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Location
                      Row(
                        children: [
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${hotspot.municipality}, ${hotspot.district}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Arrow Icon
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: AppColors.primaryTeal,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Results Header
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Found ${_filteredHotspots.length} place${_filteredHotspots.length != 1 ? 's' : ''}',
                style: TextStyle(
                  color: AppColors.textDark,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_filteredHotspots.isNotEmpty)
                TextButton(
                  onPressed: _clearSearch,
                  child: const Text('Clear'),
                ),
            ],
          ),
        ),
        // Results List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _filteredHotspots.length,
            itemBuilder: (context, index) {
              final hotspot = _filteredHotspots[index];
              return buildHotspotCard(hotspot);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.image,
        color: Colors.grey[500],
        size: 32,
      ),
    );
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }
}