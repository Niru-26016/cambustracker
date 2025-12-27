import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import 'manage_buses_screen.dart';
import 'manage_routes_screen.dart';
import 'manage_drivers_screen.dart';
import 'admin_map_screen.dart';
import 'broadcast_screen.dart';

/// Admin Dashboard - Main screen for administrators.
/// Shows overview stats and quick actions for managing the transport system.
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  Map<String, dynamic> _stats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await _firestoreService.getDashboardStats();
      if (mounted) {
        setState(() {
          _stats = stats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Background comes from theme (Black)
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadStats();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _authService.signOut();
              if (context.mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadStats,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Cards
                    _buildStatsGrid(),
                    const SizedBox(height: 24),

                    // Quick Actions
                    Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildActionsGrid(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.0,
      children: [
        _buildStatCard(
          'Active Buses',
          '${_stats['activeBuses'] ?? 0}',
          Icons.directions_bus,
          Colors.green,
        ),
        _buildStatCard(
          'Total Buses',
          '${_stats['totalBuses'] ?? 0}',
          Icons.bus_alert,
          Colors.blueAccent,
        ),
        _buildStatCard(
          'Routes',
          '${_stats['totalRoutes'] ?? 0}',
          Icons.route,
          Colors.orange,
        ),
        _buildStatCard(
          'Drivers',
          '${_stats['totalDrivers'] ?? 0}',
          Icons.person,
          Colors.purpleAccent,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E), // Dark Grey
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: [
        _buildActionCard(
          'Manage Buses',
          Icons.directions_bus,
          Theme.of(context).primaryColor,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ManageBusesScreen()),
          ),
        ),
        _buildActionCard(
          'Manage Routes',
          Icons.route,
          Colors.orange,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ManageRoutesScreen()),
          ),
        ),
        _buildActionCard(
          'Manage Drivers',
          Icons.people,
          Colors.purpleAccent,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ManageDriversScreen()),
          ),
        ),
        _buildActionCard(
          'Live Map',
          Icons.map,
          Colors.green,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminMapScreen()),
          ),
        ),
        _buildActionCard(
          'Broadcast',
          Icons.campaign,
          Colors.redAccent,
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BroadcastScreen()),
          ),
        ),
        _buildActionCard('Analytics', Icons.analytics, Colors.tealAccent, () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Analytics coming soon!')),
          );
        }),
      ],
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E), // Dark Grey
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
