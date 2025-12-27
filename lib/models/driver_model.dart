/// Driver model representing a bus driver in CambusTracker.
/// Stored in Firestore at `drivers/{driverId}`
/// Hierarchy: Route → Bus → Driver (Driver is assigned to Bus only)
class Driver {
  final String driverId;
  final String userId; // Links to users/{uid}
  final String name;
  final String email;
  final String? phone;
  final String? assignedBusId; // Driver is assigned to a Bus
  final bool isActive;
  final DateTime createdAt;

  Driver({
    required this.driverId,
    required this.userId,
    required this.name,
    required this.email,
    this.phone,
    this.assignedBusId,
    this.isActive = true,
    required this.createdAt,
  });

  /// Create Driver from Firestore document
  factory Driver.fromJson(Map<String, dynamic> json, String driverId) {
    return Driver(
      driverId: driverId,
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'],
      assignedBusId: json['assignedBusId'],
      isActive: json['isActive'] ?? true,
      createdAt: json['createdAt']?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'name': name,
      'email': email,
      'phone': phone,
      'assignedBusId': assignedBusId,
      'isActive': isActive,
      'createdAt': createdAt,
    };
  }

  /// Check if driver has an assigned bus
  bool get hasBusAssignment =>
      assignedBusId != null && assignedBusId!.isNotEmpty;

  /// Create a copy with updated fields
  Driver copyWith({
    String? name,
    String? phone,
    String? assignedBusId,
    bool? isActive,
  }) {
    return Driver(
      driverId: driverId,
      userId: userId,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      assignedBusId: assignedBusId ?? this.assignedBusId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
}
