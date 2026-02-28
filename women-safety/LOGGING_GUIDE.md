# SOS Shake Detection - Comprehensive Logging Guide

## 📊 Overview

Complete logging has been added to **all components** of the shake detection system to help track and debug the entire flow. Logs are categorized by severity level and marked with prefixes for easy filtering and identification.

## 🎯 Log Levels & Prefixes

### Android Native Logs
```
Log.d()  → Debug (Detailed info) → [TAG_NAME] or message
Log.i()  → Info (Important info) → ✓ [ACTION] Success messages
Log.w()  → Warning (Issues)      → [ACTION] or ⚠️ 
Log.e()  → Error (Critical)      → ✗ [ACTION] or [CRITICAL]
Log.v()  → Verbose (Very detail) → [SENSOR_DATA] Raw sensor values
```

### Flutter Logs
```
debugPrint() → All Flutter logs are timestamped and prefixed
✓ = Success
✗ = Failure/Error
═══════════════════════════════════════════ = Section separator
```

## 📱 Android Logging Tags

### 1. **ShakeSensorListener** (TAG: "ShakeSensorListener")
Raw accelerometer sensor data and shake detection logic.

#### Sensor Data Logs (Every ~100ms):
```
[SENSOR_DATA] X=0.45, Y=0.32, Z=9.85 | Acceleration=9.87 | GForce=-0.06 | IsShaking=false | Threshold=25.00
```
Shows: X, Y, Z acceleration, total acceleration, G-Force, shake status, and current threshold.

#### Shake Detection Logs:
```
[SHAKE_RESET] Time window exceeded (523ms). Resetting counter.
[SHAKE_DETECTED] Count: 1/2 | GForce: 28.54 | Threshold: 25.00 | TimeWindow: 500ms
[SHAKE_PENDING] Need 1 more shake(s)

╔════════════════════════════════════════╗
║     🚨 SHAKE THRESHOLD REACHED! 🚨     ║
║  Triggering SOS SOS SOS SOS SOS SOS  ║
╚════════════════════════════════════════╝
```

---

### 2. **ShakeDetectionService** (TAG: "ShakeDetectionService")
Service lifecycle, sensor registration, and SOS broadcast.

#### Service Creation:
```
═══════════════════════════════════════════
[SERVICE_LIFECYCLE] onCreate() called
═══════════════════════════════════════════

[ACCELEROMETER_INFO] Sensor Found!
  → Name: LSM6DS3 Accelerometer
  → Vendor: STMicroelectronics
  → Power: 0.50mA
  → Resolution: 0.00 m/s²
  → Max Range: 156.94 m/s²

[ACCELEROMETER_ERROR] Accelerometer sensor NOT found on this device!
```

#### Service Start:
```
═══════════════════════════════════════════
[SERVICE_LIFECYCLE] onStartCommand() called
  → startId: 1
  → flags: 0
═══════════════════════════════════════════

[LISTENER_CREATION] ShakeSensorListener created

✓ [SENSOR_REGISTRATION_SUCCESS] Accelerometer listener registered
  → Sensor: LSM6DS3 Accelerometer
  → Delay Mode: SENSOR_DELAY_NORMAL (200ms)
  → Status: NOW LISTENING FOR SHAKE EVENTS

✗ [SENSOR_REGISTRATION_FAILED] Could not register listener
✗ [CRITICAL_ERROR] Accelerometer not available - cannot register listener
```

#### SOS Broadcast:
```
═══════════════════════════════════════════
[SOS_BROADCAST] Broadcasting SOS_TRIGGERED intent
  → Action: com.example.safety_pal.SOS_TRIGGERED
  → Time: 1708952451234

✓ [BROADCAST_SENT] SOS Intent successfully broadcasted to MainActivity
═══════════════════════════════════════════
```

#### Service Destruction:
```
═══════════════════════════════════════════
[SERVICE_LIFECYCLE] onDestroy() called

✓ [LISTENER_UNREGISTERED] Sensor listener successfully unregistered
✗ [CLEANUP_WARNING] SensorManager or listener was null

[SERVICE_STATUS] Service stopped - Shake detection is now INACTIVE
═══════════════════════════════════════════
```

---

### 3. **MainActivity** (TAG: "MainActivity")
Method channel setup, service control, and broadcast reception.

#### Flutter Engine Setup:
```
═══════════════════════════════════════════
[FLUTTER_ENGINE] Configuring Flutter Engine
═══════════════════════════════════════════

[METHOD_CHANNEL] Created: com.example.safety_pal/shake

[SETUP_COMPLETE] Method channel configured successfully
═══════════════════════════════════════════
```

#### Method Channel Calls:
```
═══════════════════════════════════════════
[METHOD_CALL] Received: startShakeDetection
  → Arguments: null

✓ [START_SHAKE_DETECTION] Method called
  ✓ [SERVICE_STARTED] ShakeDetectionService started successfully

✓ [STOP_SHAKE_DETECTION] Method called
  ✓ [SERVICE_STOPPED] ShakeDetectionService stopped successfully

[CHECK_STATUS] Service running: true
═══════════════════════════════════════════
```

#### Service Status Check:
```
[CHECK_SERVICE_STATUS] Checking if ShakeDetectionService is running...
  → Total running services: 45

✓ [SERVICE_RUNNING] ShakeDetectionService is ACTIVE
  → Process ID: 12345
  → Foreground: true

✗ [SERVICE_NOT_RUNNING] ShakeDetectionService is INACTIVE
```

#### Broadcast Reception:
```
═══════════════════════════════════════════
[BROADCAST_RECEIVED] BroadcastReceiver.onReceive() called
  → Action: com.example.safety_pal.SOS_TRIGGERED
  → Time: 1708952452345

╔════════════════════════════════════════╗
║  [CRITICAL] SOS EVENT RECEIVED!       ║
║         Invoking Flutter Method        ║
║            onShakeDetected()           ║
╚════════════════════════════════════════╝

✓ [FLUTTER_METHOD_INVOKED] Successfully called onShakeDetected()
✗ [FLUTTER_ERROR] Failed to invoke method: [error details]
═══════════════════════════════════════════
```

---

## 🐦 Flutter Logging Tags

### 1. **shake_sos_service.dart**
Flutter service layer for native communication.

#### Initialization:
```
═══════════════════════════════════════════
[FLUTTER_SETUP] Setting up Method Channel listener
  → Channel: com.example.safety_pal/shake

✓ [METHOD_CHANNEL_READY] Method channel listener configured
═══════════════════════════════════════════
```

#### Permissions:
```
═══════════════════════════════════════════
[PERMISSIONS] Requesting permissions...
[PERMISSIONS] Results:
  → Permission.sensors: GRANTED
  → Permission.notification: GRANTED

✓ [PERMISSIONS] All permissions GRANTED
✗ [PERMISSIONS] Some permissions DENIED

[PERMISSIONS] Checking if permissions are granted...
  → Sensor Permission: GRANTED
✓ [PERMISSIONS] Sensor permission is GRANTED
═══════════════════════════════════════════
```

#### Start/Stop Detection:
```
═══════════════════════════════════════════
[SHAKE_SERVICE] Starting shake detection...
  → Timestamp: 2026-02-27 10:30:45.123456
  → Platform: android

[PERMISSIONS] Permissions not granted, requesting...
[CALLBACK] SOS callback registered
[NATIVE_CALL] Calling native startShakeDetection()...

✓ [START_SUCCESS] Native returned: Shake detection started
✓ [SHAKE_DETECTION] NOW ACTIVE - Listening for shake events
═══════════════════════════════════════════

[SHAKE_SERVICE] Stopping shake detection...
  → Timestamp: 2026-02-27 10:31:15.456789

[NATIVE_CALL] Calling native stopShakeDetection()...
✓ [STOP_SUCCESS] Native returned: Shake detection stopped
✓ [SHAKE_DETECTION] NOW INACTIVE - Listener stopped
═══════════════════════════════════════════
```

#### Status Check:
```
[SHAKE_SERVICE] Checking if detection is active...
  → Service Active: YES ✓
```

#### SOS Callback:
```
═══════════════════════════════════════════
[METHOD_CALL_FLUTTER] Received from native: onShakeDetected
  → Arguments: null
  → Time: 2026-02-27 10:31:45.890123

╔════════════════════════════════════════╗
║  [CRITICAL] SHAKE DETECTED ON FLUTTER ║
║    Executing SOS Callback Handler      ║
╚════════════════════════════════════════╝

[SOS_CALLBACK] Executing SOS callback...
✓ [SOS_CALLBACK] SOS callback executed successfully
✗ [SOS_CALLBACK_ERROR] Error executing SOS callback: [error details]
═══════════════════════════════════════════
```

---

## 📊 Complete Flow Log Example

### Scenario: User enables shake detection and shakes phone

```
══════════ [ FLUTTER ] ══════════════════════
═══════════════════════════════════════════════
[FLUTTER_SETUP] Setting up Method Channel listener
  → Channel: com.example.safety_pal/shake

═══════════════════════════════════════════════
[SHAKE_SERVICE] Starting shake detection...
  → Timestamp: 2026-02-27 10:30:45.123456
  → Platform: android

[PERMISSIONS] Checking if permissions are granted...
  → Sensor Permission: GRANTED
✓ [PERMISSIONS] Sensor permission is GRANTED

[CALLBACK] SOS callback registered
[NATIVE_CALL] Calling native startShakeDetection()...

══════════ [ NATIVE ANDROID ] ════════════════
═══════════════════════════════════════════════
[METHOD_CALL] Received: startShakeDetection
  → Arguments: null

✓ [START_SHAKE_DETECTION] Method called

═══════════════════════════════════════════════
[SERVICE_LIFECYCLE] onCreate() called
═══════════════════════════════════════════════

[ACCELEROMETER_INFO] Sensor Found!
  → Name: LSM6DS3 Accelerometer
  → Vendor: STMicroelectronics

═══════════════════════════════════════════════
[SERVICE_LIFECYCLE] onStartCommand() called
  → startId: 1
  → flags: 0

[LISTENER_CREATION] ShakeSensorListener created
✓ [SENSOR_REGISTRATION_SUCCESS] Accelerometer listener registered

══════════ [ SENSOR READINGS ] ════════════════
[SENSOR_DATA] X=0.45, Y=0.32, Z=9.85 | Acceleration=9.87 | GForce=-0.06 | IsShaking=false
[SENSOR_DATA] X=0.48, Y=0.35, Z=9.82 | Acceleration=9.84 | GForce=-0.03 | IsShaking=false
[SENSOR_DATA] X=0.50, Y=0.40, Z=9.80 | Acceleration=9.82 | GForce=-0.01 | IsShaking=false

══════════ [ SHAKE DETECTED! ] ═════════════════
[SENSOR_DATA] X=15.23, Y=20.45, Z=28.67 | Acceleration=36.45 | GForce=26.64 | IsShaking=true
[SHAKE_DETECTED] Count: 1/2 | GForce: 26.64 | Threshold: 25.00 | TimeWindow: 500ms
[SHAKE_PENDING] Need 1 more shake(s)

[SENSOR_DATA] X=-12.34, Y=-18.90, Z=-25.12 | Acceleration=33.42 | GForce=23.61 | IsShaking=false
[SENSOR_DATA] X=0.45, Y=0.32, Z=9.85 | Acceleration=9.87 | GForce=-0.06 | IsShaking=false
[SENSOR_DATA] X=20.15, Y=18.67, Z=31.23 | Acceleration=39.45 | GForce=29.64 | IsShaking=true
[SHAKE_DETECTED] Count: 2/2 | GForce: 29.64 | Threshold: 25.00 | TimeWindow: 500ms

╔════════════════════════════════════════╗
║     🚨 SHAKE THRESHOLD REACHED! 🚨     ║
║  Triggering SOS SOS SOS SOS SOS SOS  ║
╚════════════════════════════════════════╝

║ [CRITICAL] SOS CALLBACK TRIGGERED!    ║
║   Shake Detection Threshold Reached    ║
║          Calling triggerSOS()          ║
╚════════════════════════════════════════╝

═══════════════════════════════════════════════
[SOS_BROADCAST] Broadcasting SOS_TRIGGERED intent
  → Action: com.example.safety_pal.SOS_TRIGGERED
  → Time: 1708952451234

✓ [BROADCAST_SENT] SOS Intent successfully broadcasted to MainActivity

══════════ [ BROADCAST RECEPTION ] ════════════
═══════════════════════════════════════════════
[BROADCAST_RECEIVED] BroadcastReceiver.onReceive() called
  → Action: com.example.safety_pal.SOS_TRIGGERED
  → Time: 1708952451235

╔════════════════════════════════════════╗
║  [CRITICAL] SOS EVENT RECEIVED!       ║
║         Invoking Flutter Method        ║
║            onShakeDetected()           ║
╚════════════════════════════════════════╝

✓ [FLUTTER_METHOD_INVOKED] Successfully called onShakeDetected()

══════════ [ FLUTTER CALLBACK ] ════════════════
═══════════════════════════════════════════════
[METHOD_CALL_FLUTTER] Received from native: onShakeDetected
  → Arguments: null
  → Time: 2026-02-27 10:31:45.890123

╔════════════════════════════════════════╗
║  [CRITICAL] SHAKE DETECTED ON FLUTTER ║
║    Executing SOS Callback Handler      ║
╚════════════════════════════════════════╝

[SOS_CALLBACK] Executing SOS callback...
✓ [SOS_CALLBACK] SOS callback executed successfully
═══════════════════════════════════════════════
```

---

## 🔍 How to View Logs

### Android Studio Logcat
```bash
# View all shake detection logs
adb logcat | grep -E "ShakeDetectionService|ShakeSensorListener|MainActivity"

# View only errors
adb logcat | grep "✗\|ERROR\|FAILED"

# View only success messages
adb logcat | grep "✓\|SUCCESS"

# Follow service lifecycle
adb logcat | grep "SERVICE_LIFECYCLE"
```

### Terminal/Command Line
```bash
# Real-time log streaming
adb logcat ShakeSensorListener:* ShakeDetectionService:* MainActivity:*

# Save to file
adb logcat > shake_detection_logs.txt

# Filter by timestamp (today's logs)
adb logcat -G 16M  # Increase buffer size
```

### VS Code / Flutter Output
```
// Appears in the Debug Console
✓ [START_SUCCESS] Native returned: Shake detection started
✓ [SHAKE_DETECTION] NOW ACTIVE - Listening for shake events
```

---

## 🔴 Common Issues & Log Indicators

### Issue: Shake not detected
**Check logs for:**
- `[ACCELEROMETER_ERROR]` → Device doesn't have accelerometer
- `[SENSOR_REGISTRATION_FAILED]` → Failed to register listener
- `[SENSOR_DATA]` with `IsShaking=false` → Sensor working but shake threshold too high

### Issue: Permission denied
**Check logs for:**
- `[PERMISSIONS] Some permissions DENIED` → User denied permissions
- Ask user to grant in Settings → Apps → Permissions

### Issue: Service crashes
**Check logs for:**
- `✗ [NATIVE_ERROR]` → Exception in service
- `[SERVICE_LIFECYCLE] onDestroy()` → Service stopped unexpectedly
- Check for ANR (Application Not Responding) errors

### Issue: Flutter not receiving SOS
**Check logs for:**
- `✗ [FLUTTER_METHOD_INVOKED]` → Failed to call Flutter method
- `✗ [SOS_CALLBACK_ERROR]` → Error in your SOS callback
- Ensure callback is registered with `updateSOSCallback()`

---

## ✅ Success Indicators

Complete success log chain:
```
✓ [PERMISSIONS] All permissions GRANTED
✓ [START_SUCCESS] Native returned: Shake detection started
✓ [SERVICE_STARTED] ShakeDetectionService started successfully
✓ [SENSOR_REGISTRATION_SUCCESS] Accelerometer listener registered
✓ [SHAKE_DETECTION] NOW ACTIVE
  → (Waiting for shake...)
[SHAKE_DETECTED] Count: X/Y | GForce: X.XX
  → (More shakes until threshold...)
✓ [BROADCAST_SENT] SOS Intent successfully broadcasted
✓ [FLUTTER_METHOD_INVOKED] Successfully called onShakeDetected()
✓ [SOS_CALLBACK] SOS callback executed successfully
```

---

## 📝 Log Files Location

### Android
- Logcat buffer (in real-time via `adb logcat`)
- Device logs: `/data/anr/`, `/data/tombstones/`

### Run Configuration
For persistent logging, add to your build.gradle or use Logcat file output.

---

## 🎓 Tips for Debugging

1. **Always start fresh:** Use `adb logcat -c` to clear logs before testing
2. **Use timestamps:** Log timestamps help match events with user actions
3. **Follow the flow:** Trace logs from Flutter → Native → Sensor → Broadcast → Back to Flutter
4. **Box markers:** `═══════════` markers separate major sections for easy scanning
5. **Color code in IDE:** 
   - ✓ = Green (success)
   - ✗ = Red (error)
   - ⚠️ = Yellow (warning)
   - [TAG] = Blue (info)

That's it! Now you have complete visibility into what's happening at every step of the shake detection system. 🎯
