import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart'; // For ByteData
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/direction_service.dart';
import '../models/bus_location.dart';
import '../models/route_model.dart';
import '../models/catch_status.dart';
import '../services/alarm_service.dart';
import '../services/background_alarm_service.dart'
    show NotificationAlarmService;
import 'package:flutter/services.dart' show HapticFeedback;

/// StudentScreen (Passenger) - Tabbed interface for passengers.
/// 4 Tabs: Live Location, Driver Details, Lost Items, Arrival Alarm
class StudentScreen extends StatefulWidget {
  const StudentScreen({super.key});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final DirectionService _directionService = DirectionService();

  late TabController _tabController;
  String? _selectedBusId;
  String? _selectedBusName;
  BusLocation? _trackedBus;
  List<Map<String, String>> _availableBuses = [];
  bool _isSelectingBus = true;

  // Route selection state
  String? _selectedRouteId;
  String? _selectedRouteName;
  List<Map<String, dynamic>> _availableRoutes = [];

  // Navigation state
  List<LatLng> _walkingPath = [];
  RouteStop? _nearestStop;
  String? _distanceText;
  String? _durationText;
  bool _showingNavigation = false;

  // Alarm state (local, not Firestore)
  final AlarmService _alarmService = AlarmService();
  bool _alarmEnabled = false;
  int _alarmDistance = 500;
  Map<String, dynamic>? _selectedAlarmStop;
  bool _alarmTriggered = false;
  DateTime? _alarmTriggeredAt;

  // Custom bus marker
  BitmapDescriptor? _busMarkerIcon;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _createBusDotMarker();
    _loadAvailableRoutes();
    _loadAvailableBuses();
    _loadUserBusSelection();
    _loadAlarmSettings();
  }

  Future<void> _loadAlarmSettings() async {
    _alarmEnabled = await _alarmService.isAlarmEnabled();
    _alarmDistance = await _alarmService.getAlertDistance();
    _selectedAlarmStop = await _alarmService.getSelectedStop();
    _alarmTriggered = await _alarmService.wasAlarmTriggered();
    _alarmTriggeredAt = await _alarmService.getTriggeredTime();
    if (mounted) setState(() {});
  }

  Future<void> _createBusDotMarker() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = Colors.green;
    final Paint borderPaint = Paint()..color = Colors.white;
    final double radius = 24.0;

    // Draw white border
    canvas.drawCircle(Offset(radius, radius), radius, borderPaint);
    // Draw green dot
    canvas.drawCircle(Offset(radius, radius), radius - 6, paint);

    final ui.Image image = await pictureRecorder.endRecording().toImage(
      (radius * 2).toInt(),
      (radius * 2).toInt(),
    );
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (byteData != null) {
      final icon = BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
      setState(() => _busMarkerIcon = icon);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableRoutes() async {
    final routes = await _firestoreService.getRoutes();
    if (mounted) {
      setState(
        () => _availableRoutes = routes
            .map((r) => {'id': r.routeId, 'name': r.name})
            .toList(),
      );
    }
  }

  Future<void> _loadAvailableBuses() async {
    final buses = await _firestoreService.getAvailableBuses();
    if (mounted) {
      setState(() => _availableBuses = buses);
    }
  }

  Future<void> _loadUserBusSelection() async {
    final user = await _authService.getCurrentUserProfile();
    if (user != null && user.busId != null && mounted) {
      // Try to get bus name from available buses list
      var busName = 'Loading...';
      final matchingBus = _availableBuses
          .where((b) => b['id'] == user.busId)
          .firstOrNull;
      if (matchingBus != null) {
        busName = matchingBus['name'] ?? user.busId!;
      } else {
        // Fetch directly from Firestore if not in list
        final buses = await _firestoreService.getAvailableBuses();
        final bus = buses.where((b) => b['id'] == user.busId).firstOrNull;
        busName = bus?['name'] ?? user.busId!;
      }

      setState(() {
        _selectedBusId = user.busId;
        _selectedBusName = busName;
        _isSelectingBus = false;
      });
    }
  }

  void _selectBus(String busId, String busName) async {
    setState(() {
      _selectedBusId = busId;
      _selectedBusName = busName;
      _isSelectingBus = false;
    });
    try {
      await _authService.updateUserBus(busId);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    // Show bus selection screen first
    if (_isSelectingBus) {
      return _buildBusSelectionScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedBusName ?? 'CambusTracker',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Change Bus',
            onPressed: () => setState(() => _isSelectingBus = true),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              if (context.mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        physics: const NeverScrollableScrollPhysics(), // Disable swipe
        children: [
          _buildLiveLocationTab(),
          _buildDriverDetailsTab(),
          _buildLostItemsTab(),
          _buildArrivalAlarmTab(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: Colors.white54,
          indicatorColor: primaryColor,
          indicatorSize: TabBarIndicatorSize.tab,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.map), text: 'Live'),
            Tab(icon: Icon(Icons.person), text: 'Driver'),
            Tab(icon: Icon(Icons.warning_amber), text: 'Lost'),
            Tab(icon: Icon(Icons.alarm), text: 'Alarm'),
          ],
        ),
      ),
    );
  }

  // ============================================
  // TAB 1: Live Location
  // ============================================
  GoogleMapController? _mapController;

  Widget _buildLiveLocationTab() {
    final primaryColor = Theme.of(context).primaryColor;

    return Stack(
      children: [
        StreamBuilder<BusLocation?>(
          stream: _firestoreService.streamBusLocation(_selectedBusId!),
          builder: (context, busSnapshot) {
            _trackedBus = busSnapshot.data;
            final routeId = _trackedBus?.routeId;

            // Nested StreamBuilder for route stops
            return StreamBuilder<List<BusRoute>>(
              stream: _firestoreService.streamRoutes(),
              builder: (context, routeSnapshot) {
                // Find the route for this bus
                BusRoute? currentRoute;
                if (routeId != null && routeSnapshot.hasData) {
                  currentRoute = routeSnapshot.data
                      ?.where((r) => r.routeId == routeId)
                      .firstOrNull;
                }

                // Build markers
                final markers = <Marker>{};

                // Add bus marker
                if (_trackedBus != null) {
                  markers.add(
                    Marker(
                      markerId: MarkerId(_trackedBus!.busId),
                      position: LatLng(_trackedBus!.lat, _trackedBus!.lng),
                      rotation: _trackedBus!.bearing,
                      icon:
                          _busMarkerIcon ??
                          BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueGreen,
                          ),
                      infoWindow: InfoWindow(
                        title: _trackedBus!.busName,
                        snippet:
                            '${_trackedBus!.speedKmh.toStringAsFixed(1)} km/h',
                      ),
                    ),
                  );
                }

                // Add stop markers
                if (currentRoute != null) {
                  for (int i = 0; i < currentRoute.stops.length; i++) {
                    final stop = currentRoute.stops[i];
                    markers.add(
                      Marker(
                        markerId: MarkerId('stop_$i'),
                        position: LatLng(stop.lat, stop.lng),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueOrange,
                        ),
                        infoWindow: InfoWindow(
                          title: '${i + 1}. ${stop.name}',
                          snippet:
                              'Stop ${i + 1} of ${currentRoute.stops.length}',
                        ),
                      ),
                    );
                  }
                }

                return GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _trackedBus != null
                        ? LatLng(_trackedBus!.lat, _trackedBus!.lng)
                        : const LatLng(13.0827, 80.2707),
                    zoom: 15,
                  ),

                  onMapCreated: (controller) {
                    _mapController = controller;
                    // Apply dark mode
                    controller.setMapStyle('''
[
  {"elementType": "geometry", "stylers": [{"color": "#212121"}]},
  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#212121"}]},
  {"featureType": "road", "elementType": "geometry.fill", "stylers": [{"color": "#2c2c2c"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#000000"}]}
]
''');
                  },
                  markers: markers,
                  polylines: _walkingPath.isNotEmpty
                      ? {
                          Polyline(
                            polylineId: const PolylineId('walking_path'),
                            points: _walkingPath,
                            color: Colors.blue,
                            width: 5,
                          ),
                        }
                      : {},
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                );
              },
            );
          },
        ),

        // Navigation Card (shown when navigating)
        if (_showingNavigation && _nearestStop != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildNavigationCard(),
          )
        else
          // Bus Info Card at bottom
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _buildBusInfoCard(),
          ),

        // Zoom Buttons Column
        Positioned(
          right: 16,
          bottom: 120,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Zoom to User Location
              FloatingActionButton.small(
                heroTag: 'userLocation',
                backgroundColor: const Color(0xFF1E1E1E),
                onPressed: () async {
                  try {
                    // Check if location services are enabled
                    bool serviceEnabled =
                        await Geolocator.isLocationServiceEnabled();
                    if (!serviceEnabled) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Location services are disabled'),
                          ),
                        );
                      }
                      return;
                    }

                    // Check permissions
                    LocationPermission permission =
                        await Geolocator.checkPermission();
                    if (permission == LocationPermission.denied) {
                      permission = await Geolocator.requestPermission();
                      if (permission == LocationPermission.denied) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Location permissions are denied'),
                            ),
                          );
                        }
                        return;
                      }
                    }

                    if (permission == LocationPermission.deniedForever) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Location permissions are permanently denied. Please enable in settings.',
                            ),
                          ),
                        );
                      }
                      return;
                    }

                    // Permission granted - trigger rebuild to show blue dot
                    if (mounted) setState(() {});

                    // Try last known location first for instant response
                    Position? position =
                        await Geolocator.getLastKnownPosition();

                    // If no cached position, get current
                    position ??= await Geolocator.getCurrentPosition(
                      desiredAccuracy: LocationAccuracy.high,
                      timeLimit: const Duration(seconds: 5),
                    );

                    _mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(
                        LatLng(position.latitude, position.longitude),
                        17,
                      ),
                    );
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error getting location: $e')),
                      );
                    }
                  }
                },
                child: const Icon(Icons.person_pin_circle, color: Colors.blue),
              ),
              const SizedBox(height: 8),

              // Zoom to Bus Location
              FloatingActionButton.small(
                heroTag: 'busLocation',
                backgroundColor: primaryColor,
                onPressed: () {
                  if (_trackedBus != null) {
                    _mapController?.animateCamera(
                      CameraUpdate.newLatLngZoom(
                        LatLng(_trackedBus!.lat, _trackedBus!.lng),
                        17,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Bus location not available'),
                      ),
                    );
                  }
                },
                child: const Icon(Icons.directions_bus, color: Colors.black),
              ),
              const SizedBox(height: 8),

              // Navigate to Nearest Stop
              FloatingActionButton.small(
                heroTag: 'nearestStop',
                backgroundColor: Colors.orange,
                onPressed: () => _navigateToNearestStop(),
                child: const Icon(Icons.navigation, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Find nearest stop, fetch walking path, and show navigation UI
  Future<void> _navigateToNearestStop() async {
    try {
      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Finding nearest stop...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      // Get user's current location
      Position? position = await Geolocator.getLastKnownPosition();
      position ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );

      final userLatLng = LatLng(position.latitude, position.longitude);

      // Get the bus's route
      if (_trackedBus?.routeId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This bus has no assigned route')),
          );
        }
        return;
      }

      // Get all routes and find the one for this bus
      final routes = await _firestoreService.streamRoutes().first;
      final route = routes
          .where((r) => r.routeId == _trackedBus!.routeId)
          .firstOrNull;

      if (route == null || route.stops.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No stops found for this route')),
          );
        }
        return;
      }

      // Find nearest stop using Geolocator for accuracy
      RouteStop? nearestStop;
      double minDistance = double.infinity;

      for (final stop in route.stops) {
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          stop.lat,
          stop.lng,
        );
        if (distance < minDistance) {
          minDistance = distance;
          nearestStop = stop;
        }
      }

      if (nearestStop == null) return;

      final stopLatLng = LatLng(nearestStop.lat, nearestStop.lng);

      // Fetch walking path from Directions API
      final walkingPath = await _directionService.fetchWalkingPath(
        userLatLng,
        stopLatLng,
      );

      // Get distance/duration info
      final distanceInfo = await _directionService.getDistanceInfo(
        userLatLng,
        stopLatLng,
      );

      // Update state to show navigation
      setState(() {
        _nearestStop = nearestStop;
        _walkingPath = walkingPath;
        _distanceText = distanceInfo['distance'];
        _durationText = distanceInfo['duration'];
        _showingNavigation = true;
      });

      // Zoom to show both user and stop
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(userLatLng, 16));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  /// Clear navigation and return to normal view
  void _clearNavigation() {
    setState(() {
      _showingNavigation = false;
      _walkingPath = [];
      _nearestStop = null;
      _distanceText = null;
      _durationText = null;
    });
  }

  /// Open Google Maps navigation to nearest stop
  Future<void> _openGoogleMapsNavigation() async {
    if (_nearestStop == null) return;

    final uri = Uri.parse(
      'google.navigation:q=${_nearestStop!.lat},${_nearestStop!.lng}&mode=w',
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback to web URL
      final webUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${_nearestStop!.lat},${_nearestStop!.lng}&travelmode=walking',
      );
      await launchUrl(webUrl, mode: LaunchMode.externalApplication);
    }
  }

  /// Call the driver using phone dialer
  Future<void> _callDriver(String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open phone dialer')),
        );
      }
    }
  }

  /// Build navigation card showing nearest stop info
  Widget _buildNavigationCard() {
    final primaryColor = Theme.of(context).primaryColor;

    return Card(
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: primaryColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with close button
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.location_on, color: Colors.orange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nearest Stop',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        _nearestStop?.name ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _clearNavigation,
                  icon: const Icon(Icons.close, color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Distance and Duration
            Row(
              children: [
                Icon(Icons.directions_walk, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  _distanceText ?? 'Calculating...',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(width: 16),
                Icon(Icons.access_time, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  _durationText ?? '...',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Open in Google Maps button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openGoogleMapsNavigation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.navigation),
                label: const Text(
                  'Open in Google Maps',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBusInfoCard() {
    final primaryColor = Theme.of(context).primaryColor;

    return StreamBuilder<BusLocation?>(
      stream: _firestoreService.streamBusLocation(_selectedBusId!),
      builder: (context, snapshot) {
        final bus = snapshot.data;

        if (bus == null) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'Waiting for bus location...',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        // Update tracked bus for map
        _trackedBus = bus;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryColor.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              // Bus Status Icon
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: bus.isActive && !bus.isStale
                      ? Colors.green.withOpacity(0.2)
                      : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.directions_bus,
                  color: bus.isActive && !bus.isStale
                      ? Colors.green
                      : Colors.red,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),

              // Info with ETA
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      bus.busName,
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // ETA to next stop
                    _buildEtaInfo(bus),
                  ],
                ),
              ),

              // Status
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: bus.isActive && !bus.isStale
                      ? Colors.green
                      : Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  bus.isActive && !bus.isStale ? 'LIVE' : 'OFFLINE',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEtaInfo(BusLocation bus) {
    if (bus.routeId == null) {
      return Text(
        '${bus.lastUpdateFormatted}',
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      );
    }

    return StreamBuilder<List<BusRoute>>(
      stream: _firestoreService.streamRoutes(),
      builder: (context, routeSnapshot) {
        final routes = routeSnapshot.data ?? [];
        final route = routes.where((r) => r.routeId == bus.routeId).firstOrNull;

        if (route == null || route.stops.isEmpty) {
          return Text(
            '${bus.lastUpdateFormatted}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          );
        }

        /* 
        // Find nearest stop AHEAD of bus
        // We use bearing to determine if a stop is behind us
        RouteStop? nextStop;
        double minDistance = double.infinity;

        for (final stop in route.stops) {
          final distance = Geolocator.distanceBetween(
            bus.lat,
            bus.lng,
            stop.lat,
            stop.lng,
          );

          // Skip if very close (at stop)
          if (distance < 30) continue;

          // Check direction if bus is moving (speed > 1 m/s)
          // If stopped, we rely purely on distance
          bool isAhead = true;
          if (bus.speed > 1) {
            final bearingToStop = Geolocator.bearingBetween(
              bus.lat,
              bus.lng,
              stop.lat,
              stop.lng,
            );

            // Normalize angle difference to 0-180
            double diff = (bus.bearing - bearingToStop).abs();
            if (diff > 180) diff = 360 - diff;

            // If angle > 100 degrees, it's likely behind or passed
            if (diff > 100) isAhead = false;
          }

          if (isAhead && distance < minDistance) {
            minDistance = distance;
            nextStop = stop;
          }
        }

        if (nextStop == null) {
          // If no stop found ahead, fallback to absolute nearest
          for (final stop in route.stops) {
            final distance = Geolocator.distanceBetween(
              bus.lat,
              bus.lng,
              stop.lat,
              stop.lng,
            );
            if (distance < minDistance) {
              minDistance = distance;
              nextStop = stop;
            }
          }
        }

        if (nextStop == null) {
          return Text(
            'At stop • ${bus.lastUpdateFormatted}',
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          );
        }

        // Calculate ETA based on average bus speed (25 km/h in city)
        final avgSpeedMps = bus.speed > 2 ? bus.speed : 6.9; // ~25 km/h default
        final etaSeconds = minDistance / avgSpeedMps;
        final etaMinutes = (etaSeconds / 60).ceil();

        String etaText;
        if (etaMinutes < 1) {
          etaText = 'Arriving now';
        } else if (etaMinutes == 1) {
          etaText = '~1 min to ${nextStop.name}';
        } else if (etaMinutes < 60) {
          etaText = '~$etaMinutes min to ${nextStop.name}';
        } else {
          final hours = etaMinutes ~/ 60;
          final mins = etaMinutes % 60;
          etaText = '~${hours}h ${mins}m to ${nextStop.name}';
        }

        return Row(
          children: [
            const Icon(Icons.access_time, size: 14, color: Colors.orange),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                etaText,
                style: const TextStyle(color: Colors.orange, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
        */

        // Try to get user location to show ETA to THEIR stop
        return FutureBuilder<Position?>(
          future: Geolocator.getLastKnownPosition(),
          builder: (context, userPosSnapshot) {
            final userPos = userPosSnapshot.data;
            if (userPos != null) {
              return _buildUserToStopEta(bus, route, userPos);
            }
            return _buildBusNextStopEta(bus, route);
          },
        );
      },
    );
  }

  Widget _buildUserToStopEta(
    BusLocation bus,
    BusRoute route,
    Position userPos,
  ) {
    // 1. Find User's nearest stop
    RouteStop? userStop;
    double minUserDist = double.infinity;

    for (final stop in route.stops) {
      final d = Geolocator.distanceBetween(
        userPos.latitude,
        userPos.longitude,
        stop.lat,
        stop.lng,
      );
      if (d < minUserDist) {
        minUserDist = d;
        userStop = stop;
      }
    }

    if (userStop == null) {
      return _buildBusNextStopEta(bus, route); // Fallback
    }

    // 2. Calculate Bus ETA to User's Stop (simple distance/speed)
    final busToStopDist = Geolocator.distanceBetween(
      bus.lat,
      bus.lng,
      userStop.lat,
      userStop.lng,
    );

    // Check if bus has passed (bearing check)
    bool busPassed = false;
    if (bus.speed > 1 && busToStopDist > 50) {
      final bearingToStop = Geolocator.bearingBetween(
        bus.lat,
        bus.lng,
        userStop.lat,
        userStop.lng,
      );
      double diff = (bus.bearing - bearingToStop).abs();
      if (diff > 180) diff = 360 - diff;
      if (diff > 100) busPassed = true;
    }

    // If bus already passed or < 50m away (at stop)
    if (busPassed || busToStopDist < 50) {
      return _buildCatchStatusWidget(
        status: CatchStatus.missed,
        userStop: userStop,
        userEtaMinutes: null,
        busEtaMinutes: 0,
        busPassed: busPassed,
      );
    }

    // Calculate Bus ETA (using speed or default 25km/h)
    final avgSpeedMps = bus.speed > 2 ? bus.speed : 6.9; // ~25 km/h default
    final busEtaMinutes = (busToStopDist / avgSpeedMps / 60).ceil();

    // 3. Calculate User ETA to Stop (using walking speed ~5 km/h = 1.4 m/s)
    // We use simple calculation here to avoid API calls in hot path
    // API call only happens when user presses "Navigate" button
    const walkingSpeedMps = 1.4; // ~5 km/h walking speed
    final userEtaMinutes = (minUserDist / walkingSpeedMps / 60).ceil();

    // 4. Determine Catch Status
    const bufferMinutes = 2;
    CatchStatus status;

    if (busEtaMinutes + bufferMinutes < userEtaMinutes) {
      status = CatchStatus.missed;
    } else if (userEtaMinutes < busEtaMinutes) {
      status = CatchStatus.canCatch;
    } else {
      status = CatchStatus.hurry;
    }

    return _buildCatchStatusWidget(
      status: status,
      userStop: userStop,
      userEtaMinutes: userEtaMinutes,
      busEtaMinutes: busEtaMinutes,
      busPassed: false,
    );
  }

  Widget _buildCatchStatusWidget({
    required CatchStatus status,
    required RouteStop userStop,
    required int? userEtaMinutes,
    required int busEtaMinutes,
    required bool busPassed,
  }) {
    Color statusColor;
    IconData statusIcon;

    switch (status) {
      case CatchStatus.canCatch:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case CatchStatus.hurry:
        statusColor = Colors.orange;
        statusIcon = Icons.warning_amber_rounded;
        break;
      case CatchStatus.missed:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case CatchStatus.unknown:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status row
        Row(
          children: [
            Icon(statusIcon, size: 14, color: statusColor),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                status.message,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        // ETA details
        if (!busPassed && userEtaMinutes != null)
          Text(
            'You: ${userEtaMinutes}m • Bus: ${busEtaMinutes}m • ${userStop.name}',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          )
        else
          Text(
            'Bus passed ${userStop.name}',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _buildBusNextStopEta(BusLocation bus, BusRoute route) {
    RouteStop? nextStop;
    double minDistance = double.infinity;

    for (final stop in route.stops) {
      final distance = Geolocator.distanceBetween(
        bus.lat,
        bus.lng,
        stop.lat,
        stop.lng,
      );

      // Skip if very close (at stop)
      if (distance < 30) continue;

      // Check direction if bus is moving (speed > 1 m/s)
      bool isAhead = true;
      if (bus.speed > 1) {
        final bearingToStop = Geolocator.bearingBetween(
          bus.lat,
          bus.lng,
          stop.lat,
          stop.lng,
        );

        // Normalize angle difference to 0-180
        double diff = (bus.bearing - bearingToStop).abs();
        if (diff > 180) diff = 360 - diff;

        // If angle > 100 degrees, it's likely behind or passed
        if (diff > 100) isAhead = false;
      }

      if (isAhead && distance < minDistance) {
        minDistance = distance;
        nextStop = stop;
      }
    }

    // Fallback logic if direction check fails
    if (nextStop == null) {
      for (final stop in route.stops) {
        final distance = Geolocator.distanceBetween(
          bus.lat,
          bus.lng,
          stop.lat,
          stop.lng,
        );
        if (distance < minDistance) {
          minDistance = distance;
          nextStop = stop;
        }
      }
    }

    if (nextStop == null) {
      return Text(
        'At stop • ${bus.lastUpdateFormatted}',
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      );
    }

    final avgSpeedMps = bus.speed > 2 ? bus.speed : 6.9;
    final etaSeconds = minDistance / avgSpeedMps;
    final etaMinutes = (etaSeconds / 60).ceil();

    return Row(
      children: [
        const Icon(Icons.access_time, size: 14, color: Colors.orange),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '~$etaMinutes min to ${nextStop.name}',
            style: const TextStyle(color: Colors.orange, fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ============================================
  // TAB 2: Driver Details
  // ============================================
  Widget _buildDriverDetailsTab() {
    final primaryColor = Theme.of(context).primaryColor;

    return StreamBuilder<BusLocation?>(
      stream: _firestoreService.streamBusLocation(_selectedBusId!),
      builder: (context, snapshot) {
        final bus = snapshot.data;
        final driverId = bus?.driverId;

        if (driverId == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_off, size: 80, color: Colors.white24),
                const SizedBox(height: 16),
                const Text(
                  'No driver assigned',
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
              ],
            ),
          );
        }

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('drivers') // Changed from 'users' to 'drivers'
              .doc(driverId)
              .snapshots(),
          builder: (context, driverSnapshot) {
            if (!driverSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final driverData =
                driverSnapshot.data?.data() as Map<String, dynamic>?;
            if (driverData == null) {
              return const Center(
                child: Text(
                  'Driver not found',
                  style: TextStyle(color: Colors.white54),
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Driver Avatar
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: primaryColor,
                    child: Text(
                      (driverData['name'] ?? 'D')[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 36,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    driverData['name'] ?? 'Unknown Driver',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    driverData['email'] ?? '',
                    style: const TextStyle(color: Colors.white54),
                  ),

                  // Phone number with call button
                  if (driverData['phone'] != null &&
                      driverData['phone'].toString().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _callDriver(driverData['phone']),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      icon: const Icon(Icons.call),
                      label: Text('Call ${driverData['phone']}'),
                    ),
                  ],

                  const SizedBox(height: 30),

                  // Info Cards
                  _buildInfoCard(
                    Icons.directions_bus,
                    'Assigned Bus',
                    bus?.busName ?? 'N/A',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    Icons.speed,
                    'Current Speed',
                    '${bus?.speedKmh.toStringAsFixed(1) ?? 0} km/h',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    Icons.access_time,
                    'Last Update',
                    bus?.lastUpdateFormatted ?? 'N/A',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    Icons.circle,
                    'Status',
                    bus?.isActive == true && bus?.isStale == false
                        ? 'Active'
                        : 'Inactive',
                    valueColor: bus?.isActive == true && bus?.isStale == false
                        ? Colors.green
                        : Colors.red,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoCard(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: primaryColor, size: 24),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================
  // TAB 3: Report Lost Items
  // ============================================
  Widget _buildLostItemsTab() {
    final primaryColor = Theme.of(context).primaryColor;
    final itemController = TextEditingController();
    final descController = TextEditingController();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Report Lost Item',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Lost something on the bus? Report it here and we\'ll help you find it.',
            style: TextStyle(color: Colors.white54),
          ),
          const SizedBox(height: 24),

          TextField(
            controller: itemController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Item Name',
              hintText: 'e.g., Blue backpack, Phone, Wallet',
              prefixIcon: Icon(Icons.inventory, color: primaryColor),
            ),
          ),
          const SizedBox(height: 16),

          TextField(
            controller: descController,
            style: const TextStyle(color: Colors.white),
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Description',
              hintText: 'Describe the item and where you think you left it...',
              prefixIcon: Icon(Icons.description, color: primaryColor),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () async {
                if (itemController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter item name')),
                  );
                  return;
                }

                await FirebaseFirestore.instance.collection('lost_items').add({
                  'busId': _selectedBusId,
                  'busName': _selectedBusName,
                  'itemName': itemController.text,
                  'description': descController.text,
                  'reportedBy': _authService.currentUser?.uid,
                  'reportedAt': FieldValue.serverTimestamp(),
                  'status': 'pending',
                });

                itemController.clear();
                descController.clear();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Lost item reported! We\'ll contact you if found.',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.send),
              label: const Text(
                'Submit Report',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),

          const SizedBox(height: 40),
          const Divider(color: Colors.white24),
          const SizedBox(height: 20),

          Text(
            'My Previous Reports',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: 12),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('lost_items')
                .where('reportedBy', isEqualTo: _authService.currentUser?.uid)
                .orderBy('reportedAt', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No reports yet',
                    style: TextStyle(color: Colors.white38),
                  ),
                );
              }

              return Column(
                children: snapshot.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'] ?? 'pending';
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E1E1E),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          status == 'found'
                              ? Icons.check_circle
                              : Icons.pending,
                          color: status == 'found'
                              ? Colors.green
                              : Colors.orange,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['itemName'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                data['busName'] ?? '',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: status == 'found'
                                ? Colors.green
                                : Colors.orange,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================
  // TAB 4: Arrival Alarm
  // ============================================
  Widget _buildArrivalAlarmTab() {
    final primaryColor = Theme.of(context).primaryColor;

    // Get route stops for the selected bus
    return StreamBuilder<List<BusRoute>>(
      stream: _firestoreService.streamRoutes(),
      builder: (context, routeSnapshot) {
        List<RouteStop> availableStops = [];
        if (_trackedBus?.routeId != null && routeSnapshot.hasData) {
          final route = routeSnapshot.data!
              .where((r) => r.routeId == _trackedBus!.routeId)
              .firstOrNull;
          if (route != null) {
            availableStops = route.orderedStops;
          }
        }

        return StreamBuilder<BusLocation?>(
          stream: _selectedBusId != null
              ? _firestoreService.streamBusLocation(_selectedBusId!)
              : const Stream.empty(),
          builder: (context, busSnapshot) {
            final bus = busSnapshot.data;

            // Check alarm trigger condition
            // Only trigger if bus is actively tracking (isActive)
            if (_alarmEnabled &&
                _selectedAlarmStop != null &&
                bus != null &&
                bus.isActive && // Bus must be actively tracking
                !_alarmTriggered) {
              final distance = Geolocator.distanceBetween(
                bus.lat,
                bus.lng,
                _selectedAlarmStop!['lat'] as double,
                _selectedAlarmStop!['lng'] as double,
              );

              if (distance <= _alarmDistance) {
                _triggerAlarm();
              }
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Arrival Alarm',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Get notified when your bus is approaching your stop.',
                    style: TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 24),

                  // Alarm Status Indicator
                  _buildAlarmStatusCard(bus, primaryColor),

                  const SizedBox(height: 20),

                  // Stop Selection
                  if (availableStops.isNotEmpty) ...[
                    Text(
                      'Select Your Stop',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedAlarmStop?['stopId'] as String?,
                          hint: const Text(
                            'Choose a stop',
                            style: TextStyle(color: Colors.white54),
                          ),
                          isExpanded: true,
                          dropdownColor: const Color(0xFF2E2E2E),
                          items: availableStops.map((stop) {
                            return DropdownMenuItem<String>(
                              value:
                                  stop.name, // Using name as ID for simplicity
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    color: primaryColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      stop.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                          onChanged: (stopId) async {
                            if (stopId != null) {
                              final stop = availableStops.firstWhere(
                                (s) => s.name == stopId,
                              );
                              await _alarmService.setSelectedStop(
                                stopId: stop.name,
                                stopName: stop.name,
                                lat: stop.lat,
                                lng: stop.lng,
                              );
                              await _loadAlarmSettings();
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Select a bus first to see available stops.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Distance Slider with Human-Friendly Labels
                  Text(
                    'Alert Distance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_alarmDistance}m ${_getDistanceHint(_alarmDistance)}',
                    style: const TextStyle(color: Colors.white54),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: _alarmDistance.toDouble(),
                    min: 100,
                    max: 2000,
                    divisions: 19,
                    activeColor: _alarmEnabled ? primaryColor : Colors.grey,
                    inactiveColor: Colors.white24,
                    label: '${_alarmDistance}m',
                    onChanged: _alarmEnabled
                        ? (value) async {
                            await _alarmService.setAlertDistance(value.toInt());
                            setState(() => _alarmDistance = value.toInt());
                          }
                        : null,
                  ),

                  const SizedBox(height: 30),

                  // Alarm Toggle
                  _buildAlarmToggle(primaryColor),

                  const SizedBox(height: 30),

                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryColor.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.white70),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Keep the app open in background for alarms to work. No GPS tracking needed - only bus location is monitored.',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  String _getDistanceHint(int meters) {
    if (meters <= 200) return '(~30 sec before arrival)';
    if (meters <= 400) return '(~1-2 min before arrival)';
    if (meters <= 600) return '(~2-3 min before arrival)';
    if (meters <= 1000) return '(~3-5 min before arrival)';
    return '(~5+ min before arrival)';
  }

  Widget _buildAlarmStatusCard(BusLocation? bus, Color primaryColor) {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    String statusHint;

    if (_alarmTriggered) {
      statusColor = Colors.red;
      statusIcon = Icons.notifications_active;
      statusText = 'Bus Arriving!';
      final timeStr = _alarmTriggeredAt != null
          ? '${_alarmTriggeredAt!.hour}:${_alarmTriggeredAt!.minute.toString().padLeft(2, '0')}'
          : 'just now';
      statusHint = 'Alarm triggered at $timeStr';
    } else if (!_alarmEnabled) {
      statusColor = Colors.grey;
      statusIcon = Icons.alarm_off;
      statusText = 'Alarm Off';
      statusHint = 'Enable to get notified';
    } else if (_selectedAlarmStop == null) {
      statusColor = Colors.orange;
      statusIcon = Icons.location_off;
      statusText = 'No Stop Selected';
      statusHint = 'Select a stop below';
    } else if (bus == null || !bus.isActive) {
      statusColor = Colors.orange;
      statusIcon = Icons.bus_alert;
      statusText = 'Waiting for Bus';
      statusHint = 'Bus not active yet';
    } else {
      statusColor = Colors.green;
      statusIcon = Icons.alarm_on;
      statusText = 'Alarm Armed';
      statusHint = 'Waiting for bus at ${_selectedAlarmStop!['stopName']}';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor, width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(statusIcon, color: statusColor, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  statusHint,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
          if (_alarmTriggered)
            ElevatedButton.icon(
              onPressed: () async {
                // Stop the alarm sound
                await NotificationAlarmService.stopAlarm();
                // Reset triggered state
                await _alarmService.setAlarmTriggered(false);
                // Also disable alarm to prevent re-triggering
                await _alarmService.setAlarmEnabled(false);
                await _loadAlarmSettings();
              },
              icon: const Icon(Icons.stop, size: 18),
              label: const Text('Stop Alarm'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAlarmToggle(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _alarmEnabled ? primaryColor : Colors.white24,
          width: _alarmEnabled ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _alarmEnabled ? primaryColor : Colors.white12,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.alarm,
              size: 28,
              color: _alarmEnabled ? Colors.black : Colors.white54,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _alarmEnabled ? 'Alarm Enabled' : 'Alarm Disabled',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: _alarmEnabled ? primaryColor : Colors.white,
                  ),
                ),
                Text(
                  _alarmEnabled
                      ? 'You\'ll be alerted when bus is near'
                      : 'Tap switch to enable',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: _alarmEnabled,
            activeColor: primaryColor,
            onChanged: (value) async {
              await _alarmService.setAlarmEnabled(value);
              // Save bus ID for alarm checking
              if (_selectedBusId != null) {
                await _alarmService.setSelectedBus(_selectedBusId!);
              }
              // Request notification permissions when enabling
              if (value) {
                await NotificationAlarmService.requestPermissions();
              }
              await _loadAlarmSettings();
            },
          ),
        ],
      ),
    );
  }

  void _triggerAlarm() async {
    await _alarmService.setAlarmTriggered(true);
    _alarmTriggered = true;
    _alarmTriggeredAt = DateTime.now();

    // Vibrate
    HapticFeedback.vibrate();

    // Show system notification with alarm sound (works in background)
    final stopName = _selectedAlarmStop?['stopName'] ?? 'your stop';
    await NotificationAlarmService.showAlarmNotification(stopName);

    // Also show snackbar if app is in foreground
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.notifications_active, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Bus is arriving at $stopName!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 10),
        ),
      );
      setState(() {});
    }
  }

  // ============================================
  // Bus Selection Screen (Route First, Then Bus)
  // ============================================
  Widget _buildBusSelectionScreen() {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectedRouteId == null ? 'Select Your Route' : 'Select Bus',
          style: const TextStyle(color: Colors.white),
        ),
        leading: _selectedRouteId != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _selectedRouteId = null;
                  _selectedRouteName = null;
                }),
              )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await _authService.signOut();
              if (context.mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Step indicator
              Row(
                children: [
                  _buildStepIndicator(1, 'Route', _selectedRouteId == null),
                  const Expanded(child: Divider(color: Colors.white24)),
                  _buildStepIndicator(2, 'Bus', _selectedRouteId != null),
                ],
              ),
              const SizedBox(height: 24),

              if (_selectedRouteId == null) ...[
                // STEP 1: Route Selection
                Text(
                  'Choose Your Route',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Select the route your bus travels on',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: _availableRoutes.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                          itemCount: _availableRoutes.length,
                          itemBuilder: (context, index) {
                            final route = _availableRoutes[index];
                            return _buildRouteCard(
                              route['id']!,
                              route['name']!,
                            );
                          },
                        ),
                ),
              ] else ...[
                // STEP 2: Bus Selection (filtered by route)
                Text(
                  'Select Bus on $_selectedRouteName',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose the specific bus you travel on',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 20),
                Expanded(child: _buildBusListForRoute(_selectedRouteId!)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, bool isActive) {
    final primaryColor = Theme.of(context).primaryColor;
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isActive ? primaryColor : Colors.grey[800],
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$step',
              style: TextStyle(
                color: isActive ? Colors.black : Colors.white54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive ? primaryColor : Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildRouteCard(String id, String name) {
    final primaryColor = Theme.of(context).primaryColor;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedRouteId = id;
        _selectedRouteName = name;
      }),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.route, color: primaryColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: primaryColor, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildBusListForRoute(String routeId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('buses')
          .where('routeId', isEqualTo: routeId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final buses = snapshot.data!.docs;
        if (buses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bus_alert, size: 60, color: Colors.white38),
                const SizedBox(height: 16),
                const Text(
                  'No buses on this route',
                  style: TextStyle(color: Colors.white54),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => setState(() {
                    _selectedRouteId = null;
                    _selectedRouteName = null;
                  }),
                  child: const Text('Select Different Route'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: buses.length,
          itemBuilder: (context, index) {
            final bus = buses[index];
            final busData = bus.data() as Map<String, dynamic>;
            return _buildBusCard(bus.id, busData['name'] ?? 'Unknown Bus');
          },
        );
      },
    );
  }

  Widget _buildBusCard(String id, String name) {
    final primaryColor = Theme.of(context).primaryColor;

    return GestureDetector(
      onTap: () => _selectBus(id, name),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.directions_bus, color: primaryColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: primaryColor, size: 18),
          ],
        ),
      ),
    );
  }
}
