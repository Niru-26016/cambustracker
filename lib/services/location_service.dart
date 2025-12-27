import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// LocationService handles GPS location tracking.
/// Uses geolocator for location updates and permissions.
class LocationService {
  StreamSubscription<Position>? _positionSubscription;

  /// Check and request location permissions
  /// Returns true if permission granted, false otherwise
  Future<bool> requestLocationPermission() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[LocationService] Location services disabled');
      return false;
    }

    // Check current permission status
    LocationPermission permission = await Geolocator.checkPermission();
    debugPrint('[LocationService] Current permission: $permission');

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        debugPrint('[LocationService] Permission denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('[LocationService] Permission denied forever');
      return false;
    }

    debugPrint('[LocationService] Permission granted: $permission');
    return true;
  }

  /// Request background location permission (Android 10+)
  /// For foreground service, whileInUse is sufficient
  Future<bool> requestBackgroundLocationPermission() async {
    // Check if location services are enabled
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      debugPrint('[LocationService] Location services disabled');
      return false;
    }

    // Check current permission
    LocationPermission permission = await Geolocator.checkPermission();
    debugPrint('[LocationService] Background check - permission: $permission');

    // whileInUse is sufficient for foreground service
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      debugPrint('[LocationService] Permission OK for tracking');
      return true;
    }

    // Request permission if denied
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      debugPrint('[LocationService] Requested permission, got: $permission');
    }

    // Accept whileInUse or always
    if (permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always) {
      return true;
    }

    debugPrint('[LocationService] Permission not granted: $permission');
    return false;
  }

  /// Get current location
  Future<Position?> getCurrentLocation() async {
    try {
      bool hasPermission = await requestLocationPermission();
      if (!hasPermission) {
        debugPrint('[LocationService] No permission for getCurrentLocation');
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      debugPrint(
        '[LocationService] Got position: ${position.latitude}, ${position.longitude}',
      );
      return position;
    } catch (e) {
      debugPrint('[LocationService] Error getting location: $e');
      return null;
    }
  }

  /// Start location stream with updates every 3-5 seconds
  Stream<Position> getLocationStream() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    return Geolocator.getPositionStream(locationSettings: locationSettings);
  }

  /// Start listening to location updates with callback
  void startLocationUpdates(void Function(Position) onLocationUpdate) {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          onLocationUpdate,
          onError: (error) {
            debugPrint('[LocationService] Stream error: $error');
          },
        );
  }

  /// Stop listening to location updates
  void stopLocationUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Calculate distance between two points in meters
  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Open location settings
  Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }

  /// Open app settings (for permission denied forever)
  Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }
}
