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

              // Info
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
                    Text(
                      '${bus.speedKmh.toStringAsFixed(1)} km/h • ${bus.lastUpdateFormatted}',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
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

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(_authService.currentUser?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final alarmEnabled = userData['arrivalAlarmEnabled'] ?? false;
        final alarmDistance = (userData['arrivalAlarmDistance'] ?? 500)
            .toDouble();

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
              const SizedBox(height: 30),

              // Alarm Toggle
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: alarmEnabled ? primaryColor : Colors.white24,
                    width: alarmEnabled ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: alarmEnabled ? primaryColor : Colors.white12,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        Icons.alarm,
                        size: 32,
                        color: alarmEnabled ? Colors.black : Colors.white54,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alarmEnabled ? 'Alarm Active' : 'Alarm Off',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: alarmEnabled ? primaryColor : Colors.white,
                            ),
                          ),
                          Text(
                            alarmEnabled
                                ? 'You\'ll be notified when bus is near'
                                : 'Enable to get arrival notifications',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: alarmEnabled,
                      activeColor: primaryColor,
                      onChanged: (value) {
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(_authService.currentUser?.uid)
                            .update({'arrivalAlarmEnabled': value});
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Distance Slider
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
                'Get notified when bus is within ${alarmDistance.toInt()} meters',
                style: const TextStyle(color: Colors.white54),
              ),
              const SizedBox(height: 16),
              Slider(
                value: alarmDistance,
                min: 100,
                max: 2000,
                divisions: 19,
                activeColor: primaryColor,
                label: '${alarmDistance.toInt()}m',
                onChanged: alarmEnabled
                    ? (value) {
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(_authService.currentUser?.uid)
                            .update({'arrivalAlarmDistance': value.toInt()});
                      }
                    : null,
              ),

              const SizedBox(height: 40),

              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: primaryColor),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Make sure location permissions are enabled and the app is running in background for alarms to work.',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
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
