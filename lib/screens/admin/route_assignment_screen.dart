import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../models/bus_model.dart';
import '../../models/route_model.dart';
import '../../models/trip_model.dart';

/// Route-Bus Assignment Board with drag-and-drop UI
/// Allows admin to assign buses to routes, including combined routes
class RouteAssignmentScreen extends StatefulWidget {
  const RouteAssignmentScreen({super.key});

  @override
  State<RouteAssignmentScreen> createState() => _RouteAssignmentScreenState();
}

class _RouteAssignmentScreenState extends State<RouteAssignmentScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final Set<String> _selectedRouteIds = {};
  bool _isMultiSelectMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Route Assignment'),
        backgroundColor: Colors.grey[850],
        actions: [
          // Multi-select toggle
          IconButton(
            icon: Icon(
              _isMultiSelectMode
                  ? Icons.check_box
                  : Icons.check_box_outline_blank,
              color: _isMultiSelectMode ? Colors.amber : Colors.white,
            ),
            tooltip: 'Multi-select for combined routes',
            onPressed: () {
              setState(() {
                _isMultiSelectMode = !_isMultiSelectMode;
                if (!_isMultiSelectMode) {
                  _selectedRouteIds.clear();
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Available Buses Section
          _buildAvailableBusesSection(),
          const Divider(color: Colors.grey, height: 1),
          // Routes Section
          Expanded(child: _buildRoutesSection()),
        ],
      ),
      // Floating action for combined assignment
      floatingActionButton: _selectedRouteIds.length > 1
          ? FloatingActionButton.extended(
              onPressed: () => _showCombinedAssignmentInfo(),
              backgroundColor: Colors.amber,
              icon: const Icon(Icons.merge, color: Colors.black),
              label: Text(
                'Combine ${_selectedRouteIds.length} Routes',
                style: const TextStyle(color: Colors.black),
              ),
            )
          : null,
    );
  }

  // ==================== AVAILABLE BUSES SECTION ====================

  Widget _buildAvailableBusesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_bus, color: Colors.amber, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Available Buses',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                'Long-press to drag',
                style: TextStyle(color: Colors.grey[500], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 60,
            child: StreamBuilder<List<Bus>>(
              stream: _firestoreService.streamBuses(),
              builder: (context, busSnapshot) {
                if (!busSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return StreamBuilder<List<Trip>>(
                  stream: _firestoreService.streamActiveTrips(),
                  builder: (context, tripSnapshot) {
                    final allBuses = busSnapshot.data!;
                    final activeTrips = tripSnapshot.data ?? [];

                    // Filter to unassigned buses
                    final assignedBusIds = activeTrips
                        .map((t) => t.busId)
                        .toSet();
                    final unassignedBuses = allBuses
                        .where((b) => !assignedBusIds.contains(b.busId))
                        .toList();

                    if (unassignedBuses.isEmpty) {
                      return Center(
                        child: Text(
                          'All buses are assigned',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      );
                    }

                    return ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: unassignedBuses.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        return _buildDraggableBusCard(unassignedBuses[index]);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableBusCard(Bus bus) {
    return LongPressDraggable<Bus>(
      data: bus,
      delay: const Duration(milliseconds: 200),
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.amber,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.directions_bus, color: Colors.black),
              const SizedBox(width: 8),
              Text(
                bus.name ?? 'Bus ${bus.busId}',
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildBusCardContent(bus),
      ),
      child: _buildBusCardContent(bus),
    );
  }

  Widget _buildBusCardContent(Bus bus) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.directions_bus, color: Colors.amber, size: 20),
          const SizedBox(width: 8),
          Text(
            bus.name ?? 'Bus ${bus.busId}',
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ==================== ROUTES SECTION ====================

  Widget _buildRoutesSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.route, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Routes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_isMultiSelectMode) ...[
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Select routes to combine',
                    style: TextStyle(color: Colors.amber[300], fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: StreamBuilder<List<BusRoute>>(
              stream: _firestoreService.streamRoutes(),
              builder: (context, routeSnapshot) {
                if (!routeSnapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                return StreamBuilder<List<Trip>>(
                  stream: _firestoreService.streamActiveTrips(),
                  builder: (context, tripSnapshot) {
                    final routes = routeSnapshot.data!;
                    final activeTrips = tripSnapshot.data ?? [];

                    return ListView.separated(
                      itemCount: routes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _buildRouteDropTarget(
                          routes[index],
                          activeTrips,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteDropTarget(BusRoute route, List<Trip> activeTrips) {
    // Find ALL active trips for this route (multiple buses allowed)
    final routeTrips = activeTrips
        .where((t) => t.servesRoute(route.routeId))
        .toList();

    final hasAssignment = routeTrips.isNotEmpty;
    final hasCombined = routeTrips.any((t) => t.isCombined);
    final isSelected = _selectedRouteIds.contains(route.routeId);

    // Determine border color
    Color borderColor;
    if (isSelected) {
      borderColor = Colors.amber;
    } else if (hasCombined) {
      borderColor = Colors.orange;
    } else if (hasAssignment) {
      borderColor = Colors.green;
    } else {
      borderColor = Colors.red;
    }

    return DragTarget<Bus>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) {
        _handleBusDrop(details.data, route);
      },
      builder: (context, candidateData, rejectedData) {
        final isHighlighted = candidateData.isNotEmpty;

        return GestureDetector(
          onTap: _isMultiSelectMode
              ? () {
                  setState(() {
                    if (isSelected) {
                      _selectedRouteIds.remove(route.routeId);
                    } else {
                      _selectedRouteIds.add(route.routeId);
                    }
                  });
                }
              : hasAssignment
              ? () => _showRouteTripsDialog(route, routeTrips)
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isHighlighted
                  ? Colors.amber.withOpacity(0.2)
                  : Colors.grey[850],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isHighlighted ? Colors.amber : borderColor,
                width: isHighlighted || isSelected ? 2 : 1.5,
              ),
            ),
            child: Row(
              children: [
                // Checkbox for multi-select
                if (_isMultiSelectMode)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      isSelected
                          ? Icons.check_box
                          : Icons.check_box_outline_blank,
                      color: isSelected ? Colors.amber : Colors.grey,
                    ),
                  ),
                // Route info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        route.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (hasAssignment)
                        _buildMultipleAssignmentsInfo(routeTrips)
                      else
                        Text(
                          '⚪ No bus assigned',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                ),
                // Status indicator
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: borderColor,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMultipleAssignmentsInfo(List<Trip> trips) {
    return StreamBuilder<List<Bus>>(
      stream: _firestoreService.streamBuses(),
      builder: (context, snapshot) {
        final buses = snapshot.data ?? [];

        return Wrap(
          spacing: 8,
          runSpacing: 4,
          children: trips.map((trip) {
            final bus = buses.firstWhere(
              (b) => b.busId == trip.busId,
              orElse: () => Bus(
                busId: trip.busId,
                busNumber: trip.busId,
                isActive: true,
                createdAt: DateTime.now(),
              ),
            );

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: trip.isCombined
                    ? Colors.orange.withOpacity(0.2)
                    : Colors.green.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.directions_bus,
                    color: trip.isCombined ? Colors.orange : Colors.green[400],
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    bus.name ?? 'Bus ${bus.busId}',
                    style: TextStyle(
                      color: trip.isCombined
                          ? Colors.orange
                          : Colors.green[400],
                      fontSize: 12,
                    ),
                  ),
                  if (trip.isCombined) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.merge, size: 10, color: Colors.orange),
                  ],
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  void _showRouteTripsDialog(BusRoute route, List<Trip> trips) {
    showDialog(
      context: context,
      builder: (context) => StreamBuilder<List<Bus>>(
        stream: _firestoreService.streamBuses(),
        builder: (context, snapshot) {
          final buses = snapshot.data ?? [];

          return AlertDialog(
            backgroundColor: Colors.grey[850],
            title: Row(
              children: [
                const Icon(Icons.route, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    route.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${trips.length} bus${trips.length > 1 ? 'es' : ''} assigned:',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                ...trips.map((trip) {
                  final bus = buses.firstWhere(
                    (b) => b.busId == trip.busId,
                    orElse: () => Bus(
                      busId: trip.busId,
                      busNumber: trip.busId,
                      isActive: true,
                      createdAt: DateTime.now(),
                    ),
                  );

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: trip.isCombined ? Colors.orange : Colors.green,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.directions_bus,
                          color: trip.isCombined ? Colors.orange : Colors.green,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                bus.name ?? 'Bus ${bus.busId}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (trip.isCombined)
                                Text(
                                  'Combined: ${trip.routeIds.length} routes',
                                  style: TextStyle(
                                    color: Colors.orange[300],
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.remove_circle,
                            color: Colors.red,
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                            await _performUnassignment(trip);
                          },
                          tooltip: 'Remove',
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ==================== ASSIGNMENT LOGIC ====================

  void _handleBusDrop(Bus bus, BusRoute route) {
    if (_isMultiSelectMode && _selectedRouteIds.isNotEmpty) {
      // Add the dropped route to selection if not already selected
      _selectedRouteIds.add(route.routeId);
      _showCombinedAssignmentDialog(bus, _selectedRouteIds.toList());
    } else {
      // Single route assignment
      _showAssignmentDialog(bus, route);
    }
  }

  void _showAssignmentDialog(Bus bus, BusRoute route) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('Assign Bus', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_bus, color: Colors.amber),
                const SizedBox(width: 8),
                Text(
                  bus.name ?? 'Bus ${bus.busId}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Icon(Icons.arrow_downward, color: Colors.grey),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.route, color: Colors.blue),
                const SizedBox(width: 8),
                Text(
                  route.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
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
              Navigator.pop(context);
              await _performAssignment(bus.busId, [route.routeId]);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber),
            child: const Text('Confirm', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  void _showCombinedAssignmentDialog(Bus bus, List<String> routeIds) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Row(
          children: [
            const Icon(Icons.merge, color: Colors.orange),
            const SizedBox(width: 8),
            const Text(
              'Combined Routes',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: StreamBuilder<List<BusRoute>>(
          stream: _firestoreService.streamRoutes(),
          builder: (context, snapshot) {
            final routes = snapshot.data ?? [];
            final selectedRoutes = routes
                .where((r) => routeIds.contains(r.routeId))
                .toList();

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Low crowd scenario - One bus will serve multiple routes',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.directions_bus, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      bus.name ?? 'Bus ${bus.busId}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Routes:', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 8),
                ...selectedRoutes.map(
                  (route) => Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.route, color: Colors.blue, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          route.name,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performAssignment(bus.busId, routeIds);
              setState(() {
                _selectedRouteIds.clear();
                _isMultiSelectMode = false;
              });
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text(
              'Start Combined Service',
              style: TextStyle(color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  void _showCombinedAssignmentInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Drag a bus onto any selected route to combine them'),
        backgroundColor: Colors.amber,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showUnassignDialog(Trip trip, BusRoute route) {
    showDialog(
      context: context,
      builder: (context) => StreamBuilder<List<Bus>>(
        stream: _firestoreService.streamBuses(),
        builder: (context, snapshot) {
          final buses = snapshot.data ?? [];
          final bus = buses.firstWhere(
            (b) => b.busId == trip.busId,
            orElse: () => Bus(
              busId: trip.busId,
              busNumber: trip.busId,
              isActive: true,
              createdAt: DateTime.now(),
            ),
          );

          return AlertDialog(
            backgroundColor: Colors.grey[850],
            title: const Text(
              'Remove Assignment',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          trip.isCombined
                              ? 'This will end the combined service for all routes'
                              : 'Remove bus from this route?',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.directions_bus, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      bus.name ?? 'Bus ${bus.busId}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.route, color: Colors.blue),
                    const SizedBox(width: 8),
                    Text(
                      route.name,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
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
                  Navigator.pop(context);
                  await _performUnassignment(trip);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _performUnassignment(Trip trip) async {
    try {
      await _firestoreService.endTrip(trip.tripId);
      // Also clear the bus routeId
      await _firestoreService.unassignBus(trip.busId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Bus removed from route'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _performAssignment(String busId, List<String> routeIds) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      await _firestoreService.createTrip(
        busId: busId,
        routeIds: routeIds,
        createdBy: currentUser?.uid ?? 'admin',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              routeIds.length > 1
                  ? '✓ Combined service started with ${routeIds.length} routes'
                  : '✓ Bus assigned successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
