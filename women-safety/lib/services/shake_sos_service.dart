import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

typedef OnSOSTriggered = Future<void> Function();

class ShakeSOSService {
  static const platform = MethodChannel('com.example.safety_pal/shake');
  
  static final ShakeSOSService _instance = ShakeSOSService._internal();
  
  OnSOSTriggered? _sosCallback;
  bool _isListening = false;
  
  factory ShakeSOSService() {
    return _instance;
  }
  
  ShakeSOSService._internal() {
    _setupMethodChannelListener();
  }
  
  /**
   * Setup method channel listener for native SOS events
   */
  void _setupMethodChannelListener() {
    debugPrint('═══════════════════════════════════════════');
    debugPrint('[FLUTTER_SETUP] Setting up Method Channel listener');
    debugPrint('  → Channel: ${platform.name}');
    
    platform.setMethodCallHandler((MethodCall call) async {
      debugPrint('═══════════════════════════════════════════');
      debugPrint('[METHOD_CALL_FLUTTER] Received from native: ${call.method}');
      debugPrint('  → Arguments: ${call.arguments}');
      debugPrint('  → Time: ${DateTime.now()}');
      
      if (call.method == "onShakeDetected") {
        debugPrint('');
        debugPrint('╔════════════════════════════════════════╗');
        debugPrint('║  [CRITICAL] SHAKE DETECTED ON FLUTTER ║');
        debugPrint('║    Executing SOS Callback Handler      ║');
        debugPrint('╚════════════════════════════════════════╝');
        debugPrint('');
        
        if (_sosCallback != null) {
          try {
            debugPrint('[SOS_CALLBACK] Executing SOS callback...');
            await _sosCallback!();
            debugPrint('✓ [SOS_CALLBACK] SOS callback executed successfully');
          } catch (e) {
            debugPrint('✗ [SOS_CALLBACK_ERROR] Error executing SOS callback: $e');
          }
        } else {
          debugPrint('✗ [SOS_CALLBACK] No callback registered!');
        }
      } else {
        debugPrint('✗ [UNKNOWN_METHOD] Unknown method: ${call.method}');
      }
      debugPrint('═══════════════════════════════════════════');
    });
    
    debugPrint('✓ [METHOD_CHANNEL_READY] Method channel listener configured');
    debugPrint('═══════════════════════════════════════════');
  }
  
  /**
   * Request necessary permissions for shake detection
   */
  Future<bool> requestPermissions() async {
    try {
      debugPrint('═══════════════════════════════════════════');
      debugPrint('[PERMISSIONS] Requesting permissions...');
      
      final statuses = await [
        Permission.sensors,
        Permission.notification,
      ].request();
      
      debugPrint('[PERMISSIONS] Results:');
      statuses.forEach((permission, status) {
        debugPrint('  → $permission: ${status.isDenied ? 'DENIED' : status.isGranted ? 'GRANTED' : 'PENDING'}');
      });
      
      bool allGranted = statuses.values.every((status) => status.isGranted);
      
      if (allGranted) {
        debugPrint('✓ [PERMISSIONS] All permissions GRANTED');
      } else {
        debugPrint('✗ [PERMISSIONS] Some permissions DENIED');
      }
      debugPrint('═══════════════════════════════════════════');
      return allGranted;
    } catch (e) {
      debugPrint('✗ [PERMISSION_ERROR] Error requesting permissions: $e');
      return false;
    }
  }
  
  /**
   * Check if permissions are already granted
   */
  Future<bool> checkPermissions() async {
    try {
      debugPrint('[PERMISSIONS] Checking if permissions are granted...');
      final sensorStatus = await Permission.sensors.status;
      
      debugPrint('  → Sensor Permission: ${sensorStatus.isDenied ? 'DENIED' : sensorStatus.isGranted ? 'GRANTED' : 'PENDING'}');
      
      if (sensorStatus.isGranted) {
        debugPrint('✓ [PERMISSIONS] Sensor permission is GRANTED');
      } else {
        debugPrint('✗ [PERMISSIONS] Sensor permission is NOT granted');
      }
      
      return sensorStatus.isGranted;
    } catch (e) {
      debugPrint('✗ [PERMISSION_ERROR] Error checking permissions: $e');
      return false;
    }
  }
  
  /**
   * Start shake detection service
   */
  Future<bool> startShakeDetection(OnSOSTriggered callback) async {
    try {
      debugPrint('═══════════════════════════════════════════');
      debugPrint('[SHAKE_SERVICE] Starting shake detection...');
      debugPrint('  → Timestamp: ${DateTime.now()}');
      debugPrint('  → Platform: ${Platform.operatingSystem}');
      
      // Check and request permissions first
      bool hasPermission = await checkPermissions();
      if (!hasPermission) {
        debugPrint('[PERMISSIONS] Permissions not granted, requesting...');
        hasPermission = await requestPermissions();
        if (!hasPermission) {
          debugPrint('✗ [START_ERROR] Permissions not granted for shake detection');
          debugPrint('═══════════════════════════════════════════');
          return false;
        }
      }
      
      _sosCallback = callback;
      debugPrint('[CALLBACK] SOS callback registered');
      
      if (Platform.isAndroid) {
        debugPrint('[NATIVE_CALL] Calling native startShakeDetection()...');
        try {
          final result = await platform.invokeMethod('startShakeDetection');
          _isListening = true;
          debugPrint('✓ [START_SUCCESS] Native returned: $result');
          debugPrint('✓ [SHAKE_DETECTION] NOW ACTIVE - Listening for shake events');
          debugPrint('═══════════════════════════════════════════');
          return true;
        } catch (e) {
          debugPrint('✗ [NATIVE_ERROR] Native method failed: $e');
          return false;
        }
      } else {
        debugPrint('✗ [PLATFORM_ERROR] Platform not Android: ${Platform.operatingSystem}');
        return false;
      }
    } catch (e) {
      debugPrint('✗ [START_ERROR] Error starting shake detection: $e');
      return false;
    }
  }
  
  /**
   * Stop shake detection service
   */
  Future<bool> stopShakeDetection() async {
    try {
      debugPrint('═══════════════════════════════════════════');
      debugPrint('[SHAKE_SERVICE] Stopping shake detection...');
      debugPrint('  → Timestamp: ${DateTime.now()}');
      
      if (Platform.isAndroid) {
        debugPrint('[NATIVE_CALL] Calling native stopShakeDetection()...');
        try {
          final result = await platform.invokeMethod('stopShakeDetection');
          _isListening = false;
          debugPrint('✓ [STOP_SUCCESS] Native returned: $result');
          debugPrint('✓ [SHAKE_DETECTION] NOW INACTIVE - Listener stopped');
          debugPrint('═══════════════════════════════════════════');
          return true;
        } catch (e) {
          debugPrint('✗ [NATIVE_ERROR] Native method failed: $e');
          return false;
        }
      }
      
      return false;
    } catch (e) {
      debugPrint('✗ [STOP_ERROR] Error stopping shake detection: $e');
      return false;
    }
  }
  
  /**
   * Check if shake detection is currently active
   */
  Future<bool> isShakeDetectionActive() async {
    try {
      debugPrint('[SHAKE_SERVICE] Checking if detection is active...');
      
      if (Platform.isAndroid) {
        final result = await platform.invokeMethod('isShakeDetectionActive');
        final isActive = result as bool;
        
        debugPrint('  → Service Active: ${isActive ? 'YES ✓' : 'NO ✗'}');
        return isActive;
      }
      
      return false;
    } catch (e) {
      debugPrint('✗ [STATUS_ERROR] Error checking shake detection status: $e');
      return false;
    }
  }
  
  /**
   * Get listening status
   */
  bool get isListening => _isListening;
  
  /**
   * Set SOS callback - can be used to update callback without restarting
   */
  void setSOSCallback(OnSOSTriggered callback) {
    debugPrint('[CALLBACK] Updating SOS callback');
    _sosCallback = callback;
    debugPrint('✓ [CALLBACK] SOS callback updated successfully');
  }
}
