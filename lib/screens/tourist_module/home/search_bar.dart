import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:capstone_app/models/hotspots_model.dart';
import 'package:capstone_app/services/recommender_system.dart';
import 'package:capstone_app/screens/tourist_module/hotspot_details_screen.dart';
import '../../../utils/colors.dart';

/// Enhanced search bar widget with improved UI and functionality
class SearchBarWidget extends StatefulWidget {
  const SearchBarWidget({super.key});

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Hotspot> _suggestions = [];
  bool _isLoading = false;
  bool _isFocused = false;
  Timer? _debounceTimer;
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _focusNode.addListener(_onFocusChange);
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

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  void _onFocusChange() {
    setState(() {
      _isFocused = _focusNode.hasFocus;
    });
    
    if (_isFocused) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _onChanged(String query) {
    _debounceTimer?.cancel();
    
    if (query.isEmpty) {
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
      return;
    }

    if (!_isLoading) {
      setState(() => _isLoading = true);
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        final results = await TouristRecommendationService.searchHotspots(
          query, 
          limit: 8
        );
        
        if (mounted && _controller.text == query) {
          setState(() {
            _suggestions = results;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _suggestions = [];
            _isLoading = false;
          });
        }
      }
    });
  }

  void _onSuggestionTap(Hotspot hotspot) {
    _focusNode.unfocus();
    _controller.clear();
    setState(() {
      _suggestions = [];
      _isLoading = false;
    });
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HotspotDetailsScreen(hotspot: hotspot),
      ),
    );
  }

  void _clearSearch() {
    _controller.clear();
    setState(() {
      _suggestions = [];
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Enhanced Search Input
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(_isFocused ? 20 : 16),
            boxShadow: [
              BoxShadow(
                color: _isFocused 
                    ? AppColors.primaryOrange.withOpacity(0.3)
                    : Colors.black.withOpacity(0.1),
                blurRadius: _isFocused ? 15 : 10,
                offset: const Offset(0, 2),
                spreadRadius: _isFocused ? 1 : 0,
              ),
            ],
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            onChanged: _onChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: _isFocused 
                  ? 'Search destinations, activities, restaurants...'
                  : 'Search for places, activities...',
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
              prefixIcon: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                child: Icon(
                  Icons.search,
                  color: _isFocused ? AppColors.primaryOrange : Colors.grey,
                  size: 24,
                ),
              ),
              suffixIcon: _controller.text.isNotEmpty
                  ? AnimatedScale(
                      scale: _controller.text.isNotEmpty ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: IconButton(
                        icon: Icon(
                          Icons.clear,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                        onPressed: _clearSearch,
                        splashRadius: 20,
                      ),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_isFocused ? 20 : 16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(_isFocused ? 20 : 16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide(
                  color: AppColors.primaryOrange.withOpacity(0.3),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
          ),
        ),
        
        // Enhanced Suggestions Dropdown
        if (_controller.text.isNotEmpty && (_isLoading || _suggestions.isNotEmpty))
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: _buildSuggestionsContent(),
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildSuggestionsContent() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 24,
              width: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryOrange),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Searching...',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_suggestions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 32,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              'No results found',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Try searching with different keywords',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search Results Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primaryOrange.withOpacity(0.05),
            border: Border(
              bottom: BorderSide(
                color: Colors.grey[200]!,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search,
                size: 16,
                color: AppColors.primaryOrange,
              ),
              const SizedBox(width: 8),
              Text(
                '${_suggestions.length} result${_suggestions.length == 1 ? '' : 's'} found',
                style: TextStyle(
                  color: AppColors.primaryOrange,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        
        // Suggestions List
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 300),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const BouncingScrollPhysics(),
            itemCount: _suggestions.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              color: Colors.grey[200],
            ),
            itemBuilder: (context, index) {
              return _buildSuggestionItem(_suggestions[index], index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSuggestionItem(Hotspot hotspot, int index) {
    return InkWell(
      onTap: () => _onSuggestionTap(hotspot),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Image with loading state
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: hotspot.images.isNotEmpty
                    ? Image.network(
                        hotspot.images.first,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            color: Colors.grey[200],
                            child: Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.primaryOrange,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey[200],
                          child: Icon(
                            Icons.image,
                            size: 28,
                            color: Colors.grey[400],
                          ),
                        ),
                      )
                    : Icon(
                        Icons.location_on,
                        size: 28,
                        color: Colors.grey[400],
                      ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hotspot.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
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
                          hotspot.location,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
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
            
            // Arrow icon
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}
