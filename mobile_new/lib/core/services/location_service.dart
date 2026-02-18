import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

/// Provider for location service
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

/// Service for handling device location and navigation
class LocationService {
  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Check current permission status
  Future<LocationPermission> checkPermission() async {
    return await Geolocator.checkPermission();
  }

  /// Request location permission
  Future<LocationPermission> requestPermission() async {
    return await Geolocator.requestPermission();
  }

  /// Check and request location permission if needed
  /// Returns true if permission is granted, false otherwise
  Future<bool> checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Get current device location
  /// Returns null if permission is not granted or location cannot be retrieved
  Future<Position?> getCurrentLocation() async {
    final hasPermission = await checkAndRequestPermission();
    if (!hasPermission) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Location request timed out after 10 seconds');
        },
      );
    } catch (e) {
      debugPrint('LocationService: getCurrentLocation error - $e');
      return null;
    }
  }

  /// Open maps app for navigation to specified coordinates
  /// Uses Google Maps URL scheme which works on both Android and iOS
  Future<bool> openMapsNavigation(double latitude, double longitude) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
    );

    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Open maps app to show a specific location (without navigation)
  Future<bool> openMapsLocation(double latitude, double longitude) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );

    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Open device location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open app settings (for when permission is denied forever)
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Reverse geocode coordinates to get a human-readable address
  /// Returns null if geocoding fails (network issues, no results, etc.)
  Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isEmpty) return null;

      final place = placemarks.first;

      // Build address from available components
      final parts = <String>[
        if (place.subThoroughfare?.isNotEmpty == true) place.subThoroughfare!,
        if (place.thoroughfare?.isNotEmpty == true) place.thoroughfare!,
        if (place.subLocality?.isNotEmpty == true) place.subLocality!,
        if (place.locality?.isNotEmpty == true) place.locality!,
        if (place.administrativeArea?.isNotEmpty == true)
          place.administrativeArea!,
      ];

      return parts.isNotEmpty ? parts.join(', ') : null;
    } catch (e) {
      debugPrint('LocationService: Reverse geocoding failed - $e');
      return null;
    }
  }

  /// Forward geocode address to get coordinates
  /// Returns null if geocoding fails (network issues, no results, etc.)
  Future<({double latitude, double longitude})?> getCoordinatesFromAddress(
    String address,
  ) async {
    try {
      final locations = await locationFromAddress(address);

      if (locations.isEmpty) return null;

      return (
        latitude: locations.first.latitude,
        longitude: locations.first.longitude,
      );
    } catch (e) {
      debugPrint('LocationService: Forward geocoding failed - $e');
      return null;
    }
  }
}
