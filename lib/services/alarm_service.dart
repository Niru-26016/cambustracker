import 'package:shared_preferences/shared_preferences.dart';

/// AlarmService - Manages arrival alarm settings using SharedPreferences
/// No Firestore writes = battery-safe and fast
class AlarmService {
  static const _keyEnabled = 'alarm_enabled';
  static const _keyDistance = 'alarm_distance';
  static const _keyStopId = 'alarm_stop_id';
  static const _keyStopName = 'alarm_stop_name';
  static const _keyStopLat = 'alarm_stop_lat';
  static const _keyStopLng = 'alarm_stop_lng';
  static const _keyTriggered = 'alarm_triggered';
  static const _keyTriggeredAt = 'alarm_triggered_at';
  static const _keyBusId = 'alarm_bus_id';

  SharedPreferences? _prefs;

  Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // ============ Alarm Enabled ============
  Future<void> setAlarmEnabled(bool enabled) async {
    final p = await prefs;
    await p.setBool(_keyEnabled, enabled);
    if (!enabled) {
      // Reset triggered state when alarm is disabled
      await setAlarmTriggered(false);
    }
  }

  Future<bool> isAlarmEnabled() async {
    final p = await prefs;
    return p.getBool(_keyEnabled) ?? false;
  }

  // ============ Alert Distance ============
  Future<void> setAlertDistance(int meters) async {
    final p = await prefs;
    await p.setInt(_keyDistance, meters);
  }

  Future<int> getAlertDistance() async {
    final p = await prefs;
    return p.getInt(_keyDistance) ?? 500;
  }

  // ============ Selected Stop ============
  Future<void> setSelectedStop({
    required String stopId,
    required String stopName,
    required double lat,
    required double lng,
  }) async {
    final p = await prefs;
    await p.setString(_keyStopId, stopId);
    await p.setString(_keyStopName, stopName);
    await p.setDouble(_keyStopLat, lat);
    await p.setDouble(_keyStopLng, lng);
    // Reset triggered state when stop changes
    await setAlarmTriggered(false);
  }

  Future<Map<String, dynamic>?> getSelectedStop() async {
    final p = await prefs;
    final stopId = p.getString(_keyStopId);
    final stopName = p.getString(_keyStopName);
    final lat = p.getDouble(_keyStopLat);
    final lng = p.getDouble(_keyStopLng);

    if (stopId == null || stopName == null || lat == null || lng == null) {
      return null;
    }

    return {'stopId': stopId, 'stopName': stopName, 'lat': lat, 'lng': lng};
  }

  Future<void> clearSelectedStop() async {
    final p = await prefs;
    await p.remove(_keyStopId);
    await p.remove(_keyStopName);
    await p.remove(_keyStopLat);
    await p.remove(_keyStopLng);
  }

  // ============ Bus ID ============
  Future<void> setSelectedBus(String busId) async {
    final p = await prefs;
    await p.setString(_keyBusId, busId);
  }

  Future<String?> getSelectedBus() async {
    final p = await prefs;
    return p.getString(_keyBusId);
  }

  // ============ Alarm Triggered ============
  Future<void> setAlarmTriggered(bool triggered) async {
    final p = await prefs;
    await p.setBool(_keyTriggered, triggered);
    if (triggered) {
      await p.setString(_keyTriggeredAt, DateTime.now().toIso8601String());
    } else {
      await p.remove(_keyTriggeredAt);
    }
  }

  Future<bool> wasAlarmTriggered() async {
    final p = await prefs;
    return p.getBool(_keyTriggered) ?? false;
  }

  Future<DateTime?> getTriggeredTime() async {
    final p = await prefs;
    final timeStr = p.getString(_keyTriggeredAt);
    if (timeStr != null) {
      return DateTime.tryParse(timeStr);
    }
    return null;
  }

  // ============ Reset All ============
  Future<void> resetAlarm() async {
    final p = await prefs;
    await p.remove(_keyEnabled);
    await p.remove(_keyTriggered);
    await p.remove(_keyTriggeredAt);
    // Keep distance and stop selection for convenience
  }

  Future<void> clearAll() async {
    final p = await prefs;
    await p.remove(_keyEnabled);
    await p.remove(_keyDistance);
    await p.remove(_keyStopId);
    await p.remove(_keyStopName);
    await p.remove(_keyStopLat);
    await p.remove(_keyStopLng);
    await p.remove(_keyTriggered);
    await p.remove(_keyTriggeredAt);
    await p.remove(_keyBusId);
  }
}
