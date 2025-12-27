import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/location_service.dart';
import '../services/foreground_task_service.dart';

/// DriverScreen - Main screen for bus drivers.
/// Handles trip start/stop, location tracking, and foreground service.
class DriverScreen extends StatefulWidget {
  const DriverScreen({super.key});

  @override
  State<DriverScreen> createState() => _DriverScreenState();
}

class _DriverScreenState extends State<DriverScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final LocationService _locationService = LocationService();

  bool _isTripActive = false;
  bool _isLoading = false;
  Position? _currentPosition;
  String? _selectedBusId;
  String? _selectedBusName;
  List<Map<String, String>> _availableBuses = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadBuses();
    await _loadUserData();
    await _checkExistingTrip();
    await _getCurrentLocation();
  }

  Future<void> _loadBuses() async {
    final buses = await _firestoreService.getAvailableBuses();
    setState(() {
      _availableBuses = buses;
    });
  }

  Future<void> _loadUserData() async {
    final user = await _authService.getCurrentUserProfile();
    if (user != null && mounted) {
      setState(() {
        if (user.busId != null) {
          _selectedBusId = user.busId;
          // Find bus name
          final bus = _availableBuses.firstWhere(
            (b) => b['id'] == user.busId,
            orElse: () => {'id': user.busId!, 'name': 'Bus ${user.busId}'},
          );
          _selectedBusName = bus['name'];
        }
      });
    }
  }

  Future<void> _checkExistingTrip() async {
    final isRunning = await FlutterForegroundTask.isRunningService;
    if (isRunning && mounted) {
      setState(() {
        _isTripActive = true;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    final position = await _locationService.getCurrentLocation();
    if (position != null && mounted) {
      setState(() {
        _currentPosition = position;
      });
    }
  }

  Future<void> _startTrip() async {
    if (_selectedBusId == null || _selectedBusName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a bus first')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Request location permission
      final hasPermission = await _locationService
          .requestBackgroundLocationPermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required for tracking'),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: Geolocator.openAppSettings,
              ),
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Get current position for initial location
      final position = await _locationService.getCurrentLocation();
      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not get current location')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      // Save data for foreground service
      await FlutterForegroundTask.saveData(
        key: 'busId',
        value: _selectedBusId!,
      );
      await FlutterForegroundTask.saveData(
        key: 'driverId',
        value: _authService.currentUser!.uid,
      );

      // Start trip in Firestore
      await _firestoreService.startTrip(
        busId: _selectedBusId!,
        busName: _selectedBusName!,
        driverId: _authService.currentUser!.uid,
        lat: position.latitude,
        lng: position.longitude,
      );

      // Start foreground service
      await ForegroundTaskService.startService(
        busId: _selectedBusId!,
        driverId: _authService.currentUser!.uid,
      );

      // Update user's assigned bus
      await _authService.updateUserBus(_selectedBusId!);

      if (mounted) {
        setState(() {
          _isTripActive = true;
          _currentPosition = position;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip started! Your location is now being shared.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error starting trip: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _stopTrip() async {
    setState(() => _isLoading = true);

    try {
      // Stop foreground service
      await ForegroundTaskService.stopService();

      // Update Firestore
      if (_selectedBusId != null) {
        await _firestoreService.stopTrip(_selectedBusId!);
      }

      if (mounted) {
        setState(() {
          _isTripActive = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Trip stopped. Location sharing disabled.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error stopping trip: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return WithForegroundTask(
      child: Scaffold(
        // Background color from theme (Black)
        appBar: AppBar(
          title: const Text('Driver Mode'),
          backgroundColor: Colors.transparent,
          foregroundColor: primaryColor,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              onPressed: () async {
                if (_isTripActive) {
                  await _stopTrip();
                }
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
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Card
                      _buildStatusCard(),
                      const SizedBox(height: 24),

                      // Bus Selection
                      if (!_isTripActive) ...[
                        const Text(
                          'Select Your Bus',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E1E), // Dark Grey
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: primaryColor.withOpacity(0.3),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedBusId,
                              isExpanded: true,
                              hint: const Text(
                                'Choose a bus',
                                style: TextStyle(color: Colors.white70),
                              ),
                              dropdownColor: const Color(0xFF1E1E1E),
                              icon: Icon(
                                Icons.arrow_drop_down,
                                color: primaryColor,
                              ),
                              items: _availableBuses.map((bus) {
                                return DropdownMenuItem<String>(
                                  value: bus['id'],
                                  child: Text(
                                    bus['name']!,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                final bus = _availableBuses.firstWhere(
                                  (b) => b['id'] == value,
                                );
                                setState(() {
                                  _selectedBusId = value;
                                  _selectedBusName = bus['name'];
                                });
                              },
                            ),
                          ),
                        ),
                      ],

                      // Current Location
                      if (_currentPosition != null || _isTripActive) ...[
                        const SizedBox(height: 24),
                        _buildLocationCard(),
                      ],
                    ],
                  ),
                ),
              ),

              // Trip Control Button (fixed at bottom)
              Padding(
                padding: const EdgeInsets.all(20),
                child: _buildTripButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isTripActive ? Colors.green : Colors.grey.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: (_isTripActive ? Colors.green : Colors.black).withOpacity(
              0.2,
            ),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _isTripActive
                  ? Colors.green.withOpacity(0.2)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              _isTripActive ? Icons.location_on : Icons.location_off,
              size: 32,
              color: _isTripActive ? Colors.green : Colors.grey,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isTripActive ? 'Trip Active' : 'Trip Inactive',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isTripActive
                      ? 'Sharing location with students'
                      : 'Start a trip to begin tracking',
                  style: const TextStyle(fontSize: 14, color: Colors.white70),
                ),
                if (_selectedBusName != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      _selectedBusName!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_isTripActive)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.broadcast_on_personal,
                color: Colors.green,
                size: 24,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    // When trip is active, show real-time location from Firestore
    if (_isTripActive && _selectedBusId != null) {
      return StreamBuilder(
        stream: _firestoreService.streamBusLocation(_selectedBusId!),
        builder: (context, snapshot) {
          final busData = snapshot.data;

          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E), // Dark Grey
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.my_location,
                        color: Colors.green,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Live Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A5F),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'LIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (busData != null) ...[
                  _buildLocationRow('Latitude', busData.lat.toStringAsFixed(6)),
                  _buildLocationRow(
                    'Longitude',
                    busData.lng.toStringAsFixed(6),
                  ),
                  _buildLocationRow(
                    'Speed',
                    '${busData.speedKmh.toStringAsFixed(1)} km/h',
                  ),
                  _buildLocationRow('Last Update', busData.lastUpdateFormatted),
                ] else ...[
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          );
        },
      );
    }

    // When trip is NOT active, show static location
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.my_location, color: Color(0xFF1E3A5F)),
              const SizedBox(width: 10),
              const Text(
                'Current Location',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A5F),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: _getCurrentLocation,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            'Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          if (_currentPosition!.speed > 0)
            Text(
              'Speed: ${(_currentPosition!.speed * 3.6).toStringAsFixed(1)} km/h',
              style: TextStyle(color: Colors.grey[600]),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E3A5F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripButton() {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: ElevatedButton(
        onPressed: _isLoading ? null : (_isTripActive ? _stopTrip : _startTrip),
        style: ElevatedButton.styleFrom(
          backgroundColor: _isTripActive ? Colors.red : const Color(0xFF4CAF50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 5,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isTripActive ? Icons.stop : Icons.play_arrow, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    _isTripActive ? 'Stop Trip' : 'Start Trip',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
