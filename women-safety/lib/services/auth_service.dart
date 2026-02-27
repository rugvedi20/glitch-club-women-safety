import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for handling Firebase authentication operations.
class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Register a new user with email and password.
  /// Creates both Auth and User Firestore document.
  static Future<User?> registerUser({
    required String email,
    required String password,
    required String name,
    required String phone,
    String? age,
    String? gender,
    String? bloodGroup,
    String? address,
    String? location,
    List<Map<String, String>>? guardians,
  }) async {
    try {
      // Create Firebase Auth user
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      User? user = userCredential.user;

      if (user != null) {
        // Create user document in Firestore
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': name,
          'email': email,
          'phone': phone,
          'age': int.tryParse(age ?? '0') ?? 0,
          'gender': gender ?? '',
          'blood_grp': bloodGroup ?? '',
          'address': address ?? '',
          'location': location ?? '',
          'guardians': guardians ?? [],
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        return user;
      }
    } on FirebaseAuthException catch (e) {
      print('Auth exception: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Error registering user: $e');
      rethrow;
    }
    return null;
  }

  /// Login user with email and password.
  static Future<User?> loginUser({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      print('Auth exception: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      print('Error logging in: $e');
      rethrow;
    }
  }

  /// Logout current user.
  static Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      print('Error logging out: $e');
      rethrow;
    }
  }

  /// Get current authenticated user.
  static User? getCurrentUser() {
    return _auth.currentUser;
  }

  /// Check if user is authenticated.
  static bool isUserAuthenticated() {
    return _auth.currentUser != null;
  }

  /// Get user authentication stream.
  static Stream<User?> get authStateStream => _auth.authStateChanges();

  /// Update user profile in Firestore.
  static Future<void> updateUserProfile({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    try {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _firestore.collection('users').doc(uid).update(data);
    } catch (e) {
      print('Error updating user profile: $e');
      rethrow;
    }
  }

  /// Reset password for user.
  static Future<void> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      print('Error sending password reset email: $e');
      rethrow;
    }
  }
}
