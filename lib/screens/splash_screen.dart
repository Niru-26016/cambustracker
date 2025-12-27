import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';
import 'role_selection_screen.dart';
import 'driver_screen.dart';
import 'student_screen.dart';
import 'admin/admin_dashboard.dart';

/// SplashScreen - Initial screen that handles auth state and routing.
/// Uses StreamBuilder for real-time auth updates.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _hideSplashAfterDelay();
  }

  Future<void> _hideSplashAfterDelay() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() => _showSplash = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show splash during initial delay
    if (_showSplash) {
      return _buildSplashContent();
    }

    // Use StreamBuilder for real-time auth state changes
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        // Show splash while waiting for first auth event
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return _buildSplashContent();
        }

        final user = authSnapshot.data;

        // Not logged in - show login
        if (user == null) {
          return const LoginScreen();
        }

        // User is logged in - check their role
        return FutureBuilder(
          future: _authService.getCurrentUserProfile(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return _buildSplashContent();
            }

            final appUser = userSnapshot.data;

            if (appUser == null || appUser.role.isEmpty) {
              return const RoleSelectionScreen();
            }

            if (appUser.isAdmin) {
              return const AdminDashboard();
            } else if (appUser.isDriver) {
              return const DriverScreen();
            } else {
              return const StudentScreen();
            }
          },
        );
      },
    );
  }

  Widget _buildSplashContent() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: const Color(0xFFFFD700), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD700).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.directions_bus,
                size: 70,
                color: Color(0xFFFFD700),
              ),
            ),
            const SizedBox(height: 30),
            const Text(
              'CambusTracker',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFFD700),
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Track your campus bus in real-time',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 50),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFFD700)),
            ),
          ],
        ),
      ),
    );
  }
}
