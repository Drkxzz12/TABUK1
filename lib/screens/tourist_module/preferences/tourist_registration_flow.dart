// ===========================================
// lib/screens/tourist_module/preferences/tourist_registration_flow.dart
// ===========================================
// Multi-step registration flow for new tourist users.

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:capstone_app/utils/colors.dart';
import 'package:capstone_app/utils/constants.dart';
import 'package:capstone_app/screens/tourist_module/main_tourist_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Multi-step registration flow for new tourist users.
class TouristRegistrationFlow extends StatefulWidget {
  const TouristRegistrationFlow({super.key});

  @override
  State<TouristRegistrationFlow> createState() => _TouristRegistrationFlowState();
}

class _TouristRegistrationFlowState extends State<TouristRegistrationFlow> {
  // Core state
  int currentStep = 0;
  late final PageController pageController;
  late final ImagePicker _picker;
  bool _isLoading = false;

  // Form controllers
  late final TextEditingController usernameController;

  // Registration data
  String username = '';
  File? profileImage;
  String? uploadedProfileImageUrl;
  XFile? webProfileImage;

  // Preference data
  String selectedEventRecommendation = '';
  String selectedLesserKnown = '';
  String selectedTravelTiming = '';
  String selectedCompanion = '';
  String selectedVibe = '';
  List<String> selectedDestinationTypes = [];

  // Constants - defined once for better performance
  static const List<String> _eventRecommendationOptions = [
    AppConstants.yes,
    'Only During specific dates',
    AppConstants.no,
  ];

  static const List<String> _lesserKnownOptions = [
    'Yes, I love discovering hidden gems',
    'Only if they are easy to access',
    'No, I prefer popular and established places',
  ];

  static const List<String> _travelTimingOptions = [
    'Weekends',
    'Holidays',
    'Festival Seasons',
    'Off-Season (Less crowded)',
  ];

  static const List<String> _companionOptions = [
    'Solo',
    'With Friends',
    'With Family',
    'With Partner',
  ];

  static const List<String> _vibeOptions = [
    'Peaceful & Relaxing',
    'Thrilling & Adventurous',
    'Educational & Cultural',
    'Photo-Worthy / Instagrammable',
  ];

  static const List<String> _destinationTypes = [
    'Waterfalls',
    'Mountain Ranges',
    'Scenic Lakes',
    'Caves',
    'Nature Parks and Forests',
    'Farms and Agricultural Tourism Sites',
    'Adventure Parks',
    'Historical or Cultural Sites',
  ];

  // Constants for API and validation
  static const String _imgbbApiKey = 'aae8c93b12878911b39dd9abc8c73376';
  static const int _minUsernameLength = 3;
  static const int _maxImageSize = 512;
  static const int _imageQuality = 85;
  static const int _totalSteps = 7;

  @override
  void initState() {
    super.initState();
    pageController = PageController();
    _picker = ImagePicker();
    usernameController = TextEditingController();
  }

  @override
  void dispose() {
    usernameController.dispose();
    pageController.dispose();
    super.dispose();
  }

  // Image handling methods
  Future<void> _pickImageFromGallery() async {
    await _pickImage(ImageSource.gallery);
  }

  Future<void> _pickImageFromCamera() async {
    await _pickImage(ImageSource.camera);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: _maxImageSize.toDouble(),
        maxHeight: _maxImageSize.toDouble(),
        imageQuality: _imageQuality,
      );
      if (image != null && mounted) {
        setState(() {
          if (kIsWeb) {
            webProfileImage = image;
            profileImage = null;
          } else {
            profileImage = File(image.path);
            webProfileImage = null;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error ${source == ImageSource.gallery ? 'selecting image from gallery' : 'taking photo'}');
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) => _buildImageSourceSheet(),
    );
  }

  Widget _buildImageSourceSheet() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Select Profile Photo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildImageSourceOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                ),
                if (!kIsWeb)
                  _buildImageSourceOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onTap: () {
                      Navigator.pop(context);
                      _pickImageFromCamera();
                    },
                  ),
                if ((kIsWeb && webProfileImage != null) || (!kIsWeb && profileImage != null))
                  _buildImageSourceOption(
                    icon: Icons.delete,
                    label: 'Remove',
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        if (kIsWeb) {
                          webProfileImage = null;
                        } else {
                          profileImage = null;
                        }
                      });
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 30, color: AppColors.primaryOrange),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // Notification methods
  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Validation
  bool _validateCurrentStep() {
    switch (currentStep) {
      case 0: // Profile setup
        final trimmedUsername = usernameController.text.trim();
        if (trimmedUsername.isEmpty) {
          _showErrorSnackBar('Please enter a username');
          return false;
        }
        if (trimmedUsername.length < _minUsernameLength) {
          _showErrorSnackBar('Username must be at least $_minUsernameLength characters long');
          return false;
        }
        if ((profileImage == null && webProfileImage == null) && (uploadedProfileImageUrl == null || uploadedProfileImageUrl!.isEmpty)) {
          _showErrorSnackBar('Please select a profile image');
          return false;
        }
        return true;
      case 1: // Event recommendations
        if (selectedEventRecommendation.isEmpty) {
          _showErrorSnackBar('Please select an option for event recommendations');
          return false;
        }
        return true;
      case 2: // Lesser-known spots
        if (selectedLesserKnown.isEmpty) {
          _showErrorSnackBar('Please select your preference for lesser-known spots');
          return false;
        }
        return true;
      case 3: // Travel timing
        if (selectedTravelTiming.isEmpty) {
          _showErrorSnackBar('Please select when you usually travel');
          return false;
        }
        return true;
      case 4: // Travel companions
        if (selectedCompanion.isEmpty) {
          _showErrorSnackBar('Please select who you usually travel with');
          return false;
        }
        return true;
      case 5: // Vibe
        if (selectedVibe.isEmpty) {
          _showErrorSnackBar('Please select the vibe you\'re looking for');
          return false;
        }
        return true;
      case 6: // Destination types
        if (selectedDestinationTypes.isEmpty) {
          _showErrorSnackBar('Please select at least one destination type');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  // Navigation
  void nextStep() {
    if (_isLoading || !_validateCurrentStep()) return;

    if (currentStep < _totalSteps - 1) {
      setState(() {
        currentStep++;
      });
      pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeRegistration();
    }
  }

  void previousStep() {
    if (_isLoading || currentStep <= 0) return;

    setState(() {
      currentStep--;
    });
    pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // Image upload
  Future<String?> _uploadImageToImgbb(dynamic imageFileOrXFile) async {
    try {
      final url = Uri.parse('https://api.imgbb.com/1/upload?key=$_imgbbApiKey');
      List<int> bytes;
      if (kIsWeb && imageFileOrXFile is XFile) {
        bytes = await imageFileOrXFile.readAsBytes();
      } else if (imageFileOrXFile is File) {
        bytes = await imageFileOrXFile.readAsBytes();
      } else {
        throw Exception('Invalid image type');
      }
      final base64Image = base64Encode(bytes);
      final response = await http.post(url, body: {'image': base64Image});
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data']['url'] as String?;
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to upload image.');
      }
    }
    return null;
  }

  // Firestore operations
  /// Saves the registration data to Firestore under the user's UID.
  Future<void> _saveRegistrationToFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final usernameValue = usernameController.text.trim();
      final imageValue = uploadedProfileImageUrl ?? '';

      // Save to Users collection for profile screen
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .set({
        'name': usernameValue, // always lowercase
        'profile_photo': imageValue,
        'email': user.email ?? '',
        'role': 'Tourist',
        'user_id': user.uid,
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Save to tourist_preferences for recommender system
      await FirebaseFirestore.instance
          .collection('tourist_preferences')
          .doc(user.uid)
          .set({
        'isRegistered': true,
        'username': usernameValue, // always lowercase
        'profileImageUrl': imageValue,
        'eventRecommendation': selectedEventRecommendation,
        'lesserKnown': selectedLesserKnown,
        'travelTiming': selectedTravelTiming,
        'companion': selectedCompanion,
        'vibe': selectedVibe,
        'destinationTypes': selectedDestinationTypes,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to save registration: $e');
      }
      rethrow;
    }
  }

  // Registration completion
  Future<void> _completeRegistration() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload image if exists and not already uploaded
      if ((profileImage != null || webProfileImage != null) && (uploadedProfileImageUrl == null || uploadedProfileImageUrl!.isEmpty)) {
        final imageToUpload = kIsWeb ? webProfileImage : profileImage;
        uploadedProfileImageUrl = await _uploadImageToImgbb(imageToUpload);
        if (uploadedProfileImageUrl == null || uploadedProfileImageUrl!.isEmpty) {
          _showErrorSnackBar('Failed to upload profile image. Please try again.');
          setState(() { _isLoading = false; });
          return;
        }
      }
      // Prevent registration if no image URL
      if (uploadedProfileImageUrl == null || uploadedProfileImageUrl!.isEmpty) {
        _showErrorSnackBar('Please select and upload a profile image.');
        setState(() { _isLoading = false; });
        return;
      }
      await _saveRegistrationToFirestore();
      _saveRegistrationData();

      if (mounted) {
        _showSuccessSnackBar('Registration completed successfully!');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainTouristScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Registration failed. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _saveRegistrationData() {
    // Debug logging - can be removed in production
    debugPrint('Registration Data:');
    debugPrint('Username: ${usernameController.text.trim()}');
    debugPrint('Profile Image URL: ${uploadedProfileImageUrl ?? (profileImage?.path ?? 'None')}');
    debugPrint('Event Recommendations: $selectedEventRecommendation');
    debugPrint('Lesser Known Spots: $selectedLesserKnown');
    debugPrint('Travel Timing: $selectedTravelTiming');
    debugPrint('Travel Companion: $selectedCompanion');
    debugPrint('Vibe: $selectedVibe');
    debugPrint('Destination Types: $selectedDestinationTypes');
  }

  // Step builders
  Widget _buildProfileSetupStep() {
    return _buildStepContainer(
      title: 'Set up your Profile',
      subtitle: 'Create your tourist profile to get personalized recommendations',
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          _buildProfileImageSection(),
          const SizedBox(height: 24),
          _buildUsernameInput(),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _buildContinueButton(),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfileImageSection() {
    ImageProvider? imageProvider;
    if (kIsWeb && webProfileImage != null) {
      imageProvider = NetworkImage(webProfileImage!.path);
    } else if (!kIsWeb && profileImage != null) {
      imageProvider = FileImage(profileImage!);
    } else if (uploadedProfileImageUrl != null && uploadedProfileImageUrl!.isNotEmpty) {
      imageProvider = NetworkImage(uploadedProfileImageUrl!);
    }
    return Center(
      child: GestureDetector(
        onTap: _showImageSourceDialog,
        child: Stack(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: Colors.grey[200],
              backgroundImage: imageProvider,
              child: imageProvider == null
                  ? Icon(Icons.person, size: 50, color: Colors.grey[400])
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primaryOrange,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsernameInput() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: TextField(
        controller: usernameController,
        decoration: InputDecoration(
          hintText: 'Enter your Name',
          labelText: 'Name',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primaryOrange, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          prefixIcon: const Icon(Icons.person_outline),
        ),
        style: const TextStyle(fontSize: 16),
        textInputAction: TextInputAction.next,
        onSubmitted: (_) => nextStep(),
      ),
    );
  }

  Widget _buildEventRecommendationStep() {
    return _buildSelectionStep(
      title: 'Event-Based Recommendations',
      subtitle: 'Do you want to see recommended spots based on upcoming events or festivals in Bukidnon?',
      options: _eventRecommendationOptions,
      selectedValue: selectedEventRecommendation,
      onSelectionChanged: (value) => setState(() => selectedEventRecommendation = value),
    );
  }

  Widget _buildLesserKnownStep() {
    return _buildSelectionStep(
      title: 'Hidden Gems Discovery',
      subtitle: 'Are you interested in visiting nearby lesser-known spots?',
      options: _lesserKnownOptions,
      selectedValue: selectedLesserKnown,
      onSelectionChanged: (value) => setState(() => selectedLesserKnown = value),
    );
  }

  Widget _buildTravelTimingStep() {
    return _buildSelectionStep(
      title: 'Travel Timing Preference',
      subtitle: 'When do you usually like to travel?',
      options: _travelTimingOptions,
      selectedValue: selectedTravelTiming,
      onSelectionChanged: (value) => setState(() => selectedTravelTiming = value),
    );
  }

  Widget _buildCompanionStep() {
    return _buildSelectionStep(
      title: 'Travel Companions',
      subtitle: 'Who do you usually travel with?',
      options: _companionOptions,
      selectedValue: selectedCompanion,
      onSelectionChanged: (value) => setState(() => selectedCompanion = value),
    );
  }

  Widget _buildVibeStep() {
    return _buildSelectionStep(
      title: 'Travel Vibe',
      subtitle: 'What kind of vibe are you looking for during your trip?',
      options: _vibeOptions,
      selectedValue: selectedVibe,
      onSelectionChanged: (value) => setState(() => selectedVibe = value),
    );
  }

 Widget _buildDestinationTypesStep() {
  return _buildStepContainer(
    title: 'Destination Preferences',
    subtitle: 'What types of destinations do you want to visit in Bukidnon? (Select all that apply)',
    child: Column(
      children: [
        const SizedBox(height: 20),
        ..._destinationTypes.map((type) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildOptionCard(
            option: type,
            isSelected: selectedDestinationTypes.contains(type),
            onTap: () {
              setState(() {
                if (selectedDestinationTypes.contains(type)) {
                  selectedDestinationTypes.remove(type);
                } else {
                  selectedDestinationTypes.add(type);
                }
              });
            },
            isMultiSelect: true,
          ),
        )),
        const SizedBox(height: 16),
        if (selectedDestinationTypes.isNotEmpty) _buildSelectionSummary(),
        const SizedBox(height: 32),
        // Remove extra Padding here, just call the navigation buttons directly
        _buildNavigationButtons(isLastStep: true),
        const SizedBox(height: 24), // Add bottom spacing
      ],
    ),
  );
}

  Widget _buildSelectionSummary() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primaryOrange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primaryOrange.withOpacity(0.3)),
      ),
      child: Text(
        '${selectedDestinationTypes.length} destination type${selectedDestinationTypes.length > 1 ? 's' : ''} selected',
        style: const TextStyle(
          color: AppColors.primaryOrange,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // Reusable selection step builder
  Widget _buildSelectionStep({
    required String title,
    required String subtitle,
    required List<String> options,
    required String selectedValue,
    required ValueChanged<String> onSelectionChanged,
  }) {
    return _buildStepContainer(
      title: title,
      subtitle: subtitle,
      child: Column(
        children: [
          const SizedBox(height: 20),
          ...options.map((option) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildOptionCard(
              option: option,
              isSelected: selectedValue == option,
              onTap: () => onSelectionChanged(option),
            ),
          )),
          const SizedBox(height: 32),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  Widget _buildOptionCard({
    required String option,
    required bool isSelected,
    required VoidCallback onTap,
    bool isMultiSelect = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryOrange.withOpacity(0.15) : AppColors.white,
          border: Border.all(
            color: isSelected ? AppColors.primaryOrange : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primaryOrange.withOpacity(0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            _buildSelectionIndicator(isSelected, isMultiSelect),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 16,
                  color: isSelected ? AppColors.primaryOrange : AppColors.textDark,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionIndicator(bool isSelected, bool isMultiSelect) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primaryOrange : Colors.white,
        border: Border.all(
          color: isSelected ? AppColors.primaryOrange : Colors.grey.withOpacity(0.5),
          width: 2,
        ),
        borderRadius: BorderRadius.circular(isMultiSelect ? 6 : 12),
      ),
      child: isSelected
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : null,
    );
  }

    Widget _buildNavigationButtons({bool isLastStep = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Row(
        children: [
          if (currentStep > 0) ...[
            Expanded(
              flex: 1,
              child: _buildBackButton(),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            flex: currentStep > 0 ? 2 : 1, // Give more space to main action button when back button is present
            child: isLastStep ? _buildCompleteButton() : _buildContinueButton(),
          ),
        ],
      ),
    );
  }
  Widget _buildStepContainer({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      height: MediaQuery.of(context).size.height,
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.backgroundGradient),
      child: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                         MediaQuery.of(context).padding.top -
                         MediaQuery.of(context).padding.bottom,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  _buildProgressSection(),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStepTitle(title),
                          if (subtitle.isNotEmpty) _buildStepSubtitle(subtitle),
                          const SizedBox(height: 20),
                          child,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Text(
                'Step ${currentStep + 1} of $_totalSteps',
                style: const TextStyle(
                  color: AppColors.textLight,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                '${((currentStep + 1) / _totalSteps * 100).round()}%',
                style: const TextStyle(
                  color: AppColors.primaryOrange,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (currentStep + 1) / _totalSteps,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.primaryOrange,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildStepTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
        fontFamily: 'Roboto',
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildStepSubtitle(String subtitle) {
    return Column(
      children: [
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textLight,
            fontSize: 14,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          _buildProfileSetupStep(),
          _buildEventRecommendationStep(),
          _buildLesserKnownStep(),
          _buildTravelTimingStep(),
          _buildCompanionStep(),
          _buildVibeStep(),
          _buildDestinationTypesStep(),
        ],
      ),
    );
  }

  // Button builders
   Widget _buildContinueButton() {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryOrange,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        onPressed: _isLoading ? null : nextStep,
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Continue',
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }


   Widget _buildBackButton() {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.primaryOrange),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: _isLoading ? null : previousStep,
        child: const Text(
          'Back',
          style: TextStyle(
            color: AppColors.primaryOrange,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

Widget _buildCompleteButton() {
    return SizedBox(
      height: 48, // Changed from 45 to match other buttons
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        onPressed: _isLoading ? null : nextStep,
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Submit',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }}

/// Checks if the current user is already registered (has a tourist profile with isRegistered == true, and has a username and profile image).
Future<bool> isTouristUserRegistered() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  // Check tourist_preferences for isRegistered
  final doc = await FirebaseFirestore.instance
      .collection('tourist_preferences')
      .doc(user.uid)
      .get();
  if (!doc.exists) return false;
  final data = doc.data();
  final isRegistered = data != null && data['isRegistered'] == true;
  final username = data != null ? (data['username'] ?? '').toString().trim() : '';
  final profileImageUrl = data != null ? (data['profileImageUrl'] ?? '').toString().trim() : '';

  // Optionally, also check Users collection for Username and profile_photo
  final userDoc = await FirebaseFirestore.instance
      .collection('Users')
      .doc(user.uid)
      .get();
  final userData = userDoc.data();
  final userNameField = userData != null ? (userData['Username'] ?? '').toString().trim() : '';
  // Accept either tourist_preferences or Users for username
  final hasUsername = username.isNotEmpty || userNameField.isNotEmpty;
  final hasProfileImage = profileImageUrl.isNotEmpty;

  return isRegistered && hasUsername && hasProfileImage;
}