import 'package:cloud_firestore/cloud_firestore.dart';

/// Trip model representing an active bus-route assignment.
/// Stored in Firestore at `trips/{tripId}`
/// Supports combined routes (one bus serving multiple routes)
class Trip {
  final String tripId;
  final String busId;
  final List<String> routeIds; // Supports multiple routes for combined trips
  final String? driverId;
  final bool isCombined;
  final String status; // 'active', 'completed', 'cancelled'
  final String createdBy; // Admin UID who created this trip
  final DateTime createdAt;
  final DateTime? endedAt;

  Trip({
    required this.tripId,
    required this.busId,
    required this.routeIds,
    this.driverId,
    this.isCombined = false,
    this.status = 'active',
    required this.createdBy,
    required this.createdAt,
    this.endedAt,
  });

  /// Create Trip from Firestore document
  factory Trip.fromJson(Map<String, dynamic> json, String tripId) {
    return Trip(
      tripId: tripId,
      busId: json['busId'] ?? '',
      routeIds: List<String>.from(json['routeIds'] ?? []),
      driverId: json['driverId'],
      isCombined: json['isCombined'] ?? false,
      status: json['status'] ?? 'active',
      createdBy: json['createdBy'] ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt: (json['endedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toJson() {
    return {
      'busId': busId,
      'routeIds': routeIds,
      'driverId': driverId,
      'isCombined': isCombined,
      'status': status,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
    };
  }

  /// Check if this trip serves a specific route
  bool servesRoute(String routeId) => routeIds.contains(routeId);

  /// Check if trip is currently active
  bool get isActive => status == 'active';

  /// Get display text for routes
  String get routeDisplayText {
    if (routeIds.length == 1) return routeIds.first;
    return '${routeIds.length} routes';
  }

  /// Create a copy with updated fields
  Trip copyWith({
    String? tripId,
    String? busId,
    List<String>? routeIds,
    String? driverId,
    bool? isCombined,
    String? status,
    String? createdBy,
    DateTime? createdAt,
    DateTime? endedAt,
  }) {
    return Trip(
      tripId: tripId ?? this.tripId,
      busId: busId ?? this.busId,
      routeIds: routeIds ?? this.routeIds,
      driverId: driverId ?? this.driverId,
      isCombined: isCombined ?? this.isCombined,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      endedAt: endedAt ?? this.endedAt,
    );
  }
}
