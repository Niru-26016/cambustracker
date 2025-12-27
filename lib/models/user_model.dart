/// AppUser model representing a user in the CambusTracker app.
/// Stored in Firestore at `users/{uid}`
/// Roles: "admin" | "driver" | "passenger" (legacy: "student")
class AppUser {
  final String uid;
  final String name;
  final String email;
  final String role; // "admin" | "driver" | "passenger"
  final String? busId;
  final String? routeId;
  final String? phone;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.busId,
    this.routeId,
    this.phone,
    required this.createdAt,
  });

  /// Create AppUser from Firestore document
  factory AppUser.fromJson(Map<String, dynamic> json, String uid) {
    // Handle legacy "student" role as "passenger"
    String role = json['role'] ?? 'passenger';
    if (role == 'student') role = 'passenger';

    return AppUser(
      uid: uid,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      role: role,
      busId: json['busId'],
      routeId: json['routeId'],
      phone: json['phone'],
      createdAt: json['createdAt']?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert AppUser to Firestore document
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'email': email,
      'role': role,
      'busId': busId,
      'routeId': routeId,
      'phone': phone,
      'createdAt': createdAt,
    };
  }

  /// Check if user is an administrator
  bool get isAdmin => role == 'admin';

  /// Check if user is a driver
  bool get isDriver => role == 'driver';

  /// Check if user is a passenger (supports legacy "student" check)
  bool get isPassenger => role == 'passenger' || role == 'student';

  /// Legacy alias for isPassenger
  bool get isStudent => isPassenger;

  /// Check if role is set
  bool get hasRole => role.isNotEmpty && role != '';

  /// Create a copy with updated fields
  AppUser copyWith({
    String? name,
    String? email,
    String? role,
    String? busId,
    String? routeId,
    String? phone,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      role: role ?? this.role,
      busId: busId ?? this.busId,
      routeId: routeId ?? this.routeId,
      phone: phone ?? this.phone,
      createdAt: createdAt,
    );
  }
}
