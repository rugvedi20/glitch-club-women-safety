import 'package:flutter/material.dart';
import 'package:safety_pal/services/shake_sos_service.dart';

/// Provider to manage Shake SOS detection state
class ShakeSOSProvider extends ChangeNotifier {
  final ShakeSOSService _shakeSOSService = ShakeSOSService();
  
  bool _isShakeDetectionActive = false;
  bool _isPermissionGranted = false;
  String? _statusMessage;
  
  // Getters
  bool get isShakeDetectionActive => _isShakeDetectionActive;
  bool get isPermissionGranted => _isPermissionGranted;
  String? get statusMessage => _statusMessage;
  
  ShakeSOSProvider() {
    _initializeShakeDetection();
  }
  
  /// Initialize shake detection on provider creation
  Future<void> _initializeShakeDetection() async {
    try {
      // Check if permissions are already granted
      _isPermissionGranted = await _shakeSOSService.checkPermissions();
      notifyListeners();
    } catch (e) {
      _statusMessage = 'Error initializing shake detection: $e';
      debugPrint(_statusMessage);
      notifyListeners();
    }
  }
  
  /// Enable shake detection with SOS callback
  Future<bool> enableShakeDetection(OnSOSTriggered sosCallback) async {
    try {
      _statusMessage = 'Requesting permissions...';
      notifyListeners();
      
      // Request permissions if not already granted
      if (!_isPermissionGranted) {
        _isPermissionGranted = await _shakeSOSService.requestPermissions();
      }
      
      if (!_isPermissionGranted) {
        _statusMessage = 'Permissions denied for shake detection';
        notifyListeners();
        return false;
      }
      
      _statusMessage = 'Starting shake detection...';
      notifyListeners();
      
      final success = await _shakeSOSService.startShakeDetection(sosCallback);
      
      if (success) {
        _isShakeDetectionActive = true;
        _statusMessage = 'Shake detection is ACTIVE';
      } else {
        _statusMessage = 'Failed to start shake detection';
      }
      
      notifyListeners();
      return success;
    } catch (e) {
      _statusMessage = 'Error enabling shake detection: $e';
      debugPrint(_statusMessage);
      notifyListeners();
      return false;
    }
  }
  
  /// Disable shake detection
  Future<bool> disableShakeDetection() async {
    try {
      _statusMessage = 'Stopping shake detection...';
      notifyListeners();
      
      final success = await _shakeSOSService.stopShakeDetection();
      
      if (success) {
        _isShakeDetectionActive = false;
        _statusMessage = 'Shake detection is INACTIVE';
      } else {
        _statusMessage = 'Failed to stop shake detection';
      }
      
      notifyListeners();
      return success;
    } catch (e) {
      _statusMessage = 'Error disabling shake detection: $e';
      debugPrint(_statusMessage);
      notifyListeners();
      return false;
    }
  }
  
  /// Check current status from native side
  Future<void> checkStatus() async {
    try {
      _isShakeDetectionActive = await _shakeSOSService.isShakeDetectionActive();
      notifyListeners();
    } catch (e) {
      _statusMessage = 'Error checking status: $e';
      debugPrint(_statusMessage);
      notifyListeners();
    }
  }
  
  /// Update SOS callback
  void updateSOSCallback(OnSOSTriggered sosCallback) {
    _shakeSOSService.setSOSCallback(sosCallback);
  }
}
