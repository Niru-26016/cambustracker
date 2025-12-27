import 'dart:async';
import 'dart:isolate';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

/// ForegroundTaskService handles background location tracking.
/// Uses flutter_foreground_task to keep location updates running when app is in background.
class ForegroundTaskService {
  static String? _currentBusId;
  static String? _currentDriverId;

  /// Initialize the foreground task
  static void init() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'bus_tracking_channel',
        channelName: 'Bus Tracking',
        channelDescription: 'Notification for bus location tracking',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        iconData: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        interval: 5000, // Fallback update every 5 seconds
        isOnceEvent: false,
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  /// Start the foreground service for location tracking
  static Future<bool> startService({
    required String busId,
    required String driverId,
  }) async {
    _currentBusId = busId;
    _currentDriverId = driverId;

    // CRITICAL: Save data for the isolate to read
    await FlutterForegroundTask.saveData(key: 'busId', value: busId);
    await FlutterForegroundTask.saveData(key: 'driverId', value: driverId);

    // Request permission for notification
    final notificationPermissionStatus =
        await FlutterForegroundTask.checkNotificationPermission();

    if (notificationPermissionStatus != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    // Start the foreground service
    return await FlutterForegroundTask.startService(
      notificationTitle: 'Bus Tracking Active',
      notificationText: 'Sharing your location with students',
      callback: startCallback,
    );
  }

  /// Stop the foreground service
  static Future<bool> stopService() async {
    _currentBusId = null;
    _currentDriverId = null;
    return await FlutterForegroundTask.stopService();
  }

  /// Check if service is running
  static Future<bool> get isRunning async {
    return await FlutterForegroundTask.isRunningService;
  }

  /// Get current bus ID being tracked
  static String? get currentBusId => _currentBusId;

  /// Get current driver ID
  static String? get currentDriverId => _currentDriverId;
}

/// This is the callback that runs in the isolate
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(LocationTaskHandler());
}

/// TaskHandler that runs in the foreground service isolate
class LocationTaskHandler extends TaskHandler {
  StreamSubscription<Position>? _positionSubscription;
  String? _busId;
  String? _driverId;
  FirebaseFirestore? _firestore;
  bool _isInitialized = false;
  Timer? _fallbackTimer;

  @override
  Future<void> onStart(DateTime timestamp, SendPort? sendPort) async {
    // Initialize Firebase in this isolate
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      // Already initialized
    }
    _firestore = FirebaseFirestore.instance;
    _isInitialized = true;

    // Get data passed from main isolate
    _busId = await FlutterForegroundTask.getData(key: 'busId');
    _driverId = await FlutterForegroundTask.getData(key: 'driverId');

    print('[ForegroundTask] Started for bus: $_busId, driver: $_driverId');

    // Start continuous location stream
    _startLocationStream();

    // Also start a fallback timer for reliability
    _startFallbackTimer();
  }

  void _startLocationStream() {
    // OPTIMIZED: Most aggressive location settings for real-time tracking
    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation, // Highest GPS accuracy
      distanceFilter: 2, // Update every 2 meters (very frequent)
    );

    _positionSubscription?.cancel();
    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            _updateLocation(position);
          },
          onError: (error) {
            print('[ForegroundTask] Location stream error: $error');
            // Restart stream on error
            Future.delayed(const Duration(seconds: 2), () {
              _startLocationStream();
            });
          },
        );
  }

  void _startFallbackTimer() {
    // Fallback: get location every 5 seconds even without movement
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        _updateLocation(position);
      } catch (e) {
        print('[ForegroundTask] Fallback location error: $e');
      }
    });
  }

  Future<void> _updateLocation(Position position) async {
    if (!_isInitialized || _firestore == null) {
      print('[ForegroundTask] Not initialized yet');
      return;
    }

    if (_busId == null || _driverId == null) {
      print('[ForegroundTask] Missing busId or driverId');
      return;
    }

    try {
      // Update Firestore with new location
      await _firestore!.collection('buses').doc(_busId).set({
        'lat': position.latitude,
        'lng': position.longitude,
        'speed': position.speed,
        'bearing': position.heading,
        'accuracy': position.accuracy,
        'isActive': true,
        'driverId': _driverId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Update notification with current info
      final speedKmh = (position.speed * 3.6).toStringAsFixed(0);
      FlutterForegroundTask.updateService(
        notificationTitle: 'Bus Tracking Active',
        notificationText: 'Speed: $speedKmh km/h • Location updated',
      );

      print(
        '[ForegroundTask] Location updated: ${position.latitude}, ${position.longitude}',
      );
    } catch (e) {
      print('[ForegroundTask] Error updating location: $e');
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp, SendPort? sendPort) async {
    // Called every 5 seconds as defined in init
    // Use this as additional fallback
    if (_positionSubscription == null) {
      print('[ForegroundTask] Restarting location stream from onRepeatEvent');
      _startLocationStream();
    }

    // Also try to get current position directly
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      );
      _updateLocation(position);
    } catch (e) {
      print('[ForegroundTask] onRepeatEvent location error: $e');
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, SendPort? sendPort) async {
    _positionSubscription?.cancel();
    _fallbackTimer?.cancel();

    // Mark bus as inactive when service stops
    if (_busId != null && _firestore != null) {
      try {
        await _firestore!.collection('buses').doc(_busId).update({
          'isActive': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        print('[ForegroundTask] Error marking bus inactive: $e');
      }
    }

    print('[ForegroundTask] Destroyed');
  }

  @override
  void onNotificationPressed() {
    print('[ForegroundTask] Notification pressed');
  }
}
