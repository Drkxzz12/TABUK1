import 'package:flutter/material.dart';
// ===========================================
// lib/utils/constants.dart
// ===========================================
// Centralized app-wide string constants for UI and logic.

import 'package:google_maps_flutter/google_maps_flutter.dart';

class AppConstants {
  // Sign Up Screen Roles
  static const String roleBusinessOwner = 'Business Owner';
  static const String roleTourist = 'Tourist';
  static const String roleAdministrator = 'Administrator';
  static const List<String> signUpRoles = [
    roleBusinessOwner,
    roleTourist,
    roleAdministrator,
  ];

  // Sign Up Screen UI constants
  static const double signUpLabelFontSize = 14.0;
  static const double signUpFieldErrorFontSize = 12.0;
  static const double signUpFieldErrorLeftPadding = 12.0;
  static const double signUpFieldErrorTopPadding = 2.0;
  static const double signUpFormLabelLeftPadding = 4.0;
  static const double signUpFormLabelBottomPadding = 8.0;
  static const double signUpFormPromptSpacing = 4.0;
  static const int signUpPromptFontWeight = 600;
  static const double signUpPromptFontSize = 12.0;
  static const int signUpPromptColorARGB = 0xFF4297FF; // Color.fromARGB(255, 66, 151, 255)
  static const Color signUpPromptColor = Color(signUpPromptColorARGB);
  // App General
  static const String appName = 'TABUK';

  // admin constants
  static const String profile = 'Profile';
  static const String profileScreenPlaceholder = 'Profile Screen Placeholder';
  static const String signOut = 'Sign Out';

  // Authentication
  static const String signInWithGoogle = 'Sign up with Google';
  static const String loginWithEmail = 'Login with email';
  static const String email = 'Email';
  static const String password = 'Password';
  static const String dontHaveAccount = "Haven't have an account? ";
  static const String signUp = 'Create here';
  static const String confirmPassword = 'Confirm Password';
  static const String role = 'Role:';
  static const String signUpWithEmail = 'Sign up with email';
  static const String alreadyHaveAccount = 'Already have an account? ';
  static const String signIn = 'Sign In';
  static const String emailNotVerifiedTitle = 'Email Not Verified';
  static const String emailNotVerifiedContent =
      'Your email address is not verified. Please check your inbox for a verification email. If you did not receive it, you can resend the verification email.';
  static const String cancelButton = 'Cancel';
  static const String resendEmailButton = 'Resend Email';
  static const String verificationEmailResent =
      'Verification email resent. Please check your inbox.';
  static const String forgotPasswordLabel = 'Forgot Password?';

  // Events
  static const String eventCalendarTitle = 'Event Calendar';
  static const String thisMonth = 'This Month';
  static const String nextMonth = 'Next Month';
  static const String noEvents = 'No events';
  static const String events = 'Events';

  // Hotspots - Categories
  static const String naturalAttraction = 'Natural Attraction';
  static const String culturalSite = 'Cultural Site';
  static const String adventureSpot = 'Adventure Spot';
  static const String restaurant = 'Restaurant';
  static const String accommodation = 'Accommodation';
  static const String shopping = 'Shopping';
  static const String entertainment = 'Entertainment';

  static const List<String> hotspotCategories = [
    naturalAttraction,
    culturalSite,
    adventureSpot,
    restaurant,
    accommodation,
    shopping,
    entertainment,
  ];

  // Hotspots - Transportation
  static const String jeepney = 'Jeepney';
  static const String tricycle = 'Tricycle';
  static const String bus = 'Bus';
  static const String privateCar = 'Private Car';
  static const String motorcycle = 'Motorcycle';
  static const String walking = 'Walking';

  static const List<String> transportationOptions = [
    jeepney,
    tricycle,
    bus,
    privateCar,
    motorcycle,
    walking,
  ];

  // Hotspots - UI Text
  static const String hotspots = 'Hotspots';
  static const String hotspotDetails = 'Hotspot Details';
  static const String viewOnMap = 'View on Map';
  static const String getDirections = 'Get Directions';
  static const String shareHotspot = 'Share Hotspot';
  static const String addToFavorites = 'Add to Favorites';
  static const String removeFromFavorites = 'Remove from Favorites';
  static const String writeReview = 'Write Review';
  static const String seeAllReviews = 'See All Reviews';
  static const String operatingHours = 'Operating Hours';
  static const String entranceFee = 'Entrance Fee';
  static const String transportation = 'Transportation';
  static const String safetyTips = 'Safety Tips';
  static const String suggestions = 'Suggestions';
  static const String facilities = 'Facilities';
  static const String contactInfo = 'Contact Information';
  static const String localGuide = 'Local Guide';
  static const String restroom = 'Restroom Available';
  static const String foodAccess = 'Food Access';
  static const String noImageAvailable = 'No Image Available';
  static const String loadingHotspots = 'Loading hotspots...';
  static const String noHotspotsFound = 'No hotspots found';
  static const String errorLoadingHotspots = 'Error loading hotspots';
  static const String searchHotspots = 'Search Destinations...';
  static const String filterBy = 'Filter by';
  static const String sortBy = 'Sort by';
  static const String allCategories = 'All Categories';
  static const String nearbyHotspots = 'Nearby Hotspots';
  static const String popularHotspots = 'Popular Hotspots';
  static const String recentlyAdded = 'Recently Added';
  static const String featured = 'Featured';
  static const String free = 'Free';
  static const String paid = 'Paid';

  // Hotspots - Messages
  static const String hotspotAddedToFavorites = 'Hotspot added to favorites';
  static const String hotspotRemovedFromFavorites =
      'Hotspot removed from favorites';
  static const String failedToLoadHotspot = 'Failed to load hotspot details';
  static const String failedToAddFavorite = 'Failed to add to favorites';
  static const String failedToRemoveFavorite =
      'Failed to remove from favorites';

  // Common UI
  static const String retry = 'Retry';
  static const String refresh = 'Refresh';
  static const String loading = 'Loading...';
  static const String error = 'Error';
  static const String success = 'Success';
  static const String warning = 'Warning';
  static const String info = 'Info';
  static const String ok = 'OK';
  static const String yes = 'Yes';
  static const String no = 'No';
  static const String save = 'Save';
  static const String edit = 'Edit';
  static const String delete = 'Delete';
  static const String search = 'Search';
  static const String filter = 'Filter';
  static const String sort = 'Sort';
  static const String share = 'Share';
  static const String close = 'Close';

  // Home Recommendations Section
  static const String recommendedForYou = 'Recommended for you';
  static const String seeAll = 'See All';
  static const String allRecommendations = 'All Recommendations';
  static const double defaultPadding = 16.0;
  static const double cardImageHeight = 110.0;
  static const double cardWidth = 160.0;
  static const double cardBorderRadius = 16.0;
  static const double cardContentPadding = 12.0;
  static const double cardListHeight = 220.0;
  static const double cardListSpacing = 12.0;
  static const double cardTitleFontSize = 16.0;
  static const double cardSubtitleFontSize = 13.0;
  static const double cardIconSize = 40.0;

  // Button constants
  static const double buttonHeight = 45;
  static const double buttonBorderRadius = 8;
  static const double buttonBorderWidth = 1.5;
  static const double buttonFontSize = 16;

  // TextField constants
  static const double textFieldBorderRadius = 8;
  static const double textFieldFontSize = 16;
  static const double textFieldHorizontalPadding = 12;
  static const double textFieldVerticalPadding = 12;

  // Social login button constants
  static const double socialIconSize = 20;
  static const double socialIconSpacing = 12;

  // SnackBar constants

  // Logo constants
  static const double logoSize = 250;
  static const double signUpLogoSize = 150;
  static const double signUpLogoBorderRadius = 16;
  static const double signUpLogoIconSize = 40;
  static const double signUpLogoTextFontSize = 14;
  // Removed duplicate signUpFieldErrorFontSize, signUpFieldErrorLeftPadding, signUpFieldErrorTopPadding
  static const double signUpFormTopSpacing = 50;
  static const double signUpFormSectionSpacing = 18;
  static const double signUpFormButtonSpacing = 32;

  // Google button constants
  static const double googleButtonHeight = 50;
  static const double googleIconSize = 20;
  static const double googleButtonHorizontalPadding = 16;

  // App-wide constants
  static const String rootRoute = '/';
  static const String splashRoute = '/splash';

  // Connectivity messages and settings
  static const String connectivityChecking = 'Checking connection...';
  static const String connectivityConnected = 'Connected to internet';
  static const String connectivityNoInternet = 'No internet connection';
  static const String connectivityNoNetwork = 'No network connection';
  static const String connectivityMobileNoInternet = 'Mobile data enabled but no internet access';
  static const String connectivityWifiNoInternet = 'Connected to WiFi but no internet access';
  static const String connectivityNetworkNoInternet = 'Connected to network but no internet access';
  static const String connectivityError = 'Connection error';
  static const int connectivityTestAttempts = 2;
  static const int connectivityDnsTimeoutSeconds = 8;
  static const int connectivityRetryDelaySeconds = 2;
  static const int connectivityHttpTimeoutSeconds = 10;
  static const String connectivityHttpTestUrl = 'https://www.google.com';

  // Auth error messages and settings
  static const String authActionUrl = 'https://tabuk-ce16e.firebaseapp.com/__/auth/action';
  static const String authInvalidEmailLink = 'Invalid email link';
  static const String authWeakPassword = 'The password provided is too weak.';
  static const String authEmailAlreadyInUse = 'An account already exists for this email address.';
  static const String authInvalidEmail = 'The email address is not valid.';
  static const String authUserDisabled = 'This user account has been disabled.';
  static const String authUserNotFound = 'No user found for this email address.';
  static const String authWrongPassword = 'Wrong password provided.';
  static const String authInvalidCredential = 'The provided credentials are invalid.';
  static const String authAccountExistsWithDifferentCredential = 'An account already exists with a different sign-in method.';
  static const String authCredentialAlreadyInUse = 'This credential is already associated with a different user account.';
  static const String authOperationNotAllowed = 'This sign-in method is not enabled for your Firebase project.';
  static const String authTooManyRequests = 'Too many requests. Please try again in 60 seconds.';
  static const String authNetworkRequestFailed = 'Network error. Please check your internet connection.';
  static const String authRequiresRecentLogin = 'This operation requires recent authentication. Please sign in again.';
  static const String authPopupClosedByUser = 'Sign-in popup was closed before completing the sign-in process.';
  static const String authPopupBlocked = 'Sign-in popup was blocked by the browser. Please allow popups and try again.';
  static const String authDefaultError = 'An authentication error occurred.';
  static const String authGuestRole = 'Guest';
  static String authUnexpectedError(String e) => 'An unexpected error occurred: $e';
  static String authFailedToSendEmailLink(String e) => 'Failed to send email link: $e';
  static String authFailedToSignInWithEmailLink(String e) => 'Failed to sign in with email link: $e';
  static String authFailedToSendPasswordReset(String e) => 'Failed to send password reset email: $e';
  static String authFailedToSignOut(String e) => 'Failed to sign out: $e';
  static String authFailedToDeleteAccount(String e) => 'Failed to delete account: $e';
  static String authFailedToSendVerification(String e) => 'Failed to send verification email: $e';
  static String authFailedToLinkCredential(String e) => 'Failed to link credential: $e';
  static String authFailedToLinkEmailLink(String e) => 'Failed to link email link credential: $e';
  static String authFailedToReauthenticate(String e) => 'Failed to re-authenticate: $e';
  static String authFailedToReauthenticateWithEmailLink(String e) => 'Failed to re-authenticate with email link: $e';
  static String authGoogleSignInFailed(String e) => 'Google sign-in failed: $e';
  static const String authRedirectWebOnly = 'Redirect method is only available for web platforms';
  static String authGoogleSignInRedirectFailed(String e) => 'Google sign-in with redirect failed: $e';

  // Firestore collection names
  static const String hotspotsCollection = 'hotspots';
  static const String tripPlanningCollection = 'trip_planning';
  static const String touristProfilesCollection = 'tourist_profiles';

  // Error messages for services
  static const String errorAddingHotspot = 'Error adding hotspot';
  static const String errorUpdatingHotspot = 'Error updating hotspot';
  static const String errorDeletingHotspot = 'Error deleting hotspot';
  static const String errorSavingTrip = 'Error saving trip';
  static const String errorLoadingTrips = 'Error loading trips';
  static const String errorDeletingTrip = 'Error deleting trip';
  static const String errorGettingRecommendations = 'Error getting recommendations';
  static const String errorLoadingTouristPreferences = 'Error loading tourist preferences';

  // Add missing authentication and validation constants
  static const String emailRequired = 'Email is required';
  static const String emailRequiredError = 'Email is required';
  static const String emailRegexPattern = r'^[\w\.-]+@([\w\-]+\.)+[A-Za-z]{2,}$';
  static const String emailRegex = r'^[\w\.-]+@([\w\-]+\.)+[A-Za-z]{2,}$';
  static const String invalidEmailMessage = 'Invalid email address';
  static const String invalidEmailError = 'Invalid email address';
  static const String passwordRequired = 'Password is required';
  static const String passwordRequiredError = 'Password is required';
  static const int minPasswordLength = 6;
  static const String passwordTooShortMessage = 'Password is too short';
  static const String passwordLengthError = 'Password is too short';
  static const String confirmPasswordRequiredError = 'Confirm password is required';
  static const String passwordsDoNotMatchError = 'Passwords do not match';
  static const String noInternetMessage = 'No internet connection';
  static const String noInternetConnectionError = 'No internet connection';
  static const String selectRoleError = 'Please select a role';
  static const String accountCreationSuccess = 'Account created successfully!';
  static const String creatingAccount = 'Creating account...';
  static const String verificationEmailResentShort = 'Verification email resent.';
  static const String errorUserNotLoggedIn = 'User not logged in.';
  static const String errorSaveRegistration = 'Failed to save registration.';
  static const String forgotPassword = 'Forgot Password?';
  static const String notifications = 'Notifications';
  static const String logoAsset = 'assets/images/TABUK-new-logo.png';
  static const String searchHint = 'Search...';
  static const String clearSearch = 'Clear';
  static const String searchButton = 'Search';
  static const String searchFiltersTitle = 'Filters';
  static const String searchDistrictsTitle = 'Districts';
  static const String searchMunicipalitiesTitle = 'Municipalities';
  static const String searchCategoriesTitle = 'Categories';
  static const String searchResultsTitle = 'Results';
  static const String searchNoResults = 'No results found.';
  static const String homeTitle = 'Home';
  static const String homeWelcome = 'Welcome!';
  static const String homeNoRecommendations = 'No recommendations.';
  static const String homeForYou = 'For You';
  static const String homeTrending = 'Trending';
  static const String homeNearby = 'Nearby';
  static const String homeSeasonal = 'Seasonal';
  static const String seasonChristmas = 'Christmas';
  static const String seasonSummer = 'Summer';
  static const String seasonFestival = 'Festival';
  static const String profileTitle = 'Profile';
  static const String profilePlaceholder = 'No profile info.';
  static const String profileSignOutButtonColor = 'Sign Out';
  static const String touristPreferencesCollection = 'tourist_preferences';
  // Add missing UI constants (sizes, spacings, etc.)
  static const double homeWelcomeFontSize = 24.0;
  static const double googleButtonHeightLarge = 48.0;
  static const double buttonBorderRadiusLarge = 12.0;
  static const double socialIconSpacingLarge = 12.0;
  static const double buttonFontSizeLarge = 16.0;
  static const double signUpFormHorizontalPadding = 24.0;
  static const int snackBarDurationSeconds = 3;
  // Home screen limits
  static const int homeForYouLimit = 5;
  static const int homeTrendingLimit = 5;
  static const int homeNearbyLimit = 5;
  static const int homeSeasonalLimit = 5;
  // Home screen spacings and sizes
  static const double homeTopSpacing = 24.0;
  static const double homeHorizontalPadding = 16.0;
  static const double homeSectionSpacing = 24.0;
  static const double homeCarouselSpacing = 16.0;
  static const double homeBottomSpacing = 24.0;
  static const double homeCarouselBarWidth = 32.0;
  static const double homeCarouselBarHeight = 4.0;
  static const double homeCarouselBarRadius = 2.0;
  static const double homeCarouselBarSpacing = 8.0;
  static const double homeCarouselTitleFontSize = 18.0;
  static const double homeCarouselHeight = 180.0;
  static const double homeCarouselCardSpacing = 12.0;
  static const double homeCardWidth = 160.0;
  static const double homeCardRadius = 16.0;
  static const double homeCardShadowBlur = 8.0;
  static const double homeCardImageHeight = 100.0;
  static const double homeCardImageIconSize = 40.0;
  static const double homeCardPadding = 12.0;
  static const double homeCardTitleFontSize = 16.0;
  static const double homeCardTitleSpacing = 8.0;
  static const double homeCardDescFontSize = 14.0;
  // Profile
  static const double profilePlaceholderFontSize = 16.0;
  static const double profileButtonSpacing = 16.0;
  // Splash screen
  static const double splashLogoSpacing = 32.0;
  static const double splashStatusSpacing = 16.0;
  static const double splashWarningSpacing = 16.0;
  // Event calendar
  static const double calendarLogoHeight = 80.0;
  static const double calendarTitleSpacing = 16.0;
  static const double calendarTitleFontSize = 20.0;
  static const double calendarCardMargin = 8.0;
  static const double calendarCardPadding = 12.0;
  static const double calendarRowHeight = 40.0;
  static const double calendarDayFontSize = 14.0;
  static const double calendarWeekdayFontSize = 12.0;
  static const double calendarBelowSpacing = 16.0;
  static const double calendarEventCardMargin = 8.0;
  static const double calendarEventCardVertical = 4.0;
  static const double calendarEventDetailsSpacing = 8.0;
  // Hotspots
  static const double hotspotTitleFontSize = 18.0;
  static const double hotspotCategoryFontSize = 14.0;
  static const double hotspotFeeFontSize = 14.0;
  static const double hotspotLatLngFontSize = 12.0;
  // Map
  static final LatLng bukidnonCenter = LatLng(8.1573, 125.1277);
  static final LatLngBounds bukidnonBounds = LatLngBounds(
    southwest: LatLng(7.8, 124.8),
    northeast: LatLng(8.5, 125.5),
  );
  // Map zoom levels
  static const double kInitialZoom = 12.0;
  static const double kMinZoom = 8.0;
  static const double kMaxZoom = 18.0;
  static const double kLocationZoom = 15.0;
  static const Duration kServiceCheckTimeout = Duration(seconds: 10);
  static const Duration kLocationTimeout = Duration(seconds: 10);
  static const String kMapStyle = '';
  // Search
  static const List<String> districts = ['District 1', 'District 2'];
  static const List<String> municipalities = ['Municipality 1', 'Municipality 2'];
  static const double searchChipSpacing = 8.0;
  static const double searchScreenPadding = 16.0;
  static const double searchSectionTitleFontSize = 16.0;
  static const double searchSectionSpacing = 12.0;
  static const double searchResultsSpacing = 16.0;

}
