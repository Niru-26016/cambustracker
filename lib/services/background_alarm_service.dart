import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

/// Simple alarm service that plays phone alarm sound
class NotificationAlarmService {
  static bool _isPlaying = false;
  static final FlutterRingtonePlayer _player = FlutterRingtonePlayer();

  /// Initialize (no-op for simple implementation)
  static Future<void> initialize() async {
    // No initialization needed for flutter_ringtone_player
  }

  /// Show alarm notification and play sound
  static Future<void> showAlarmNotification(String stopName) async {
    if (_isPlaying) return;
    _isPlaying = true;

    // Play alarm sound (loops until stopped)
    try {
      _player.playAlarm(looping: true, volume: 1.0, asAlarm: true);
    } catch (e) {
      _isPlaying = false;
    }
  }

  /// Stop the alarm sound
  static Future<void> stopAlarm() async {
    _isPlaying = false;
    try {
      _player.stop();
    } catch (e) {
      // Ignore errors
    }
  }

  /// Request notification permissions (no-op for simple implementation)
  static Future<bool> requestPermissions() async {
    return true;
  }
}
