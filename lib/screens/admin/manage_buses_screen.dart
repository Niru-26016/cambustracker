import 'package:flutter/material.dart';
import '../../services/firestore_service.dart';
import '../../models/bus_location.dart';
import '../../models/route_model.dart';
import '../../models/driver_model.dart';
import 'bulk_import_screen.dart';

/// Manage Buses Screen - CRUD operations for buses
class ManageBusesScreen extends StatefulWidget {
  const ManageBusesScreen({super.key});

  @override
  State<ManageBusesScreen> createState() => _ManageBusesScreenState();
}

class _ManageBusesScreenState extends State<ManageBusesScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final Map<String, String> _routeNameCache = {};
  final Map<String, String> _driverNameCache = {};

  Future<String> _getRouteName(String routeId) async {
    if (_routeNameCache.containsKey(routeId)) {
      return _routeNameCache[routeId]!;
    }
    final routes = await _firestoreService.streamRoutes().first;
    final route = routes.where((r) => r.routeId == routeId).firstOrNull;
    final name = route?.name ?? routeId;
    _routeNameCache[routeId] = name;
    return name;
  }

  Future<String?> _getDriverForBus(String busId) async {
    if (_driverNameCache.containsKey(busId)) {
      return _driverNameCache[busId];
    }
    final drivers = await _firestoreService.getDrivers();
    final driver = drivers.where((d) => d.assignedBusId == busId).firstOrNull;
    if (driver != null) {
      _driverNameCache[busId] = driver.name;
      return driver.name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Buses'),
        backgroundColor: Colors.transparent,
        foregroundColor: primaryColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            tooltip: 'Bulk Import',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      const BulkImportScreen(importType: ImportType.buses),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddBusDialog(),
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: StreamBuilder<List<BusLocation>>(
        stream: _firestoreService.streamAllBuses(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          final buses = snapshot.data ?? [];

          if (buses.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.directions_bus_outlined,
                    size: 80,
                    color: Colors.grey[800],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No buses yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to add a bus',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: buses.length,
            itemBuilder: (context, index) {
              final bus = buses[index];
              return _buildBusCard(bus);
            },
          );
        },
      ),
    );
  }

  Widget _buildBusCard(BusLocation bus) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
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
          ),
        ),
        title: Text(
          bus.busName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bus.isActive ? 'Active' : 'Inactive',
              style: TextStyle(
                color: bus.isActive ? Colors.green : Colors.grey,
              ),
            ),
            if (bus.routeId != null && bus.routeId!.isNotEmpty)
              FutureBuilder<String>(
                future: _getRouteName(bus.routeId!),
                builder: (context, snapshot) {
                  return Text(
                    'Route: ${snapshot.data ?? '...'}',
                    style: const TextStyle(fontSize: 12, color: Colors.orange),
                  );
                },
              ),
            FutureBuilder<String?>(
              future: _getDriverForBus(bus.busId),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Row(
                    children: [
                      const Icon(Icons.person, size: 14, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        snapshot.data!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  );
                }
                return const Text(
                  'No driver assigned',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                );
              },
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.white70),
          color: const Color(0xFF1E1E1E),
          onSelected: (value) {
            if (value == 'delete') {
              _confirmDelete(bus);
            } else if (value == 'assign_route') {
              _showAssignRouteDialog(bus);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'assign_route',
              child: Row(
                children: [
                  Icon(Icons.route, color: Colors.orange, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Assign to Route',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAssignRouteDialog(BusLocation bus) async {
    final routes = await _firestoreService.streamRoutes().first;
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Assign ${bus.busName} to Route',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: routes.isEmpty
              ? const Text(
                  'No routes available',
                  style: TextStyle(color: Colors.white70),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: routes.length,
                  itemBuilder: (context, index) {
                    final route = routes[index];
                    return ListTile(
                      leading: Icon(
                        Icons.route,
                        color: Theme.of(context).primaryColor,
                      ),
                      title: Text(
                        route.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        '${route.stops.length} stops',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      onTap: () async {
                        await _firestoreService.assignBusToRoute(
                          bus.busId,
                          route.routeId,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${bus.busName} assigned to ${route.name}',
                              ),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showAddBusDialog() {
    final nameController = TextEditingController();
    final numberController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Add New Bus', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Bus Name',
                hintText: 'e.g., Campus Express',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: numberController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Bus Number',
                hintText: 'e.g., BUS-001',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                final busNumber = numberController.text.isNotEmpty
                    ? numberController.text
                    : 'BUS-${DateTime.now().millisecondsSinceEpoch % 10000}';
                final busId = 'bus_${DateTime.now().millisecondsSinceEpoch}';
                await _firestoreService.saveBus(
                  busId: busId,
                  name: '${nameController.text} ($busNumber)',
                );
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BusLocation bus) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Delete Bus?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete ${bus.busName}?',
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
              await _firestoreService.deleteBus(bus.busId);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
