/// Route model representing a bus route in CambusTracker.
/// Stored in Firestore at `routes/{routeId}`
class BusRoute {
  final String routeId;
  final String name;
  final String description;
  final List<RouteStop> stops;
  final bool isActive;
  final DateTime createdAt;

  BusRoute({
    required this.routeId,
    required this.name,
    this.description = '',
    this.stops = const [],
    this.isActive = true,
    required this.createdAt,
  });

  /// Create BusRoute from Firestore document
  factory BusRoute.fromJson(Map<String, dynamic> json, String routeId) {
    final stopsList =
        (json['stops'] as List<dynamic>?)
            ?.map((s) => RouteStop.fromJson(s as Map<String, dynamic>))
            .toList() ??
        [];

    return BusRoute(
      routeId: routeId,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      stops: stopsList,
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt']?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'stops': stops.map((s) => s.toJson()).toList(),
      'isActive': isActive,
      'createdAt': createdAt,
    };
  }

  /// Get total number of stops
  int get stopCount => stops.length;

  /// Get ordered stops
  List<RouteStop> get orderedStops {
    final sorted = List<RouteStop>.from(stops);
    sorted.sort((a, b) => a.order.compareTo(b.order));
    return sorted;
  }
}

/// RouteStop model representing a stop on a bus route
class RouteStop {
  final String name;
  final double lat;
  final double lng;
  final int order;
  final String? arrivalTime; // Expected arrival time (e.g., "08:30")

  RouteStop({
    required this.name,
    required this.lat,
    required this.lng,
    required this.order,
    this.arrivalTime,
  });

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    return RouteStop(
      name: json['name'] ?? '',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (json['lng'] as num?)?.toDouble() ?? 0.0,
      order: json['order'] ?? 0,
      arrivalTime: json['arrivalTime'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'lat': lat,
      'lng': lng,
      'order': order,
      'arrivalTime': arrivalTime,
    };
  }
}
