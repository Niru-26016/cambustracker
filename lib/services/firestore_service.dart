import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bus_location.dart';
import '../models/bus_model.dart';
import '../models/route_model.dart';
import '../models/driver_model.dart';

/// FirestoreService handles all Firestore operations.
/// Uses streams for real-time updates as per project requirements.
class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collection references
  CollectionReference<Map<String, dynamic>> get _busesRef =>
      _firestore.collection('buses');
  CollectionReference<Map<String, dynamic>> get _routesRef =>
      _firestore.collection('routes');
  CollectionReference<Map<String, dynamic>> get _driversRef =>
      _firestore.collection('drivers');
  CollectionReference<Map<String, dynamic>> get _usersRef =>
      _firestore.collection('users');

  // ==================== BUS OPERATIONS ====================

  /// Stream all buses
  Stream<List<BusLocation>> streamAllBuses() {
    return _busesRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return BusLocation.fromJson(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Stream only active buses (currently on trip)
  Stream<List<BusLocation>> streamActiveBuses() {
    return _busesRef.where('isActive', isEqualTo: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) {
        return BusLocation.fromJson(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Stream a specific bus location
  Stream<BusLocation?> streamBusLocation(String busId) {
    return _busesRef.doc(busId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return BusLocation.fromJson(doc.data()!, doc.id);
    });
  }

  /// Update bus location (called by driver during trip)
  Future<void> updateBusLocation({
    required String busId,
    required double lat,
    required double lng,
    required double speed,
    required double bearing,
    required String driverId,
  }) async {
    await _busesRef.doc(busId).set({
      'lat': lat,
      'lng': lng,
      'speed': speed,
      'bearing': bearing,
      'isActive': true,
      'driverId': driverId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Start a trip for a bus
  Future<void> startTrip({
    required String busId,
    required String busName,
    required String driverId,
    required double lat,
    required double lng,
  }) async {
    await _busesRef.doc(busId).set({
      'name': busName,
      'lat': lat,
      'lng': lng,
      'speed': 0.0,
      'bearing': 0.0,
      'isActive': true,
      'driverId': driverId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stop a trip for a bus
  Future<void> stopTrip(String busId) async {
    await _busesRef.doc(busId).update({
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get list of available buses from Firestore
  Future<List<Map<String, String>>> getAvailableBuses() async {
    final snapshot = await _busesRef.get();
    if (snapshot.docs.isEmpty) {
      // Return default buses if none exist
      return [
        {'id': 'bus_1', 'name': 'Bus 1 - Main Campus'},
        {'id': 'bus_2', 'name': 'Bus 2 - North Route'},
        {'id': 'bus_3', 'name': 'Bus 3 - South Route'},
        {'id': 'bus_4', 'name': 'Bus 4 - Express'},
        {'id': 'bus_5', 'name': 'Bus 5 - Shuttle'},
      ];
    }
    return snapshot.docs.map((doc) {
      return {'id': doc.id, 'name': doc.data()['name']?.toString() ?? doc.id};
    }).toList();
  }

  /// Create or update a bus
  Future<void> saveBus({
    required String busId,
    required String name,
    String? routeId,
    String? driverId,
  }) async {
    await _busesRef.doc(busId).set({
      'name': name,
      'routeId': routeId,
      'driverId': driverId,
      'isActive': false,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Delete a bus (also unassigns any driver from this bus)
  Future<void> deleteBus(String busId) async {
    try {
      // Find driver assigned to this bus and unassign them
      final driversSnapshot = await _driversRef
          .where('assignedBusId', isEqualTo: busId)
          .get();

      for (final doc in driversSnapshot.docs) {
        await doc.reference.update({'assignedBusId': null});
      }

      // Delete the bus
      await _busesRef.doc(busId).delete();
    } catch (e) {
      // If any error, try direct delete
      await _busesRef.doc(busId).delete();
    }
  }

  /// Check if a bus is currently active
  Future<bool> isBusActive(String busId) async {
    final doc = await _busesRef.doc(busId).get();
    if (!doc.exists) return false;
    return doc.data()?['isActive'] ?? false;
  }

  /// Stream all buses as Bus model
  Stream<List<Bus>> streamBuses() {
    return _busesRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Bus.fromJson(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Get buses assigned to a specific route
  Stream<List<Bus>> streamBusesByRoute(String routeId) {
    return _busesRef.where('routeId', isEqualTo: routeId).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) {
        return Bus.fromJson(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Assign a bus to a route
  Future<void> assignBusToRoute(String busId, String routeId) async {
    await _busesRef.doc(busId).update({
      'routeId': routeId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Unassign a bus from its route
  Future<void> unassignBusFromRoute(String busId) async {
    await _busesRef.doc(busId).update({
      'routeId': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== ROUTE OPERATIONS ====================

  /// Stream all routes
  Stream<List<BusRoute>> streamRoutes() {
    return _routesRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return BusRoute.fromJson(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Get all routes (one-time fetch)
  Future<List<BusRoute>> getRoutes() async {
    final snapshot = await _routesRef.get();
    return snapshot.docs.map((doc) {
      return BusRoute.fromJson(doc.data(), doc.id);
    }).toList();
  }

  /// Create or update a route
  Future<String> saveRoute(BusRoute route) async {
    if (route.routeId.isEmpty) {
      // Create new route
      final docRef = await _routesRef.add(route.toJson());
      return docRef.id;
    } else {
      // Update existing route
      await _routesRef.doc(route.routeId).set(route.toJson());
      return route.routeId;
    }
  }

  /// Delete a route (also unassigns all buses from this route)
  Future<void> deleteRoute(String routeId) async {
    try {
      // Find all buses assigned to this route and unassign them
      final busesSnapshot = await _busesRef
          .where('routeId', isEqualTo: routeId)
          .get();

      for (final doc in busesSnapshot.docs) {
        await doc.reference.update({'routeId': null});
      }

      // Delete the route
      await _routesRef.doc(routeId).delete();
    } catch (e) {
      // If any error, try direct delete
      await _routesRef.doc(routeId).delete();
    }
  }

  // ==================== DRIVER OPERATIONS ====================

  /// Stream all drivers
  Stream<List<Driver>> streamDrivers() {
    return _driversRef.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return Driver.fromJson(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Get all drivers (one-time fetch)
  Future<List<Driver>> getDrivers() async {
    final snapshot = await _driversRef.get();
    return snapshot.docs.map((doc) {
      return Driver.fromJson(doc.data(), doc.id);
    }).toList();
  }

  /// Create or update a driver
  Future<String> saveDriver(Driver driver) async {
    if (driver.driverId.isEmpty) {
      final docRef = await _driversRef.add(driver.toJson());
      return docRef.id;
    } else {
      await _driversRef.doc(driver.driverId).set(driver.toJson());
      return driver.driverId;
    }
  }

  /// Assign a driver to a bus
  Future<void> assignDriverToBus({
    required String driverId,
    required String busId,
  }) async {
    final batch = _firestore.batch();

    // Update driver
    batch.update(_driversRef.doc(driverId), {'assignedBusId': busId});

    // Update bus
    batch.update(_busesRef.doc(busId), {'driverId': driverId});

    await batch.commit();
  }

  /// Unassign a driver from their bus
  Future<void> unassignDriver(String driverId) async {
    final driverDoc = await _driversRef.doc(driverId).get();
    final busId = driverDoc.data()?['assignedBusId'];

    final batch = _firestore.batch();
    batch.update(_driversRef.doc(driverId), {'assignedBusId': null});

    if (busId != null) {
      batch.update(_busesRef.doc(busId), {'driverId': null});
    }

    await batch.commit();
  }

  /// Delete a driver
  Future<void> deleteDriver(String driverId) async {
    try {
      // First get driver to check if assigned to a bus
      final driverDoc = await _driversRef.doc(driverId).get();
      if (driverDoc.exists) {
        final busId = driverDoc.data()?['assignedBusId'];

        // If assigned to a bus, unassign first
        if (busId != null && busId.isNotEmpty) {
          await _busesRef.doc(busId).update({'driverId': null});
        }
      }

      // Delete the driver
      await _driversRef.doc(driverId).delete();
    } catch (e) {
      // If any error, try direct delete
      await _driversRef.doc(driverId).delete();
    }
  }

  // ==================== ADMIN STATISTICS ====================

  /// Get dashboard statistics
  Future<Map<String, dynamic>> getDashboardStats() async {
    final buses = await _busesRef.get();
    final routes = await _routesRef.get();
    final drivers = await _driversRef.get();

    final activeBuses = buses.docs
        .where((doc) => doc.data()['isActive'] == true)
        .length;

    return {
      'totalBuses': buses.docs.length,
      'activeBuses': activeBuses,
      'totalRoutes': routes.docs.length,
      'totalDrivers': drivers.docs.length,
    };
  }
}
