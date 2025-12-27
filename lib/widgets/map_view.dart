import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/bus_location.dart';

/// BusMapView - Google Maps widget with real-time bus markers.
/// Handles marker animation, camera follow, and bus selection.
class BusMapView extends StatefulWidget {
  final List<BusLocation> buses;
  final String? selectedBusId;
  final bool cameraFollow;
  final Function(String) onBusSelected;

  const BusMapView({
    super.key,
    required this.buses,
    this.selectedBusId,
    this.cameraFollow = true,
    required this.onBusSelected,
  });

  @override
  State<BusMapView> createState() => _BusMapViewState();
}

class _BusMapViewState extends State<BusMapView> with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  final Map<String, LatLng> _previousPositions = {};
  final Map<String, AnimationController> _animationControllers = {};
  final Map<String, LatLng> _animatedPositions = {};
  bool _hasCenteredOnBus = false;
  bool _mapReady = false;

  // Cache for custom markers with bus numbers
  final Map<String, BitmapDescriptor> _busMarkerCache = {};

  // Default center - Chennai area
  static const LatLng _defaultCenter = LatLng(13.0827, 80.2707);
  static const double _defaultZoom = 15.0;

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
    _createBusMarkers();
  }

  /// Create custom markers with bus numbers for all buses
  Future<void> _createBusMarkers() async {
    for (final bus in widget.buses) {
      await _getOrCreateMarker(bus);
    }
    if (mounted) setState(() {});
  }

  /// Get or create a cached marker for a bus
  Future<BitmapDescriptor> _getOrCreateMarker(BusLocation bus) async {
    final cacheKey = '${bus.busId}_${bus.isActive}_${bus.isStale}';

    if (_busMarkerCache.containsKey(cacheKey)) {
      return _busMarkerCache[cacheKey]!;
    }

    // Determine color based on bus state
    Color bgColor;
    if (bus.isActive && !bus.isStale) {
      bgColor = const Color(0xFF4CAF50); // Green - active
    } else if (bus.isStale) {
      bgColor = const Color(0xFFFF9800); // Orange - stale
    } else {
      bgColor = const Color(0xFFE53935); // Red - inactive
    }

    // Extract bus number from name (e.g., "Bus 1" -> "1", "Bus 10" -> "10")
    String busNumber = bus.busName.replaceAll(RegExp(r'[^0-9]'), '');
    if (busNumber.isEmpty) {
      busNumber = bus.busName.substring(0, 2).toUpperCase();
    }

    final marker = await _createTextMarker(busNumber, bgColor);
    _busMarkerCache[cacheKey] = marker;
    return marker;
  }

  /// Create a bitmap marker with text
  Future<BitmapDescriptor> _createTextMarker(String text, Color bgColor) async {
    const double size = 100;
    const double fontSize = 40;

    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint bgPaint = Paint()..color = bgColor;
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    // Draw circle background
    canvas.drawCircle(const Offset(size / 2, size / 2), size / 2 - 4, bgPaint);
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2 - 4,
      borderPaint,
    );

    // Draw text
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset((size - textPainter.width) / 2, (size - textPainter.height) / 2),
    );

    final img = await pictureRecorder.endRecording().toImage(
      size.toInt(),
      size.toInt(),
    );
    final data = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.bytes(data!.buffer.asUint8List());
  }

  @override
  void didUpdateWidget(BusMapView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Create markers for new buses
    for (final bus in widget.buses) {
      _getOrCreateMarker(bus);
    }

    // Animate markers when bus positions change
    for (final bus in widget.buses) {
      final oldPosition = _previousPositions[bus.busId];
      final newPosition = LatLng(bus.lat, bus.lng);

      if (oldPosition != null && oldPosition != newPosition) {
        _animateMarker(bus.busId, oldPosition, newPosition);
      }
      _previousPositions[bus.busId] = newPosition;
    }

    // Follow selected bus
    if (widget.cameraFollow && widget.selectedBusId != null && _mapReady) {
      final selectedBus = widget.buses
          .where((b) => b.busId == widget.selectedBusId)
          .firstOrNull;
      if (selectedBus != null) {
        _moveCameraTo(LatLng(selectedBus.lat, selectedBus.lng));
      }
    }
  }

  void _animateMarker(String busId, LatLng from, LatLng to) {
    _animationControllers[busId]?.dispose();

    final controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    final animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));

    animation.addListener(() {
      if (mounted) {
        setState(() {
          _animatedPositions[busId] = LatLng(
            from.latitude + (to.latitude - from.latitude) * animation.value,
            from.longitude + (to.longitude - from.longitude) * animation.value,
          );
        });
      }
    });

    _animationControllers[busId] = controller;
    controller.forward();
  }

  void _moveCameraTo(LatLng position) {
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(position, _defaultZoom),
    );
  }

  Set<Marker> _buildMarkers() {
    return widget.buses.map((bus) {
      final position =
          _animatedPositions[bus.busId] ?? LatLng(bus.lat, bus.lng);
      final cacheKey = '${bus.busId}_${bus.isActive}_${bus.isStale}';
      final icon = _busMarkerCache[cacheKey] ?? BitmapDescriptor.defaultMarker;

      return Marker(
        markerId: MarkerId(bus.busId),
        position: position,
        rotation: bus.bearing,
        anchor: const Offset(0.5, 0.5),
        infoWindow: InfoWindow(
          title: bus.busName,
          snippet:
              '${bus.speedKmh.toStringAsFixed(1)} km/h • ${bus.lastUpdateFormatted}',
        ),
        icon: icon,
        onTap: () => widget.onBusSelected(bus.busId),
      );
    }).toSet();
  }

  @override
  void dispose() {
    for (final controller in _animationControllers.values) {
      controller.dispose();
    }
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine initial camera position
    LatLng initialPosition = _defaultCenter;
    if (widget.buses.isNotEmpty) {
      final firstBus = widget.buses.first;
      initialPosition = LatLng(firstBus.lat, firstBus.lng);
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: initialPosition,
        zoom: _defaultZoom,
      ),
      onMapCreated: (controller) {
        _mapController = controller;
        _mapReady = true;

        // Apply dark mode style
        controller.setMapStyle(_darkMapStyle);

        // Immediately move to bus if available
        if (widget.buses.isNotEmpty) {
          final firstBus = widget.buses.first;
          Future.delayed(const Duration(milliseconds: 300), () {
            _moveCameraTo(LatLng(firstBus.lat, firstBus.lng));
            _hasCenteredOnBus = true;
          });
        }
      },
      markers: _buildMarkers(),
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: true,
      buildingsEnabled: true,
      trafficEnabled: false,
      minMaxZoomPreference: const MinMaxZoomPreference(10, 18),
    );
  }
}
