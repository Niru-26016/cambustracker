/// Bus model representing a bus in CambusTracker.
/// Stored in Firestore at `buses/{busId}`
/// Hierarchy: Route → Bus → Driver
class Bus {
  final String busId;
  final String busNumber; // e.g., "TN09AB1234"
  final String? name; // e.g., "Perambur Boys"
  final String? routeId; // Links to routes/{routeId}
  final bool isActive;
  final DateTime createdAt;

  Bus({
    required this.busId,
    required this.busNumber,
    this.name,
    this.routeId,
    this.isActive = true,
    required this.createdAt,
  });

  /// Create Bus from Firestore document
  factory Bus.fromJson(Map<String, dynamic> json, String busId) {
    return Bus(
      busId: busId,
      busNumber: json['busNumber'] ?? busId,
      name: json['name'],
      routeId: json['routeId'],
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt']?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toJson() {
    return {
      'busNumber': busNumber,
      'name': name,
      'routeId': routeId,
      'isActive': isActive,
      'createdAt': createdAt,
    };
  }

  /// Get display name (name or busNumber)
  String get displayName => name ?? busNumber;

  /// Check if bus is assigned to a route
  bool get hasRoute => routeId != null && routeId!.isNotEmpty;

  /// Create a copy with updated fields
  Bus copyWith({
    String? busNumber,
    String? name,
    String? routeId,
    bool? isActive,
  }) {
    return Bus(
      busId: busId,
      busNumber: busNumber ?? this.busNumber,
      name: name ?? this.name,
      routeId: routeId ?? this.routeId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
}
