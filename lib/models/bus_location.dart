/// BusLocation model representing real-time bus position.
/// Stored in Firestore at `buses/{busId}` (real-time location updates)
/// Hierarchy: Route → Bus → Driver
class BusLocation {
  final String busId;
  final String busName;
  final String? routeId; // Links to routes/{routeId}
  final double lat;
  final double lng;
  final double speed; // in km/h (cleaned by driver app)
  final double bearing; // direction in degrees
  final bool isActive;
  final String? driverId;
  final DateTime updatedAt;

  // Stop tracking for ETA calculation
  final int
  currentStopIndex; // Index of stop bus just passed (0 = before first stop)
  final String? nextStopName; // Name of next upcoming stop

  BusLocation({
    required this.busId,
    required this.busName,
    this.routeId,
    required this.lat,
    required this.lng,
    required this.speed,
    required this.bearing,
    required this.isActive,
    this.driverId,
    required this.updatedAt,
    this.currentStopIndex = 0,
    this.nextStopName,
  });

  /// Create BusLocation from Firestore document
  factory BusLocation.fromJson(Map<String, dynamic> json, String busId) {
    return BusLocation(
      busId: busId,
      busName: json['name'] ?? 'Bus $busId',
      routeId: json['routeId'],
      lat: (json['lat'] ?? 0.0).toDouble(),
      lng: (json['lng'] ?? 0.0).toDouble(),
      speed: (json['speed'] ?? 0.0).toDouble(),
      bearing: (json['bearing'] ?? 0.0).toDouble(),
      isActive: json['isActive'] ?? false,
      driverId: json['driverId'],
      updatedAt: json['updatedAt']?.toDate() ?? DateTime.now(),
      currentStopIndex: json['currentStopIndex'] ?? 0,
      nextStopName: json['nextStopName'],
    );
  }

  /// Convert BusLocation to Firestore document
  Map<String, dynamic> toJson() {
    return {
      'name': busName,
      'routeId': routeId,
      'lat': lat,
      'lng': lng,
      'speed': speed,
      'bearing': bearing,
      'isActive': isActive,
      'driverId': driverId,
      'updatedAt': updatedAt,
      'currentStopIndex': currentStopIndex,
      'nextStopName': nextStopName,
    };
  }

  /// Check if location data is stale (no update in 30 seconds)
  bool get isStale {
    return DateTime.now().difference(updatedAt).inSeconds > 30;
  }

  /// Get speed in km/h (speed is already in km/h from driver app)
  double get speedKmh => speed;

  /// Get formatted last update time
  String get lastUpdateFormatted {
    final diff = DateTime.now().difference(updatedAt);
    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${diff.inHours}h ago';
    }
  }
}
