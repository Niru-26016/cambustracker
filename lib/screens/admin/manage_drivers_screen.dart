import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/firestore_service.dart';
import '../../models/driver_model.dart';

/// Manage Drivers Screen - CRUD operations for drivers
class ManageDriversScreen extends StatefulWidget {
  const ManageDriversScreen({super.key});

  @override
  State<ManageDriversScreen> createState() => _ManageDriversScreenState();
}

class _ManageDriversScreenState extends State<ManageDriversScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final Map<String, String> _busNameCache = {};

  Future<String> _getBusName(String busId) async {
    if (_busNameCache.containsKey(busId)) {
      return _busNameCache[busId]!;
    }
    final buses = await _firestoreService.getAvailableBuses();
    final bus = buses.where((b) => b['id'] == busId).firstOrNull;
    final name = bus?['name'] ?? busId;
    _busNameCache[busId] = name;
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Drivers'),
        backgroundColor: Colors.transparent,
        foregroundColor: primaryColor,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDriverDialog(),
        backgroundColor: primaryColor,
        child: const Icon(Icons.add, color: Colors.black),
      ),
      body: StreamBuilder<List<Driver>>(
        stream: _firestoreService.streamDrivers(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          final drivers = snapshot.data ?? [];

          if (drivers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 80, color: Colors.grey[800]),
                  const SizedBox(height: 16),
                  Text(
                    'No drivers yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap + to add a driver',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final driver = drivers[index];
              return _buildDriverCard(driver);
            },
          );
        },
      ),
    );
  }

  Widget _buildDriverCard(Driver driver) {
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
            color: driver.isActive
                ? Colors.green.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.person,
            color: driver.isActive ? Colors.green : Colors.grey,
          ),
        ),
        title: Text(
          driver.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              driver.phone ?? 'No phone',
              style: const TextStyle(color: Colors.white70),
            ),
            if (driver.assignedBusId != null &&
                driver.assignedBusId!.isNotEmpty)
              FutureBuilder<String>(
                future: _getBusName(driver.assignedBusId!),
                builder: (context, snapshot) {
                  return Text(
                    'Bus: ${snapshot.data ?? '...'}',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
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
              _confirmDelete(driver);
            } else if (value == 'assign_bus') {
              _showAssignBusDialog(driver);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'assign_bus',
              child: Row(
                children: [
                  Icon(Icons.directions_bus, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Text('Assign to Bus', style: TextStyle(color: Colors.white)),
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

  void _showAssignBusDialog(Driver driver) async {
    final buses = await _firestoreService.getAvailableBuses();
    final allDrivers = await _firestoreService.getDrivers();
    if (!mounted) return;

    // Build map of busId -> assigned driver name
    final Map<String, String> busDriverMap = {};
    for (final d in allDrivers) {
      if (d.assignedBusId != null && d.driverId != driver.driverId) {
        busDriverMap[d.assignedBusId!] = d.name;
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text(
          'Assign ${driver.name} to Bus',
          style: const TextStyle(color: Colors.white),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: buses.isEmpty
              ? const Text(
                  'No buses available',
                  style: TextStyle(color: Colors.white70),
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: buses.length,
                  itemBuilder: (context, index) {
                    final bus = buses[index];
                    final existingDriver = busDriverMap[bus['id']];
                    final isAssigned = existingDriver != null;

                    return ListTile(
                      leading: Icon(
                        Icons.directions_bus,
                        color: isAssigned
                            ? Colors.orange
                            : Theme.of(context).primaryColor,
                      ),
                      title: Text(
                        bus['name'] ?? 'Unknown',
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: isAssigned
                          ? Text(
                              'Currently: $existingDriver',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                              ),
                            )
                          : null,
                      trailing: isAssigned
                          ? const Icon(
                              Icons.warning,
                              color: Colors.orange,
                              size: 20,
                            )
                          : null,
                      onTap: () async {
                        if (isAssigned) {
                          // Show confirmation dialog
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1E1E1E),
                              title: const Text(
                                'Bus Already Assigned',
                                style: TextStyle(color: Colors.white),
                              ),
                              content: Text(
                                'This bus is currently assigned to $existingDriver.\n\nDo you want to reassign it to ${driver.name}?',
                                style: const TextStyle(color: Colors.white70),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                  ),
                                  child: const Text('Reassign'),
                                ),
                              ],
                            ),
                          );
                          if (confirm != true) return;
                        }

                        await _firestoreService.assignDriverToBus(
                          driverId: driver.driverId,
                          busId: bus['id']!,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                '${driver.name} assigned to ${bus['name']}',
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

  void _showAddDriverDialog() {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Add New Driver',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Driver Name *',
                  hintText: 'e.g., John Doe',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (for Google Sign-In)',
                  hintText: 'e.g., driver@gmail.com',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                maxLength: 10,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: const InputDecoration(
                  labelText: 'Phone (for OTP login)',
                  hintText: 'e.g., 9876543210',
                  counterStyle: TextStyle(color: Colors.white54),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Driver will login using email OR phone in the Driver App',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Require name and at least email OR phone
              if (nameController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Name is required')),
                );
                return;
              }
              if (emailController.text.isEmpty &&
                  phoneController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Email or Phone is required for driver login',
                    ),
                  ),
                );
                return;
              }

              final driver = Driver(
                driverId: '',
                userId: '',
                name: nameController.text,
                email: emailController.text.trim(),
                phone: phoneController.text.isEmpty
                    ? null
                    : phoneController.text,
                isActive: true,
                createdAt: DateTime.now(),
              );
              await _firestoreService.saveDriver(driver);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Driver driver) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text(
          'Delete Driver?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete ${driver.name}?',
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
              await _firestoreService.deleteDriver(driver.driverId);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
