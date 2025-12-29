import 'package:geolocator/geolocator.dart';
import '../models/route_model.dart';
import '../models/bus_location.dart';

/// ETA Calculator using distance/speed (no API calls)
/// Free, battery-friendly, works in real-time
class EtaCalculator {
  /// Default average bus speed when actual speed is too low (km/h)
  static const double _defaultAverageSpeed = 25.0;

  /// Minimum speed to trust for ETA calculation (km/h)
  static const double _minSpeedForEta = 5.0;

  /// Calculate ETA from bus to a specific stop
  /// Returns ETA in minutes, or null if cannot be calculated
  static int? calculateEtaToStop({
    required BusLocation bus,
    required RouteStop targetStop,
    required List<RouteStop> allStops,
  }) {
    if (!bus.isActive) return null;

    // Get ordered stops
    final orderedStops = List<RouteStop>.from(allStops)
      ..sort((a, b) => a.order.compareTo(b.order));

    // Find target stop index
    final targetIndex = orderedStops.indexWhere(
      (s) =>
          s.name == targetStop.name ||
          (s.lat == targetStop.lat && s.lng == targetStop.lng),
    );

    if (targetIndex < 0) return null;

    // If bus has already passed the target stop
    if (bus.currentStopIndex > targetIndex) {
      return null; // Bus passed this stop
    }

    // Calculate total distance from bus to target stop
    double totalDistance = 0;

    // Distance from bus current position to next stop
    if (bus.currentStopIndex < orderedStops.length) {
      totalDistance = Geolocator.distanceBetween(
        bus.lat,
        bus.lng,
        orderedStops[bus.currentStopIndex].lat,
        orderedStops[bus.currentStopIndex].lng,
      );
    }

    // Add distances between intermediate stops
    for (int i = bus.currentStopIndex; i < targetIndex; i++) {
      if (i + 1 < orderedStops.length) {
        totalDistance += Geolocator.distanceBetween(
          orderedStops[i].lat,
          orderedStops[i].lng,
          orderedStops[i + 1].lat,
          orderedStops[i + 1].lng,
        );
      }
    }

    // Get speed (use bus speed if valid, otherwise default)
    final speedKmh = bus.speed >= _minSpeedForEta
        ? bus.speed
        : _defaultAverageSpeed;

    // Calculate ETA: time = distance / speed
    // distance in meters, speed in km/h
    // ETA in minutes = (distance / 1000) / speed * 60
    final etaMinutes = (totalDistance / 1000) / speedKmh * 60;

    return etaMinutes.round();
  }

  /// Calculate ETA from bus to user's nearest stop
  /// First finds nearest stop to user, then calculates bus ETA to that stop
  static Map<String, dynamic>? calculateEtaToUserStop({
    required BusLocation bus,
    required double userLat,
    required double userLng,
    required List<RouteStop> allStops,
  }) {
    if (!bus.isActive || allStops.isEmpty) return null;

    // Get ordered stops
    final orderedStops = List<RouteStop>.from(allStops)
      ..sort((a, b) => a.order.compareTo(b.order));

    // Find nearest stop to user (that bus hasn't passed yet)
    RouteStop? nearestStop;
    double minDistance = double.infinity;
    int nearestIndex = -1;

    for (int i = bus.currentStopIndex; i < orderedStops.length; i++) {
      final stop = orderedStops[i];
      final distanceToUser = Geolocator.distanceBetween(
        userLat,
        userLng,
        stop.lat,
        stop.lng,
      );

      if (distanceToUser < minDistance) {
        minDistance = distanceToUser;
        nearestStop = stop;
        nearestIndex = i;
      }
    }

    if (nearestStop == null) return null;

    // Calculate ETA to that stop
    final eta = calculateEtaToStop(
      bus: bus,
      targetStop: nearestStop,
      allStops: allStops,
    );

    return {
      'stop': nearestStop,
      'stopIndex': nearestIndex,
      'distanceToUser': minDistance.round(),
      'etaMinutes': eta,
    };
  }

  /// Format ETA for display
  static String formatEta(int? minutes) {
    if (minutes == null) return 'N/A';
    if (minutes <= 0) return 'Arriving';
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }

  /// Get color-coded status based on ETA
  /// Returns: 'soon' (< 5 min), 'coming' (5-15 min), 'later' (> 15 min)
  static String getEtaStatus(int? minutes) {
    if (minutes == null) return 'unknown';
    if (minutes <= 2) return 'arriving';
    if (minutes <= 5) return 'soon';
    if (minutes <= 15) return 'coming';
    return 'later';
  }
}
