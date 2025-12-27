import 'dart:convert';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// DirectionService - Fetches walking directions from Google Directions API
class DirectionService {
  // Using the same API key as Google Maps
  static const String _apiKey = 'AIzaSyAEystrkiyrrbO0GWxphvGnvBBIyAlfn_Q';

  /// Fetch walking path between two points
  /// Returns a list of LatLng points representing the walking route
  Future<List<LatLng>> fetchWalkingPath(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=walking'
        '&key=$_apiKey',
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch directions: ${response.statusCode}');
      }

      final data = json.decode(response.body);

      if (data['status'] != 'OK') {
        throw Exception('Directions API error: ${data['status']}');
      }

      final routes = data['routes'] as List;
      if (routes.isEmpty) {
        return [];
      }

      final polyline = routes[0]['overview_polyline']['points'] as String;
      return _decodePolyline(polyline);
    } catch (e) {
      // Return empty list on error - will just show markers without path
      return [];
    }
  }

  /// Get distance and duration between two points
  Future<Map<String, dynamic>> getDistanceInfo(
    LatLng origin,
    LatLng destination,
  ) async {
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=walking'
        '&key=$_apiKey',
      );

      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK') {
        final leg = data['routes'][0]['legs'][0];
        return {
          'distance': leg['distance']['text'],
          'distanceMeters': leg['distance']['value'],
          'duration': leg['duration']['text'],
        };
      }
    } catch (_) {}

    return {'distance': 'Unknown', 'distanceMeters': 0, 'duration': 'Unknown'};
  }

  /// Decode Google's encoded polyline to list of LatLng points
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      shift = 0;
      result = 0;

      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      lng += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return points;
  }
}
