import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

/// MapStopPicker - Allows admin to pick multiple stops on map for a bus route.
/// Returns a list of stops when confirmed.
class MapStopPicker extends StatefulWidget {
  final String routeName;
  final int stopNumber;
  final List<Map<String, dynamic>> existingStops;

  const MapStopPicker({
    super.key,
    required this.routeName,
    this.stopNumber = 1,
    this.existingStops = const [],
  });

  @override
  State<MapStopPicker> createState() => _MapStopPickerState();
}

class _MapStopPickerState extends State<MapStopPicker> {
  GoogleMapController? _mapController;
  late List<Map<String, dynamic>> _stops;
  LatLng? _pendingLocation;
  final TextEditingController _nameController = TextEditingController();

  static const LatLng _defaultCenter = LatLng(13.0827, 80.2707);

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
  void initState() {
    super.initState();
    // Initialize with existing stops
    _stops = List.from(widget.existingStops);
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _mapController?.animateCamera(
        CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Stops to ${widget.routeName}'),
        backgroundColor: Colors.transparent,
        foregroundColor: primaryColor,
        actions: [
          if (_stops.isNotEmpty)
            TextButton.icon(
              onPressed: _confirmAllStops,
              icon: Icon(Icons.check, color: primaryColor),
              label: Text(
                'Done (${_stops.length})',
                style: TextStyle(color: primaryColor),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: _defaultCenter,
              zoom: 14,
            ),
            onMapCreated: (controller) {
              _mapController = controller;
              controller.setMapStyle(_darkMapStyle);
            },
            onTap: _onMapTap,
            markers: _buildMarkers(),
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
          ),

          // Instructions
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
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.touch_app, color: primaryColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Tap on map to add stops',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${_stops.length} stops added',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.my_location, color: primaryColor),
                    onPressed: _getCurrentLocation,
                  ),
                ],
              ),
            ),
          ),

          // Added stops list
          if (_stops.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 200),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                  border: Border.all(color: Colors.white10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Text(
                            'Added Stops',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: primaryColor,
                            ),
                          ),
                          const Spacer(),
                          ElevatedButton.icon(
                            onPressed: _confirmAllStops,
                            icon: const Icon(Icons.check, size: 18),
                            label: const Text('Save All'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: ReorderableListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _stops.length,
                        onReorder: (oldIndex, newIndex) {
                          setState(() {
                            if (newIndex > oldIndex) newIndex--;
                            final item = _stops.removeAt(oldIndex);
                            _stops.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, index) {
                          final stop = _stops[index];
                          return ListTile(
                            key: ValueKey('stop_$index'),
                            dense: true,
                            leading: CircleAvatar(
                              radius: 14,
                              backgroundColor: primaryColor,
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              stop['name'] as String,
                              style: const TextStyle(color: Colors.white),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ReorderableDragStartListener(
                                  index: index,
                                  child: Icon(
                                    Icons.drag_handle,
                                    color: Colors.white54,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, size: 20),
                                  color: Colors.red,
                                  onPressed: () => _removeStop(index),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    for (int i = 0; i < _stops.length; i++) {
      final stop = _stops[i];
      markers.add(
        Marker(
          markerId: MarkerId('stop_$i'),
          position: LatLng(stop['lat'] as double, stop['lng'] as double),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(title: '${i + 1}. ${stop['name']}'),
        ),
      );
    }

    if (_pendingLocation != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('pending'),
          position: _pendingLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );
    }

    return markers;
  }

  void _onMapTap(LatLng position) {
    setState(() => _pendingLocation = position);
    _showAddStopDialog(position);
  }

  void _showAddStopDialog(LatLng position) {
    _nameController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Stop #${widget.stopNumber + _stops.length}',
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Stop Name',
                hintText: 'e.g., Main Gate, Library...',
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Lat: ${position.latitude.toStringAsFixed(5)}, Lng: ${position.longitude.toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _pendingLocation = null);
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              if (_nameController.text.trim().isNotEmpty) {
                setState(() {
                  _stops.add({
                    'name': _nameController.text.trim(),
                    'lat': position.latitude,
                    'lng': position.longitude,
                  });
                  _pendingLocation = null;
                });
                Navigator.pop(context);
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Stop'),
          ),
        ],
      ),
    );
  }

  void _removeStop(int index) {
    setState(() => _stops.removeAt(index));
  }

  void _confirmAllStops() {
    if (_stops.isEmpty) return;
    Navigator.pop(context, _stops);
  }
}
