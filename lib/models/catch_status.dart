/// CatchStatus - Represents whether user can catch their bus
enum CatchStatus {
  /// User can comfortably catch the bus
  canCatch,

  /// Timing is close - user should hurry
  hurry,

  /// User will likely miss the bus
  missed,

  /// Cannot determine status (e.g., no location data)
  unknown,
}

/// Extension to get display properties for CatchStatus
extension CatchStatusExtension on CatchStatus {
  String get message {
    switch (this) {
      case CatchStatus.canCatch:
        return 'You can catch this bus';
      case CatchStatus.hurry:
        return 'Hurry up!';
      case CatchStatus.missed:
        return 'You will miss this bus';
      case CatchStatus.unknown:
        return 'Calculating...';
    }
  }
}
