import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../services/firestore_service.dart';
import '../../models/bus_location.dart';

/// Admin Map Screen - Live view of all buses for administrators
class AdminMapScreen extends StatefulWidget {
  const AdminMapScreen({super.key});

  @override
  State<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends State<AdminMapScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  GoogleMapController? _mapController;
  BusLocation? _selectedBus;

  static const LatLng _defaultCenter = LatLng(13.0827, 80.2707); // Chennai

  // Dark mode map style
  static const String _darkMapStyle = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#212121"}]},
  {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#212121"}]},
  {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#757575"}]},
  {"featureType": "administrative.country", "elementType": "labels.text.fill", "stylers": [{"color": "#9e9e9e"}]},
  {"featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#bdbdbd"}]},
  {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#181818"}]},
  {"featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{"color": "#616161"}]},
  {"featureType": "road", "elementType": "geometry.fill", "stylers": [{"color": "#2c2c2c"}]},
  {"featureType": "road", "elementType": "labels.text.fill", "stylers": [{"color": "#8a8a8a"}]},
  {"featureType": "road.arterial", "elementType": "geometry", "stylers": [{"color": "#373737"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#3c3c3c"}]},
  {"featureType": "road.highway.controlled_access", "elementType": "geometry", "stylers": [{"color": "#4e4e4e"}]},
  {"featureType": "road.local", "elementType": "labels.text.fill", "stylers": [{"color": "#616161"}]},
  {"featureType": "transit", "elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#000000"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#3d3d3d"}]}
]
''';

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Bus Tracking'),
        backgroundColor: Colors.transparent,
        foregroundColor: primaryColor,
      ),
      body: StreamBuilder<List<BusLocation>>(
        stream: _firestoreService.streamAllBuses(),
        builder: (context, snapshot) {
          final buses = snapshot.data ?? [];
          final activeBuses = buses.where((b) => b.isActive).toList();

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: const CameraPosition(
                  target: _defaultCenter,
                  zoom: 12,
                ),
                onMapCreated: (controller) {
                  _mapController = controller;
                  controller.setMapStyle(_darkMapStyle);
                  if (activeBuses.isNotEmpty) {
                    _fitBounds(activeBuses);
                  }
                },
                markers: _buildMarkers(buses),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: true,
              ),

              // Stats bar at top
              Positioned(
                top: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatChip(
                        Icons.directions_bus,
                        '${activeBuses.length} Active',
                        Colors.green,
                      ),
                      _buildStatChip(
                        Icons.bus_alert,
                        '${buses.length - activeBuses.length} Inactive',
                        Colors.grey,
                      ),
                    ],
                  ),
                ),
              ),

              if (_selectedBus != null)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: _buildBusInfoCard(_selectedBus!),
                ),
            ],
          );
        },
      ),
    );
  }

  Set<Marker> _buildMarkers(List<BusLocation> buses) {
    return buses.map((bus) {
      return Marker(
        markerId: MarkerId(bus.busId),
        position: LatLng(bus.lat, bus.lng),
        rotation: bus.bearing,
        icon: BitmapDescriptor.defaultMarkerWithHue(
          bus.isActive
              ? (bus.isStale
                    ? BitmapDescriptor.hueOrange
                    : BitmapDescriptor.hueGreen)
              : BitmapDescriptor.hueRed,
        ),
        infoWindow: InfoWindow(
          title: bus.busName,
          snippet: bus.isActive ? 'Active' : 'Inactive',
        ),
        onTap: () => setState(() => _selectedBus = bus),
      );
    }).toSet();
  }

  Widget _buildStatChip(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildBusInfoCard(BusLocation bus) {
    final primaryColor = Theme.of(context).primaryColor;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bus.isActive
                  ? Colors.green.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.directions_bus,
              color: bus.isActive ? Colors.green : Colors.grey,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  bus.busName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  bus.isActive
                      ? 'Speed: ${bus.speedKmh.toStringAsFixed(1)} km/h'
                      : 'Inactive',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => setState(() => _selectedBus = null),
          ),
        ],
      ),
    );
  }

  void _fitBounds(List<BusLocation> buses) {
    if (buses.isEmpty || _mapController == null) return;

    double minLat = buses.first.lat;
    double maxLat = buses.first.lat;
    double minLng = buses.first.lng;
    double maxLng = buses.first.lng;

    for (final bus in buses) {
      if (bus.lat < minLat) minLat = bus.lat;
      if (bus.lat > maxLat) maxLat = bus.lat;
      if (bus.lng < minLng) minLng = bus.lng;
      if (bus.lng > maxLng) maxLng = bus.lng;
    }

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        50,
      ),
    );
  }
}
