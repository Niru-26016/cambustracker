import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'student_screen.dart';
import 'driver_screen.dart';

/// RoleSelectionScreen - First-time user role selection.
/// Driver or Passenger role with appropriate options.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  bool _isLoading = false;
  String? _selectedRole;
  String? _selectedBusId;
  List<Map<String, String>> _availableBuses = [];

  @override
  void initState() {
    super.initState();
    _loadBuses();
  }

  Future<void> _loadBuses() async {
    final buses = await _firestoreService.getAvailableBuses();
    setState(() => _availableBuses = buses);
  }

  Future<void> _saveRole() async {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a role')));
      return;
    }

    // Validate bus selection for driver
    if (_selectedRole == 'driver' && _selectedBusId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a bus')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.updateUserRole(_selectedRole!, busId: _selectedBusId);

      // Navigate directly to appropriate screen
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => _selectedRole == 'driver'
                ? const DriverScreen()
                : const StudentScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () async {
              await _authService.signOut();
              if (context.mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome! 👋',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'How will you use CambusTracker?',
                style: TextStyle(fontSize: 18, color: Colors.white70),
              ),
              const SizedBox(height: 30),

              // Role Selection Cards (only Passenger and Driver)
              _buildRoleCard(
                role: 'passenger',
                icon: Icons.person,
                title: 'Passenger',
                description: 'Track campus buses on the map in real-time',
                isSelected: _selectedRole == 'passenger',
              ),
              const SizedBox(height: 12),
              _buildRoleCard(
                role: 'driver',
                icon: Icons.drive_eta,
                title: 'Driver',
                description: 'Share your bus location with passengers',
                isSelected: _selectedRole == 'driver',
              ),

              // Bus Selection (for drivers)
              if (_selectedRole == 'driver') ...[
                const SizedBox(height: 24),
                Text(
                  'Select Your Bus',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: primaryColor.withOpacity(0.3)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedBusId,
                      isExpanded: true,
                      hint: const Text(
                        'Choose a bus',
                        style: TextStyle(color: Colors.white70),
                      ),
                      dropdownColor: const Color(0xFF1E1E1E),
                      icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                      items: _availableBuses.map((bus) {
                        return DropdownMenuItem<String>(
                          value: bus['id'],
                          child: Text(
                            bus['name']!,
                            style: const TextStyle(color: Colors.white),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) =>
                          setState(() => _selectedBusId = value),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 40),

              // Continue Button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveRole,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 5,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String role,
    required IconData icon,
    required String title,
    required String description,
    required bool isSelected,
  }) {
    final primaryColor = Theme.of(context).primaryColor;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRole = role;
          if (role != 'driver') _selectedBusId = null;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withOpacity(0.1)
              : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? primaryColor : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isSelected ? primaryColor : Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 28,
                color: isSelected ? Colors.black : primaryColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? primaryColor : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 13, color: Colors.white70),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: primaryColor, size: 24),
          ],
        ),
      ),
    );
  }
}
