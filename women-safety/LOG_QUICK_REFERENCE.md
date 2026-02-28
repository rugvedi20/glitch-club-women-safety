# Shake Detection - Quick Log Reference

## 🚨 Critical Logs You MUST See

These indicate successful shake detection flow:

### ✓ Service Starting
```
✓ [SERVICE_STARTED] ShakeDetectionService started successfully
✓ [SENSOR_REGISTRATION_SUCCESS] Accelerometer listener registered
✓ [SHAKE_DETECTION] NOW ACTIVE - Listening for shake events
```

### ✓ Shake Detected
```
[SHAKE_DETECTED] Count: 1/2 | GForce: 26.64 | Threshold: 25.00
[SHAKE_DETECTED] Count: 2/2 | GForce: 29.64 | Threshold: 25.00
╔════════════════════════════════════════╗
║     🚨 SHAKE THRESHOLD REACHED! 🚨     ║
╚════════════════════════════════════════╝
```

### ✓ Broadcast Sent
```
✓ [BROADCAST_SENT] SOS Intent successfully broadcasted to MainActivity
```

### ✓ Flutter Callback
```
✓ [FLUTTER_METHOD_INVOKED] Successfully called onShakeDetected()
✓ [SOS_CALLBACK] SOS callback executed successfully
```

---

## ❌ Error Logs to Watch For

### Accelerometer Issues
```
❌ [ACCELEROMETER_ERROR] Accelerometer sensor NOT found on this device!
```
→ **Solution:** Device doesn't have accelerometer sensor

### Permission Issues
```
❌ [PERMISSIONS] Some permissions DENIED
✗ [PERMISSION_ERROR] Error requesting permissions
```
→ **Solution:** Check app permissions in Android Settings

### Service Not Starting
```
❌ [SERVICE_ERROR] Failed to start service
✗ [SENSOR_REGISTRATION_FAILED] Could not register listener
```
→ **Solution:** Check if service declaration is in AndroidManifest.xml

### Shake Not Detected
```
[SENSOR_DATA] ... | IsShaking=false | Threshold=25.00
[SHAKE_PENDING] Need 2 more shake(s)
```
→ **Solution:** Shake harder or lower SHAKE_THRESHOLD in ShakeSensorListener.java

### Flutter Not Receiving
```
✗ [FLUTTER_ERROR] Failed to invoke method
✗ [SOS_CALLBACK_ERROR] Error executing SOS callback
```
→ **Solution:** Ensure SOS callback is properly registered

---

## 🔍 Quick Diagnosis Flow

### Step 1: Check Service Started
```bash
adb logcat | grep "SERVICE_STARTED\|SERVICE_ERRORS"
```
If you don't see `✓ [SERVICE_STARTED]`:
- Check AndroidManifest.xml has `<service>` declaration
- Check for permission errors above it

### Step 2: Check Sensor Registration
```bash
adb logcat | grep "SENSOR_REGISTRATION"
```
If you see `[SENSOR_REGISTRATION_FAILED]`:
- Device may not have accelerometer
- Or permissions not granted

### Step 3: Check Sensor Data
```bash
adb logcat | grep "SENSOR_DATA"
```
You should see continuous data like:
```
[SENSOR_DATA] X=0.45, Y=0.32, Z=9.85 | Acceleration=9.87
```
If no data appears:
- Service isn't running (check Step 1)
- Sensor registration failed (check Step 2)

### Step 4: Check Shake Detection
```bash
adb logcat | grep "SHAKE_DETECTED\|SHAKE_PENDING"
```
When you shake phone, it should show:
```
[SHAKE_DETECTED] Count: 1/2
[SHAKE_DETECTED] Count: 2/2
🚨 SHAKE THRESHOLD REACHED! 🚨
```
If not appearing:
- Shake harder or lower threshold
- Check sensor sensitivity settings

### Step 5: Check Broadcast
```bash
adb logcat | grep "SOS_BROADCAST\|BROADCAST_SENT"
```
Should see:
```
✓ [BROADCAST_SENT] SOS Intent successfully broadcasted
```

### Step 6: Check Flutter Reception
```bash
adb logcat | grep "BROADCAST_RECEIVED\|FLUTTER_METHOD_INVOKED"
```
Should see:
```
✓ [FLUTTER_METHOD_INVOKED] Successfully called onShakeDetected()
✓ [SOS_CALLBACK] SOS callback executed successfully
```

---

## 📊 Complete Log Chain (Copy/Paste for Reference)

```
// 1. Service Starting
[SERVICE_LIFECYCLE] onCreate() called
[ACCELEROMETER_INFO] Sensor Found!
[SERVICE_LIFECYCLE] onStartCommand() called
[LISTENER_CREATION] ShakeSensorListener created
✓ [SENSOR_REGISTRATION_SUCCESS] Accelerometer listener registered

// 2. Sensor Readings
[SENSOR_DATA] X=0.45, Y=0.32, Z=9.85 | IsShaking=false
[SENSOR_DATA] X=0.48, Y=0.35, Z=9.82 | IsShaking=false

// 3. Shake Detected
[SHAKE_DETECTED] Count: 1/2 | GForce: 26.64
[SHAKE_DETECTED] Count: 2/2 | GForce: 29.64
🚨 SHAKE THRESHOLD REACHED! 🚨

// 4. SOS Triggered
✓ [BROADCAST_SENT] SOS Intent successfully broadcasted

// 5. Flutter Receives
✓ [FLUTTER_METHOD_INVOKED] Successfully called onShakeDetected()
✓ [SOS_CALLBACK] SOS callback executed successfully
```

---

## 🚀 Useful Adb Commands

```bash
# View all shake logs
adb logcat | grep -i shake

# View errors only
adb logcat | grep -E "✗|ERROR|FAILED"

# View success messages
adb logcat | grep -E "✓|SUCCESS"

# Save logs to file
adb logcat > logs.txt &

# Clear logs
adb logcat -c

# Follow service lifecycle
adb logcat | grep SERVICE_LIFECYCLE

# See which permissions were denied
adb logcat | grep -i permission

# Filter by specific tag
adb logcat ShakeSensorListener:V MainActivity:V ShakeDetectionService:V

# Real-time grep with context
adb logcat | grep -A 3 -B 3 "SHAKE_DETECTED"
```

---

## 💡 What Each Component Does

|Component|Logs with|What it does|
|---------|-----------|-----------|
|ShakeSensorListener|[SENSOR_DATA], [SHAKE_DETECTED]|Reads accelerometer, detects shakes|
|ShakeDetectionService|[SERVICE_LIFECYCLE], [SENSOR_REGISTRATION]|Manages service & sensor|
|MainActivity|[METHOD_CALL], [BROADCAST_RECEIVED]|Receives native calls & broadcasts|
|shake_sos_service.dart|[SHAKE_SERVICE], [NATIVE_CALL]|Calls native from Flutter|
|ShakeSOSProvider|[CALLBACKS], [STATUS]|Manages Flutter UI state|

---

## ⚡ One-Liner Diagnosis

```bash
# Everything in one view
adb logcat | grep -E "ShakeSensorListener|ShakeDetectionService|MainActivity" | grep -v SENSOR_DATA
```

This shows you everything EXCEPT raw sensor data (which is verbose).

---

## 🎯 Normal vs Abnormal

### ✅ Normal (Good)
- Constant `[SENSOR_DATA]` logs appearing
- When phone is shaken: `[SHAKE_DETECTED]` appears
- When threshold reached: Box with 🚨 appears
- `✓ [BROADCAST_SENT]` appears
- Flutter receives callback

### ⚠️ Abnormal (Problem)
- No `[SENSOR_DATA]` = Service not running
- `[SENSOR_REGISTRATION_FAILED]` = Permissions issue
- Shake not triggering = Threshold too high
- No broadcast = Service not running
- Flutter not receiving = Broadcast receiver not registered

---

## 📞 Support Checklist

When debugging, check these in order:

- [ ] Is service started? → Look for `✓ [SERVICE_STARTED]`
- [ ] Is sensor registered? → Look for `✓ [SENSOR_REGISTRATION_SUCCESS]`
- [ ] Are we getting sensor data? → Look for `[SENSOR_DATA]`
- [ ] When shaking: do we see `[SHAKE_DETECTED]`?
- [ ] Do we see `✓ [BROADCAST_SENT]`?
- [ ] Does Flutter receive method call? → Look for `✓ [FLUTTER_METHOD_INVOKED]`
- [ ] Is callback executed? → Look for `✓ [SOS_CALLBACK]`

If any of these fail, check the error log right above it.

**Enjoy debugging! 🚀**
