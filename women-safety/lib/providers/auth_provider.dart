import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:safety_pal/services/auth_service.dart';
import 'package:safety_pal/services/user_service.dart';

/// Manages authentication state and user session.
class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  Map<String, dynamic>? _userData;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  User? get currentUser => _currentUser;
  Map<String, dynamic>? get userData => _userData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  AuthProvider() {
    _initializeAuth();
  }

  /// Initialize authentication stream listener.
  void _initializeAuth() {
    AuthService.authStateStream.listen((User? user) {
      _currentUser = user;
      if (user != null) {
        _loadUserData(user.uid);
      } else {
        _userData = null;
      }
      notifyListeners();
    });
  }

  /// Load user data from Firestore.
  Future<void> _loadUserData(String uid) async {
    try {
      _userData = await UserService.getUserData(uid);
      notifyListeners();
    } catch (e) {
      print('Error loading user data: $e');
      _errorMessage = 'Failed to load user data';
      notifyListeners();
    }
  }

  /// Register new user.
  Future<bool> register({
    required String email,
    required String password,
    required String name,
    required String phone,
    String? age,
    String? gender,
    String? bloodGroup,
    String? address,
    String? location,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      User? user = await AuthService.registerUser(
        email: email,
        password: password,
        name: name,
        phone: phone,
        age: age,
        gender: gender,
        bloodGroup: bloodGroup,
        address: address,
        location: location,
      );

      if (user != null) {
        _currentUser = user;
        await _loadUserData(user.uid);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getAuthErrorMessage(e.code);
    } catch (e) {
      _errorMessage = 'Registration failed: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Login user.
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();

      User? user = await AuthService.loginUser(
        email: email,
        password: password,
      );

      if (user != null) {
        _currentUser = user;
        await _loadUserData(user.uid);
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } on FirebaseAuthException catch (e) {
      _errorMessage = _getAuthErrorMessage(e.code);
    } catch (e) {
      _errorMessage = 'Login failed: $e';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Logout user.
  Future<void> logout() async {
    try {
      _isLoading = true;
      notifyListeners();

      await AuthService.logout();
      _currentUser = null;
      _userData = null;
      _errorMessage = null;

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Logout failed: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Get user-friendly error message from Firebase error code.
  String _getAuthErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'email-already-in-use':
        return 'Email already registered. Try logging in.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'too-many-requests':
        return 'Too many login attempts. Try again later.';
      default:
        return 'Authentication error: $code';
    }
  }
}
