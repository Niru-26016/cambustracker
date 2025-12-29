import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/splash_screen.dart';
import 'services/foreground_task_service.dart';
import 'services/background_alarm_service.dart' show NotificationAlarmService;

/// Main entry point for CambusTracker app.
/// Initializes Firebase and foreground task before running the app.
void main() async {
  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (check if already initialized to prevent duplicate error)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase already initialized (hot restart case)
  }

  // Initialize foreground task for background location tracking
  ForegroundTaskService.init();

  // Initialize background alarm service
  await NotificationAlarmService.initialize();

  runApp(const CambusTrackerApp());
}

/// Root widget for CambusTracker app.
class CambusTrackerApp extends StatelessWidget {
  const CambusTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CambusTracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Black and Gold Color Scheme
        scaffoldBackgroundColor: Colors.black,
        primaryColor: const Color(0xFFFFD700), // Gold
        canvasColor: Colors.black, // For Drawers/BottomSheets

        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD700), // Gold
          secondary: Color(0xFFFFD700),
          surface: Color(0xFF1E1E1E), // Dark Grey for Cards
          onPrimary: Colors.black, // Text on Gold buttons
          onSurface: Colors.white, // Text on Dark Cards
        ),

        useMaterial3: true,

        // App bar theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          foregroundColor: Color(0xFFFFD700), // Gold Text/Icons
          elevation: 0,
        ),

        // Elevated button theme
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFD700), // Gold background
            foregroundColor: Colors.black, // Black text
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        // Floating Action Button Theme
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFFFFD700),
          foregroundColor: Colors.black,
        ),

        // Text Theme
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodyMedium: TextStyle(color: Colors.white70),
          titleLarge: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),

        // Input Decoration Theme
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1E1E1E),
          labelStyle: const TextStyle(color: Colors.white70),
          hintStyle: const TextStyle(color: Colors.white38),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.white24),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFFD700)),
          ),
          prefixIconColor: const Color(0xFFFFD700),
        ),
        // Snackbar theme
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),

      // Named routes for navigation
      initialRoute: '/',
      routes: {'/': (context) => const SplashScreen()},
    );
  }
}
