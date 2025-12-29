import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bus_location.dart';
import '../models/bus_model.dart';
import '../models/route_model.dart';
import '../models/driver_model.dart';
import '../models/trip_model.dart';

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
  CollectionReference<Map<String, dynamic>> get _tripsRef =>
      _firestore.collection('trips');

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
    }, SetOptions(merge: true)); // Preserve existing fields like routeId
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

  /// Assign a driver to a bus (enforces one-bus-one-driver)
  Future<void> assignDriverToBus({
    required String driverId,
    required String busId,
  }) async {
    final batch = _firestore.batch();

    // First, check if another driver is currently assigned to this bus
    final existingDriverQuery = await _driversRef
        .where('assignedBusId', isEqualTo: busId)
        .get();

    // Unassign any existing drivers from this bus
    for (final doc in existingDriverQuery.docs) {
      if (doc.id != driverId) {
        batch.update(doc.reference, {'assignedBusId': null});
      }
    }

    // Also check if this driver was assigned to a different bus and clear that bus's driverId
    final driverDoc = await _driversRef.doc(driverId).get();
    final previousBusId = driverDoc.data()?['assignedBusId'];
    if (previousBusId != null && previousBusId != busId) {
      batch.update(_busesRef.doc(previousBusId), {'driverId': null});
    }

    // Update driver with new bus
    batch.update(_driversRef.doc(driverId), {'assignedBusId': busId});

    // Update bus with new driver
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

  // ==================== BULK IMPORT OPERATIONS ====================

  /// Bulk import multiple drivers (skips duplicates by email/phone)
  /// busAssignments: Map from driver index to bus name/number for assignment
  Future<Map<String, dynamic>> bulkImportDrivers(
    List<Driver> drivers, {
    Map<int, String>? busAssignments,
  }) async {
    int successCount = 0;
    int skippedCount = 0;
    final List<String> errors = [];

    // Get existing drivers to check for duplicates
    final existingDrivers = await getDrivers();

    // Create lookup maps for existing drivers by email and phone
    final Map<String, Driver> existingByEmail = {};
    final Map<String, Driver> existingByPhone = {};
    for (final d in existingDrivers) {
      if (d.email.isNotEmpty) {
        existingByEmail[d.email.toLowerCase()] = d;
      }
      if (d.phone != null && d.phone!.isNotEmpty) {
        existingByPhone[d.phone!] = d;
      }
    }

    // Get existing buses for assignment lookup by bus number
    Map<String, String> busNumberToId = {};
    if (busAssignments != null && busAssignments.isNotEmpty) {
      // Fetch all buses from Firestore to get bus numbers
      final busSnapshot = await _busesRef.get();
      for (final doc in busSnapshot.docs) {
        final data = doc.data();
        // Get bus number from the name field or use doc id
        final busName = data['name']?.toString() ?? '';
        final busId = doc.id;

        // Extract number from bus name like "Bus 1 - Main Campus" or just use the name
        // Also support pure numbers like "69", "56"
        busNumberToId[busName.toLowerCase()] = busId;
        busNumberToId[busId.toLowerCase()] = busId;

        // Extract numbers from name for matching (e.g., "69" from "Bus 69")
        final numMatch = RegExp(r'\d+').firstMatch(busName);
        if (numMatch != null) {
          busNumberToId[numMatch.group(0)!] = busId;
        }
      }
    }

    int updatedCount = 0;

    for (int i = 0; i < drivers.length; i++) {
      final driver = drivers[i];

      // Check for bus assignment from import data
      String? assignedBusId;
      if (busAssignments != null && busAssignments.containsKey(i)) {
        final busNumber = busAssignments[i]!.toLowerCase().trim();
        if (busNumber.isNotEmpty) {
          // Try to find matching bus by number
          assignedBusId = busNumberToId[busNumber];
          if (assignedBusId == null) {
            // Try partial match
            for (final entry in busNumberToId.entries) {
              if (entry.key.contains(busNumber) ||
                  busNumber.contains(entry.key)) {
                assignedBusId = entry.value;
                break;
              }
            }
          }
        }
      }

      // Check if driver already exists (by email or phone)
      Driver? existingDriver;
      if (driver.email.isNotEmpty &&
          existingByEmail.containsKey(driver.email.toLowerCase())) {
        existingDriver = existingByEmail[driver.email.toLowerCase()];
      } else if (driver.phone != null &&
          driver.phone!.isNotEmpty &&
          existingByPhone.containsKey(driver.phone)) {
        existingDriver = existingByPhone[driver.phone!];
      }

      try {
        if (existingDriver != null) {
          // Check if there are new details to update
          bool hasNewData = false;
          String? newEmail;
          String? newPhone;
          String? newBusId;

          // Check for new email
          if (driver.email.isNotEmpty && existingDriver.email != driver.email) {
            newEmail = driver.email;
            hasNewData = true;
          }

          // Check for new phone
          if (driver.phone != null &&
              driver.phone!.isNotEmpty &&
              existingDriver.phone != driver.phone) {
            newPhone = driver.phone;
            hasNewData = true;
          }

          // Check for new bus assignment
          if (assignedBusId != null &&
              existingDriver.assignedBusId != assignedBusId) {
            newBusId = assignedBusId;
            hasNewData = true;
          }

          if (hasNewData) {
            // Update existing driver with new details
            final updatedDriver = existingDriver.copyWith(
              name: driver.name.isNotEmpty ? driver.name : null,
              phone: newPhone,
              assignedBusId: newBusId,
            );
            await saveDriver(updatedDriver);
            updatedCount++;
            errors.add(
              'Row ${i + 1}: Updated "${driver.name}" with new details',
            );
          } else {
            skippedCount++;
            errors.add(
              'Row ${i + 1}: Driver "${driver.name}" already exists (no new data)',
            );
          }
        } else {
          // New driver - create with bus assignment if found
          final driverToSave = assignedBusId != null
              ? driver.copyWith(assignedBusId: assignedBusId)
              : driver;

          await saveDriver(driverToSave);
          successCount++;

          // Add to lookup maps to catch duplicates within the import file
          if (driver.email.isNotEmpty)
            existingByEmail[driver.email.toLowerCase()] = driverToSave;
          if (driver.phone != null)
            existingByPhone[driver.phone!] = driverToSave;
        }
      } catch (e) {
        errors.add('Row ${i + 1}: Failed to import - $e');
      }
    }

    return {
      'successCount': successCount,
      'updatedCount': updatedCount,
      'skippedCount': skippedCount,
      'failedCount':
          drivers.length - successCount - updatedCount - skippedCount,
      'errors': errors,
    };
  }

  /// Bulk import multiple buses (skips duplicates by bus number)
  Future<Map<String, dynamic>> bulkImportBuses(
    List<Map<String, dynamic>> buses,
  ) async {
    int successCount = 0;
    int skippedCount = 0;
    final List<String> errors = [];

    // Get existing buses to check for duplicates
    final existingBuses = await getAvailableBuses();
    final existingNames = existingBuses
        .map((b) => b['name']!.toLowerCase())
        .toSet();

    for (int i = 0; i < buses.length; i++) {
      final bus = buses[i];
      final name = bus['name'] as String;

      // Check for duplicates by name
      if (existingNames.contains(name.toLowerCase())) {
        skippedCount++;
        errors.add('Row ${i + 1}: Bus "$name" already exists');
        continue;
      }

      try {
        final busId = 'bus_${DateTime.now().millisecondsSinceEpoch}_$i';
        await saveBus(busId: busId, name: name);
        successCount++;
        existingNames.add(name.toLowerCase());
      } catch (e) {
        errors.add('Row ${i + 1}: Failed to import - $e');
      }
    }

    return {
      'successCount': successCount,
      'skippedCount': skippedCount,
      'failedCount': buses.length - successCount - skippedCount,
      'errors': errors,
    };
  }

  // ==================== TRIP OPERATIONS ====================

  /// Stream all active trips
  Stream<List<Trip>> streamActiveTrips() {
    return _tripsRef.where('status', isEqualTo: 'active').snapshots().map((
      snapshot,
    ) {
      return snapshot.docs.map((doc) {
        return Trip.fromJson(doc.data(), doc.id);
      }).toList();
    });
  }

  /// Get active trip for a specific route
  Future<Trip?> getActiveTripForRoute(String routeId) async {
    final snapshot = await _tripsRef
        .where('status', isEqualTo: 'active')
        .where('routeIds', arrayContains: routeId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return Trip.fromJson(snapshot.docs.first.data(), snapshot.docs.first.id);
  }

  /// Get active trip for a specific bus
  Future<Trip?> getActiveTripForBus(String busId) async {
    final snapshot = await _tripsRef
        .where('status', isEqualTo: 'active')
        .where('busId', isEqualTo: busId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return Trip.fromJson(snapshot.docs.first.data(), snapshot.docs.first.id);
  }

  /// Create a new trip (assign bus to routes)
  Future<Trip> createTrip({
    required String busId,
    required List<String> routeIds,
    String? driverId,
    required String createdBy,
  }) async {
    // End any existing active trip for this bus (a bus can only serve one route set at a time)
    final existingBusTrip = await getActiveTripForBus(busId);
    if (existingBusTrip != null) {
      await endTrip(existingBusTrip.tripId);
    }

    // NOTE: We do NOT end existing trips for routes
    // Multiple buses CAN serve the same route simultaneously

    // Create new trip
    final docRef = _tripsRef.doc();
    final trip = Trip(
      tripId: docRef.id,
      busId: busId,
      routeIds: routeIds,
      driverId: driverId,
      isCombined: routeIds.length > 1,
      status: 'active',
      createdBy: createdBy,
      createdAt: DateTime.now(),
    );

    await docRef.set(trip.toJson());

    // Also update bus with first route for backward compatibility
    await _busesRef.doc(busId).update({
      'routeId': routeIds.first,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return trip;
  }

  /// End a trip (mark as completed)
  Future<void> endTrip(String tripId) async {
    await _tripsRef.doc(tripId).update({
      'status': 'completed',
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Unassign bus from all routes (end current trip)
  Future<void> unassignBus(String busId) async {
    final activeTrip = await getActiveTripForBus(busId);
    if (activeTrip != null) {
      await endTrip(activeTrip.tripId);
    }

    // Clear routeId on bus
    await _busesRef.doc(busId).update({
      'routeId': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get buses that are not currently assigned to any active trip
  Future<List<Bus>> getUnassignedBuses() async {
    // Get all buses
    final busSnapshot = await _busesRef.get();
    final allBuses = busSnapshot.docs
        .map((doc) => Bus.fromJson(doc.data(), doc.id))
        .toList();

    // Get active trips
    final activeTrips = await _tripsRef
        .where('status', isEqualTo: 'active')
        .get();

    final assignedBusIds = activeTrips.docs
        .map((doc) => doc.data()['busId'] as String)
        .toSet();

    return allBuses
        .where((bus) => !assignedBusIds.contains(bus.busId))
        .toList();
  }

  /// Stream unassigned buses (real-time)
  Stream<List<Bus>> streamUnassignedBuses() {
    return streamBuses().asyncMap((allBuses) async {
      final activeTrips = await _tripsRef
          .where('status', isEqualTo: 'active')
          .get();

      final assignedBusIds = activeTrips.docs
          .map((doc) => doc.data()['busId'] as String)
          .toSet();

      return allBuses
          .where((bus) => !assignedBusIds.contains(bus.busId))
          .toList();
    });
  }
}
