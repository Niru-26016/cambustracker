import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/route_model.dart';
import 'map_stop_picker.dart';

/// Manage Routes Screen - CRUD operations for routes
class ManageRoutesScreen extends StatefulWidget {
  const ManageRoutesScreen({super.key});

  @override
  State<ManageRoutesScreen> createState() => _ManageRoutesScreenState();
}

class _ManageRoutesScreenState extends State<ManageRoutesScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Routes'),
        backgroundColor: Colors.transparent,
        foregroundColor: primaryColor,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddRouteDialog(),
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: StreamBuilder<List<BusRoute>>(
        stream: _firestoreService.streamRoutes(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          final routes = snapshot.data ?? [];

          if (routes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.route_outlined, size: 80, color: Colors.grey[800]),
                  const SizedBox(height: 16),
                  Text(
                    'No routes yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to add a route',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: routes.length,
            itemBuilder: (context, index) {
              final route = routes[index];
              return _buildRouteCard(route);
            },
          );
        },
      ),
    );
  }

  Widget _buildRouteCard(BusRoute route) {
    final primaryColor = Theme.of(context).primaryColor;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      child: ExpansionTile(
        iconColor: primaryColor,
        collapsedIconColor: Colors.white70,
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(Icons.route, color: primaryColor),
        ),
        title: Text(
          route.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        subtitle: Text(
          '${route.stopCount} stops',
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white70),
          color: const Color(0xFF1E1E1E),
          onSelected: (value) {
            if (value == 'delete') {
              _confirmDelete(route);
            } else if (value == 'editStops') {
              _showEditStopsMap(route);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'editStops',
              child: Row(
                children: [
                  Icon(Icons.edit_location_alt, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Text('Edit Stops', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
        children: [
          if (route.stops.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: route.stops.length,
              itemBuilder: (context, index) {
                final stop = route.stops[index];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 12,
                    backgroundColor: primaryColor,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(fontSize: 12, color: Colors.black),
                    ),
                  ),
                  title: Text(
                    stop.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _showAddRouteDialog() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Add New Route',
          style: TextStyle(color: Colors.white),
        ),
        content: TextField(
          controller: nameController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Route Name',
            hintText: 'e.g., Campus Loop',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                Navigator.pop(context);
                // Navigate to map picker to add stops
                final stops = await Navigator.push<List<Map<String, dynamic>>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MapStopPicker(
                      routeName: nameController.text,
                      stopNumber: 1,
                    ),
                  ),
                );

                // Create route with stops
                final routeStops = (stops ?? []).asMap().entries.map((entry) {
                  final stop = entry.value;
                  return RouteStop(
                    name: stop['name'] as String,
                    lat: stop['lat'] as double,
                    lng: stop['lng'] as double,
                    order: entry.key + 1,
                  );
                }).toList();

                final route = BusRoute(
                  routeId: '',
                  name: nameController.text,
                  stops: routeStops,
                  createdAt: DateTime.now(),
                );
                await _firestoreService.saveRoute(route);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Route "${nameController.text}" created with ${routeStops.length} stops',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            icon: const Icon(Icons.map),
            label: const Text('Add Stops'),
          ),
        ],
      ),
    );
  }

  void _showEditStopsMap(BusRoute route) async {
    // Convert existing stops to map format for the picker
    final existingStops = route.stops
        .map((stop) => {'name': stop.name, 'lat': stop.lat, 'lng': stop.lng})
        .toList();

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            MapStopPicker(routeName: route.name, existingStops: existingStops),
      ),
    );

    if (result != null && result is List) {
      // Replace all stops with new list
      final newStops = (result as List)
          .asMap()
          .entries
          .map(
            (entry) => RouteStop(
              name: entry.value['name'] as String,
              lat: entry.value['lat'] as double,
              lng: entry.value['lng'] as double,
              order: entry.key + 1,
            ),
          )
          .toList();

      final updatedRoute = BusRoute(
        routeId: route.routeId,
        name: route.name,
        stops: newStops,
        createdAt: route.createdAt,
      );
      await _firestoreService.saveRoute(updatedRoute);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${route.name} updated with ${newStops.length} stops',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _confirmDelete(BusRoute route) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Delete Route?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete ${route.name}?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await _firestoreService.deleteRoute(route.routeId);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
