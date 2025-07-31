import 'package:flutter/foundation.dart';

class ApiEnvironment {
  static const String proxyBaseUrl = "http://localhost:3000/directions";
  static const String directionsBaseUrl = "https://maps.googleapis.com/maps/api/directions/json";
  static const String googleDirectionsApiKey = "AIzaSyCHDrbJrZHSeMFG40A-hQPB37nrmA6rUKE";

  static String getDirectionsUrl(String origin, String destination) {
    if (kIsWeb) {
      // Use proxy for web
      return "$proxyBaseUrl?origin=$origin&destination=$destination&mode=driving";
    } else {
      // Use Google API directly for mobile
      final encodedOrigin = Uri.encodeComponent(origin);
      final encodedDestination = Uri.encodeComponent(destination);
      return "$directionsBaseUrl?origin=$encodedOrigin&destination=$encodedDestination&key=$googleDirectionsApiKey&mode=driving";
    }
  }
}