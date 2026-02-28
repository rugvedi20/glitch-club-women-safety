package com.example.safety_pal;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.hardware.Sensor;
import android.hardware.SensorManager;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.Vibrator;
import android.os.VibrationEffect;
import android.util.Log;
import android.widget.Toast;

import androidx.core.app.NotificationCompat;

import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

public class ShakeDetectionService extends Service {
    private static final String TAG = "ShakeDetectionService";
    private static final String CHANNEL_ID = "shake_detection_channel";
    private static final int NOTIFICATION_ID = 1001;
    
    private SensorManager sensorManager;
    private Sensor accelerometer;
    private ShakeSensorListener shakeSensorListener;
    
    @Override
    public void onCreate() {
        super.onCreate();
        Log.d(TAG, "═══════════════════════════════════════════");
        Log.d(TAG, "[SERVICE_LIFECYCLE] onCreate() called");
        Log.d(TAG, "═══════════════════════════════════════════");
        
        // Initialize sensor manager
        sensorManager = (SensorManager) getSystemService(Context.SENSOR_SERVICE);
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
        
        if (accelerometer != null) {
            Log.i(TAG, "[ACCELEROMETER_INFO] Sensor Found!");
            Log.i(TAG, String.format(
                "  → Name: %s\n  → Vendor: %s\n  → Power: %.2fmA\n  → Resolution: %.2f m/s²\n  → Max Range: %.2f m/s²",
                accelerometer.getName(),
                accelerometer.getVendor(),
                accelerometer.getPower(),
                accelerometer.getResolution(),
                accelerometer.getMaximumRange()
            ));
        } else {
            Log.e(TAG, "[ACCELEROMETER_ERROR] Accelerometer sensor NOT found on this device!");
        }
        
        // Create notification channel for Android 8.0+
        createNotificationChannel();
        
        // Start foreground service with notification
        startForeground(NOTIFICATION_ID, createNotification());
        
        Log.i(TAG, "[SERVICE_STATUS] Foreground Service started successfully");
        Log.i(TAG, "[NOTIFICATION_ID] " + NOTIFICATION_ID);
        Log.d(TAG, "═══════════════════════════════════════════");
    }
    
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Log.d(TAG, "═══════════════════════════════════════════");
        Log.d(TAG, "[SERVICE_LIFECYCLE] onStartCommand() called");
        Log.d(TAG, "  → startId: " + startId);
        Log.d(TAG, "  → flags: " + flags);
        Log.d(TAG, "═══════════════════════════════════════════");
        
        // Create shake listener
        shakeSensorListener = new ShakeSensorListener(() -> {
            Log.e(TAG, "\n╔════════════════════════════════════════╗\n" +
                "║ [CRITICAL] SOS CALLBACK TRIGGERED!    ║\n" +
                "║   Shake Detection Threshold Reached    ║\n" +
                "║          Calling triggerSOS()          ║\n" +
                "╚════════════════════════════════════════╝");
            triggerSOS();
        });
        Log.d(TAG, "[LISTENER_CREATION] ShakeSensorListener created");
        
        // Register the sensor listener
        if (accelerometer != null) {
            boolean registered = sensorManager.registerListener(
                    shakeSensorListener,
                    accelerometer,
                    SensorManager.SENSOR_DELAY_NORMAL
            );
            
            if (registered) {
                Log.i(TAG, "✓ [SENSOR_REGISTRATION_SUCCESS] Accelerometer listener registered");
                Log.i(TAG, "  → Sensor: " + accelerometer.getName());
                Log.i(TAG, "  → Delay Mode: SENSOR_DELAY_NORMAL (200ms)");
                Log.i(TAG, "  → Status: NOW LISTENING FOR SHAKE EVENTS");
            } else {
                Log.e(TAG, "✗ [SENSOR_REGISTRATION_FAILED] Could not register listener");
            }
        } else {
            Log.e(TAG, "✗ [CRITICAL_ERROR] Accelerometer not available - cannot register listener");
        }
        
        Log.d(TAG, "═══════════════════════════════════════════");
        
        // Return START_STICKY to restart the service if killed
        return START_STICKY;
    }
    
    @Override
    public void onDestroy() {
        super.onDestroy();
        Log.d(TAG, "═══════════════════════════════════════════");
        Log.w(TAG, "[SERVICE_LIFECYCLE] onDestroy() called");
        
        // Unregister the sensor listener
        if (sensorManager != null && shakeSensorListener != null) {
            sensorManager.unregisterListener(shakeSensorListener);
            Log.i(TAG, "✓ [LISTENER_UNREGISTERED] Sensor listener successfully unregistered");
        } else {
            Log.w(TAG, "✗ [CLEANUP_WARNING] SensorManager or listener was null");
        }
        
        Log.w(TAG, "[SERVICE_STATUS] Service stopped - Shake detection is now INACTIVE");
        Log.d(TAG, "═══════════════════════════════════════════");
    }
    
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }
    
    /**
     * Create a notification for the foreground service
     */
    private Notification createNotification() {
        Intent notificationIntent = new Intent(this, MainActivity.class);
        PendingIntent pendingIntent = PendingIntent.getActivity(this, 0, notificationIntent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        
        return new NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("Safety Pal - SOS Active")
                .setContentText("Shake detection is active. Your safety is our priority.")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentIntent(pendingIntent)
                .setOngoing(true)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .build();
    }
    
    /**
     * Create notification channel for Android 8.0+
     */
    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            CharSequence name = "Shake Detection";
            String description = "Notifications for shake detection";
            int importance = NotificationManager.IMPORTANCE_DEFAULT;
            
            NotificationChannel channel = new NotificationChannel(CHANNEL_ID, name, importance);
            channel.setDescription(description);
            
            NotificationManager notificationManager = getSystemService(NotificationManager.class);
            if (notificationManager != null) {
                notificationManager.createNotificationChannel(channel);
            }
        }
    }
    
    /**
     * Trigger SOS action - communicate with Flutter
     */
    private void triggerSOS() {
        Log.d(TAG, "═══════════════════════════════════════════");
        Log.e(TAG, "[SOS_BROADCAST] Broadcasting SOS_TRIGGERED intent");
        Log.d(TAG, "  → Action: com.example.safety_pal.SOS_TRIGGERED");
        Log.d(TAG, "  → Time: " + System.currentTimeMillis());
        
        // Provide vibration feedback to user
        provideVibrationFeedback();
        
        // Show toast notification to user
        showToastNotification();
        
        // Log activation event
        logActivation("shake");
        
        // Send broadcast to notify the app
        Intent sosIntent = new Intent("com.example.safety_pal.SOS_TRIGGERED");
        sendBroadcast(sosIntent);
        
        Log.i(TAG, "✓ [BROADCAST_SENT] SOS Intent successfully broadcasted to MainActivity");
        Log.d(TAG, "═══════════════════════════════════════════");
    }
    
    /**
     * Provide vibration feedback when shake is detected
     */
    private void provideVibrationFeedback() {
        try {
            Vibrator vibrator = (Vibrator) getSystemService(VIBRATOR_SERVICE);
            if (vibrator != null && vibrator.hasVibrator()) {
                Log.d(TAG, "[VIBRATION] Providing haptic feedback");
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    // Use VibrationEffect for Android 8.0+
                    vibrator.vibrate(VibrationEffect.createOneShot(400, VibrationEffect.DEFAULT_AMPLITUDE));
                } else {
                    // Fallback for older Android versions
                    vibrator.vibrate(400);
                }
                Log.d(TAG, "[VIBRATION] Vibration executed");
            } else {
                Log.w(TAG, "[VIBRATION] Vibrator not available");
            }
        } catch (Exception e) {
            Log.e(TAG, "[VIBRATION_ERROR] Failed to vibrate: " + e.getMessage());
        }
    }
    
    /**
     * Show toast notification to user
     */
    private void showToastNotification() {
        try {
            new Handler(Looper.getMainLooper()).post(() -> {
                try {
                    Toast.makeText(
                        ShakeDetectionService.this,
                        "🚨 SHAKE DETECTED! Triggering SOS...",
                        Toast.LENGTH_LONG
                    ).show();
                    Log.d(TAG, "[TOAST] Toast notification displayed");
                } catch (Exception e) {
                    Log.e(TAG, "[TOAST_ERROR] Failed to show toast: " + e.getMessage());
                }
            });
        } catch (Exception e) {
            Log.e(TAG, "[TOAST_ERROR] Failed to create handler for toast: " + e.getMessage());
        }
    }
    
    /**
     * Log activation event to SharedPreferences with JSON format
     */
    private void logActivation(String type) {
        try {
            Log.d(TAG, "[ACTIVATION_LOG] Logging activation event: " + type);
            
            SharedPreferences prefs = getSharedPreferences("safety_pal_prefs", MODE_PRIVATE);
            
            // Create activation event JSON object
            JSONObject activationEvent = new JSONObject();
            activationEvent.put("type", type);
            activationEvent.put("time", System.currentTimeMillis());
            activationEvent.put("timestamp", new java.text.SimpleDateFormat("yyyy-MM-dd HH:mm:ss").format(new java.util.Date()));
            
            // Get existing activation log array
            String existingLog = prefs.getString("activation_log", null);
            JSONArray activationArray;
            
            if (existingLog != null) {
                try {
                    activationArray = new JSONArray(existingLog);
                } catch (JSONException e) {
                    Log.w(TAG, "[ACTIVATION_LOG] Failed to parse existing log, creating new array");
                    activationArray = new JSONArray();
                }
            } else {
                activationArray = new JSONArray();
            }
            
            // Add new event to array
            activationArray.put(activationEvent);
            
            // Save back to preferences
            prefs.edit()
                    .putString("activation_log", activationArray.toString())
                    .putLong("last_activation_time", System.currentTimeMillis())
                    .apply();
            
            Log.i(TAG, "✓ [ACTIVATION_LOG] Activation logged: " + activationEvent.toString());
            
            // Broadcast activation event for Flutter to receive
            Intent activationIntent = new Intent("com.example.safety_pal.ACTIVATION_EVENT");
            activationIntent.putExtra("type", type);
            activationIntent.putExtra("time", System.currentTimeMillis());
            sendBroadcast(activationIntent);
            Log.d(TAG, "[BROADCAST_ACTIVATION] Activation event broadcasted for Flutter");
            
        } catch (Exception e) {
            Log.e(TAG, "[ACTIVATION_LOG_ERROR] Failed to log activation: " + e.getMessage(), e);
        }
    }
}
