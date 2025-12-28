import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

import 'student_screen.dart';
import 'admin/admin_dashboard.dart';

/// SplashScreen - Initial screen that handles auth state and routing.
/// Uses StreamBuilder for real-time auth updates.
/// Note: Driver features have been moved to CambusTracker Driver app.
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

        // User is logged in - check their role using StreamBuilder for real-time updates
        return StreamBuilder(
          stream: _authService.streamCurrentUser(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return _buildSplashContent();
            }

            final appUser = userSnapshot.data;

            // If no user profile yet or role is empty, default to student directly
            if (appUser == null || appUser.role.isEmpty) {
              return const StudentScreen();
            }

            if (appUser.isAdmin) {
              return const AdminDashboard();
            } else if (appUser.isDriver) {
              // Driver features moved to separate app
              return _buildDriverBlockedScreen();
            } else {
              return const StudentScreen();
            }
          },
        );
      },
    );
  }

  /// Screen shown to drivers - they should use the separate Driver app
  Widget _buildDriverBlockedScreen() {
    final primaryColor = Theme.of(context).primaryColor;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.directions_bus, size: 80, color: primaryColor),
              const SizedBox(height: 24),
              Text(
                'Driver Account Detected',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Please use the CambusTracker Driver app for driver features.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () async {
                  await _authService.signOut();
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
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
