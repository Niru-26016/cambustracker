import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

/// AuthService handles Google Sign-In and user authentication.
/// Uses Firebase Auth for authentication and Firestore for user profiles.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get current Firebase user
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes for real-time auth updates
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Sign in with Google
  /// Returns the signed-in user or null if cancelled/failed
  Future<User?> signInWithGoogle() async {
    try {
      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User cancelled the sign-in
        return null;
      }

      // Get auth details from Google
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase
      final UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      final User? user = userCredential.user;

      if (user != null) {
        // Check if user exists in Firestore
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

        if (!userDoc.exists) {
          // Create new user document (role will be set later)
          await _firestore.collection('users').doc(user.uid).set({
            'name': user.displayName ?? '',
            'email': user.email ?? '',
            'role': 'student', // Default to passenger/student
            'busId': null,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }

      return user;
    } catch (e) {
      // Log error for debugging
      debugPrint('Google Sign-In Error: $e');
      rethrow; // Rethrow so LoginScreen can show error
    }
  }

  /// Get current user's AppUser profile from Firestore
  /// Uses stream for real-time updates
  Stream<AppUser?> streamCurrentUser() {
    final user = currentUser;
    if (user == null) {
      return Stream.value(null);
    }

    return _firestore.collection('users').doc(user.uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return AppUser.fromJson(doc.data()!, doc.id);
    });
  }

  /// Get current user's AppUser profile (one-time fetch)
  Future<AppUser?> getCurrentUserProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final doc = await _firestore.collection('users').doc(user.uid).get();
    if (!doc.exists) return null;

    return AppUser.fromJson(doc.data()!, doc.id);
  }

  /// Update user role (driver or student)
  Future<void> updateUserRole(String role, {String? busId}) async {
    final user = currentUser;
    if (user == null) throw Exception('No user signed in');

    await _firestore.collection('users').doc(user.uid).update({
      'role': role,
      'busId': busId,
    });
  }

  /// Update user's assigned bus
  Future<void> updateUserBus(String busId) async {
    final user = currentUser;
    if (user == null) throw Exception('No user signed in');

    await _firestore.collection('users').doc(user.uid).update({'busId': busId});
  }

  /// Sign in with email and password
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      final UserCredential userCredential = await _auth
          .signInWithEmailAndPassword(email: email, password: password);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw _getAuthErrorMessage(e.code);
    } catch (e) {
      throw 'Failed to sign in. Please try again.';
    }
  }

  /// Register with email and password
  Future<User?> registerWithEmail(
    String email,
    String password,
    String name, {
    String role = 'student', // Default role
  }) async {
    try {
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      final User? user = userCredential.user;

      if (user != null) {
        // Update display name
        await user.updateDisplayName(name);

        // Create user document in Firestore with role
        await _firestore.collection('users').doc(user.uid).set({
          'name': name,
          'email': email,
          'role': role, // Set role from registration
          'busId': null,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw _getAuthErrorMessage(e.code);
    } catch (e) {
      throw 'Failed to register. Please try again.';
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _getAuthErrorMessage(e.code);
    } catch (e) {
      throw 'Failed to send reset email. Please try again.';
    }
  }

  /// Get user-friendly error message from Firebase error code
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }
}
