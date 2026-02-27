package com.example.guess_me;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Intent;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.os.Bundle;
import android.os.PowerManager;
import android.util.Log;
import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.os.Vibrator;
import android.os.VibrationEffect;
import android.Manifest;
import android.content.pm.PackageManager;
import android.content.SharedPreferences;
import androidx.core.content.ContextCompat;
import com.google.android.gms.location.FusedLocationProviderClient;
import com.google.android.gms.location.LocationServices;
import com.google.android.gms.location.Priority;
import android.location.Location;
import androidx.core.app.NotificationCompat;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import android.speech.SpeechRecognizer;
import android.speech.RecognizerIntent;
import android.speech.RecognitionListener;
import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.Context;
import android.os.SystemClock;
import java.util.ArrayList;

public class ForegroundService extends Service implements SensorEventListener {
    public static final String CHANNEL_ID = "guessme_foreground_channel";
    private static final String TAG = "ForegroundService";
    private PowerManager.WakeLock wakeLock;
    private SensorManager sensorManager;
    private Sensor accelerometer;
    private static final boolean ENABLE_SHAKE = true; // enable shake activation
    private static final float SHAKE_THRESHOLD = 10f; // raised to require harder shakes
    private static final long SHAKE_WINDOW_MS = 2000;  // time window to count shakes
    private static final int REQUIRED_SHAKES = 4;      // need 2 shakes to trigger
    private static final long ACTIVATION_COOLDOWN_MS = 3000; // prevent rapid re-triggers
    private int shakeCount = 0;
    private long lastShakeTime = 0;
    private long lastActivationTime = 0;
    private FusedLocationProviderClient fusedLocationClient;
    // Speech recognition for hotword detection
    private SpeechRecognizer speechRecognizer;
    private Intent recognizerIntent;
    private Handler srRestartHandler;
    private static final long SR_RESTART_DELAY_MS = 800; // initial delay to restart on error
    private long srBackoffMs = SR_RESTART_DELAY_MS;
    private static final long SR_BACKOFF_MAX_MS = 8000; // max backoff
    private volatile boolean srListening = false;
    private volatile boolean srStarting = false;
    private int srFailureCount = 0;
    private static final int SR_FAILURE_THRESHOLD = 6;

    // Periodic heartbeat: saves location + timestamp so BootReceiver can detect
    // forced power-offs where ACTION_SHUTDOWN is never broadcast.
    private static final long HEARTBEAT_INTERVAL_MS = 30 * 60 * 1000L; // 30 minutes
    private Handler heartbeatHandler;
    private Runnable heartbeatRunnable;

    @Override
    public void onCreate() {
        super.onCreate();
        createNotificationChannel();
        acquireWakeLock();
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this);
        // Register shake detection only if enabled
        if (ENABLE_SHAKE) {
            sensorManager = (SensorManager) getSystemService(SENSOR_SERVICE);
            if (sensorManager != null) {
                accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER);
                if (accelerometer != null) {
                    sensorManager.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_UI);
                }
            }
        }
        // Start periodic heartbeat so forced power-off can be detected on next boot.
        startHeartbeat();
        // Start continuous speech recognition if permission available
        startSpeechRecognitionIfPermitted();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        Notification notification = new NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("GuessMe is Running")
            .setContentText("The app is running in the background and listening for activation.")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .build();
        startForeground(1, notification);
        Log.d(TAG, "Service started");
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (sensorManager != null) {
            sensorManager.unregisterListener(this);
        }
        stopSpeechRecognition();
        stopHeartbeat();
        releaseWakeLock();
        Log.d(TAG, "Service destroyed");
    }
    // SensorEventListener methods for shake detection
    @Override
    public void onSensorChanged(SensorEvent event) {
        if (!ENABLE_SHAKE) return;
        if (event.sensor.getType() == Sensor.TYPE_ACCELEROMETER) {
            float x = event.values[0];
            float y = event.values[1];
            float z = event.values[2];
            float gX = x / SensorManager.GRAVITY_EARTH;
            float gY = y / SensorManager.GRAVITY_EARTH;
            float gZ = z / SensorManager.GRAVITY_EARTH;
            float gForce = (float) Math.sqrt(gX * gX + gY * gY + gZ * gZ);
            if (gForce > SHAKE_THRESHOLD) {
                long now = System.currentTimeMillis();
                // If outside window, reset count
                if (now - lastShakeTime > SHAKE_WINDOW_MS) {
                    shakeCount = 0;
                }
                shakeCount += 1;
                lastShakeTime = now;
                Log.d(TAG, "Shake hit: count=" + shakeCount + " gForce=" + gForce);
                boolean cooldownElapsed = (now - lastActivationTime) > ACTIVATION_COOLDOWN_MS;
                if (shakeCount >= REQUIRED_SHAKES && cooldownElapsed) {
                    shakeCount = 0;
                    lastActivationTime = now;
                    onShakeDetected();
                }
            }
        }
    }

    @Override
    public void onAccuracyChanged(Sensor sensor, int accuracy) {}

    private void onShakeDetected() {
        // Vibrate to indicate activation
        Vibrator vibrator = (Vibrator) getSystemService(VIBRATOR_SERVICE);
        if (vibrator != null) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createOneShot(400, VibrationEffect.DEFAULT_AMPLITUDE));
            } else {
                vibrator.vibrate(400);
            }
        }
        // Show a Toast for user feedback
        android.os.Handler handler = new android.os.Handler(getMainLooper());
        handler.post(() -> android.widget.Toast.makeText(this, "Shake detected!", android.widget.Toast.LENGTH_SHORT).show());
        Log.i(TAG, "Shake detected: Activation triggered");
        // Log activation and then capture location
        logActivation("shake");
        captureLocation();
    }

    /**
     * Log activation event into SharedPreferences (JSON array) and broadcast
     * an activation intent so Flutter can display it in realtime.
     */
    private void logActivation(String type) {
        try {
            SharedPreferences prefs = getSharedPreferences("guessme_prefs", MODE_PRIVATE);
            String lastLat = prefs.getString("last_lat", null);
            String lastLon = prefs.getString("last_lon", null);
            long lastTime = prefs.getLong("last_time", 0);

            JSONObject obj = new JSONObject();
            obj.put("type", type);
            obj.put("time", System.currentTimeMillis());
            if (lastLat != null && lastLon != null) {
                obj.put("lat", lastLat);
                obj.put("lon", lastLon);
                obj.put("loc_time", lastTime);
            }

            String existing = prefs.getString("activation_log", null);
            JSONArray arr;
            if (existing != null) {
                try {
                    arr = new JSONArray(existing);
                } catch (JSONException e) {
                    arr = new JSONArray();
                }
            } else {
                arr = new JSONArray();
            }
            arr.put(obj);
            prefs.edit().putString("activation_log", arr.toString()).apply();

            // Broadcast activation event for UI
            Intent intent = new Intent("com.example.guess_me.ACTIVATION_EVENT");
            intent.putExtra("type", type);
            intent.putExtra("time", System.currentTimeMillis());
            if (lastLat != null && lastLon != null) {
                try {
                    intent.putExtra("lat", Double.parseDouble(lastLat));
                    intent.putExtra("lon", Double.parseDouble(lastLon));
                    intent.putExtra("loc_time", lastTime);
                } catch (NumberFormatException ignored) {}
            }
            sendBroadcast(intent);
            Log.d(TAG, "Activation logged: " + obj.toString());
        } catch (Exception e) {
            Log.w(TAG, "Failed to log activation", e);
        }
    }

    private void captureLocation() {
        boolean fineGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED;
        boolean coarseGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED;
        if (!(fineGranted || coarseGranted)) {
            Log.w(TAG, "Location permission not granted; cannot capture location.");
            return;
        }

        fusedLocationClient
            .getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, null)
            .addOnSuccessListener(location -> {
                if (location != null) {
                    sendLocationBroadcast(location);
                } else {
                    Log.w(TAG, "Current location is null; trying last known.");
                    fallbackLastLocation();
                }
            })
            .addOnFailureListener(e -> Log.e(TAG, "Failed to get location", e));
    }

    private void fallbackLastLocation() {
        fusedLocationClient
                .getLastLocation()
                .addOnSuccessListener(location -> {
                    if (location != null) {
                        sendLocationBroadcast(location);
                    } else {
                        Log.w(TAG, "Last location also null; not caching.");
                    }
                })
                .addOnFailureListener(e -> Log.e(TAG, "Failed to get last location", e));
    }

    private void sendLocationBroadcast(Location location) {
        Intent intent = new Intent("com.example.guess_me.LOCATION_UPDATE");
        intent.putExtra("lat", location.getLatitude());
        intent.putExtra("lon", location.getLongitude());
        intent.putExtra("time", location.getTime());
        sendBroadcast(intent);
        cacheLocation(location);
        Log.i(TAG, "Location broadcasted: lat=" + location.getLatitude() + " lon=" + location.getLongitude());
    }

    private void cacheLocation(Location location) {
        SharedPreferences prefs = getSharedPreferences("guessme_prefs", MODE_PRIVATE);
        prefs.edit()
                .putString("last_lat", String.valueOf(location.getLatitude()))
                .putString("last_lon", String.valueOf(location.getLongitude()))
                .putLong("last_time", location.getTime())
                .apply();
    }

    // ---- Heartbeat helpers ----

    private void startHeartbeat() {
        heartbeatHandler = new Handler(Looper.getMainLooper());
        heartbeatRunnable = new Runnable() {
            @Override
            public void run() {
                writeHeartbeat();
                captureLocationForHeartbeat();
                heartbeatHandler.postDelayed(this, HEARTBEAT_INTERVAL_MS);
            }
        };
        // Write an immediate heartbeat, then repeat.
        heartbeatHandler.post(heartbeatRunnable);
    }

    private void stopHeartbeat() {
        if (heartbeatHandler != null && heartbeatRunnable != null) {
            heartbeatHandler.removeCallbacks(heartbeatRunnable);
        }
    }

    /** Stamps the current time and the heartbeat interval so BootReceiver
     *  can compute whether the gap since the last ping is abnormally large. */
    private void writeHeartbeat() {
        SharedPreferences prefs = getSharedPreferences("guessme_prefs", MODE_PRIVATE);
        prefs.edit()
                .putLong("last_heartbeat_time", System.currentTimeMillis())
                .putLong("heartbeat_interval_ms", HEARTBEAT_INTERVAL_MS)
                // Clear any previous forced-shutdown flag while the service is alive.
                .putBoolean("forced_shutdown_suspected", false)
                .apply();
        Log.d(TAG, "Heartbeat written at " + System.currentTimeMillis());
    }

    /** Silently captures location for the heartbeat cache (no UI broadcast). */
    private void captureLocationForHeartbeat() {
        boolean fineGranted = ContextCompat.checkSelfPermission(this,
                Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED;
        boolean coarseGranted = ContextCompat.checkSelfPermission(this,
                Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED;
        if (!(fineGranted || coarseGranted)) return;

        fusedLocationClient
                .getCurrentLocation(Priority.PRIORITY_HIGH_ACCURACY, null)
                .addOnSuccessListener(location -> {
                    if (location != null) {
                        cacheLocation(location);
                        Log.d(TAG, "Heartbeat location cached: " + location.getLatitude()
                                + ", " + location.getLongitude());
                    } else {
                        // Fall back to last known
                        fusedLocationClient.getLastLocation()
                                .addOnSuccessListener(last -> {
                                    if (last != null) cacheLocation(last);
                                });
                    }
                })
                .addOnFailureListener(e -> Log.w(TAG, "Heartbeat location failed", e));
    }

    // ---- Speech recognition (hotword) ----

    private void startSpeechRecognitionIfPermitted() {
        boolean audioGranted = ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED;
        if (!audioGranted) {
            Log.i(TAG, "RECORD_AUDIO not granted; skipping speech recognition.");
            return;
        }
        // guard: avoid starting if already listening
        if (srListening) {
            Log.i(TAG, "SpeechRecognizer already listening - skip start");
            return;
        }
        startSpeechRecognition();
    }

    private void startSpeechRecognition() {
        try {
            if (!SpeechRecognizer.isRecognitionAvailable(this)) {
                Log.w(TAG, "Speech recognition not available on this device.");
                return;
            }
            if (speechRecognizer == null) {
                speechRecognizer = SpeechRecognizer.createSpeechRecognizer(this);
            }
            recognizerIntent = new Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH);
            recognizerIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM);
            recognizerIntent.putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true);
            recognizerIntent.putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3);
            recognizerIntent.putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true);
            recognizerIntent.putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, getPackageName());

            speechRecognizer.setRecognitionListener(new RecognitionListener() {
                    @Override public void onReadyForSpeech(Bundle params) { srListening = true; srStarting = false; srFailureCount = 0; }
                    @Override public void onBeginningOfSpeech() { }
                    @Override public void onRmsChanged(float rmsdB) { }
                    @Override public void onBufferReceived(byte[] buffer) { }
                    @Override public void onEndOfSpeech() {
                        srListening = false;
                        srStarting = false;
                        // immediate restart to keep continuous listening
                        try {
                            if (srRestartHandler == null) srRestartHandler = new Handler(Looper.getMainLooper());
                            srRestartHandler.postDelayed(() -> {
                                if (!srListening && !srStarting) startSpeechRecognition();
                            }, 200);
                        } catch (Exception ignored) {}
                    }
                    @Override public void onEvent(int eventType, Bundle params) { }

                @Override
                public void onError(int error) {
                    Log.w(TAG, "SpeechRecognizer error: " + error + " (srListening=" + srListening + ")");
                    srListening = false;
                    srStarting = false;
                    srFailureCount++;
                    // increase backoff on repeated errors
                    if (srBackoffMs < SR_BACKOFF_MAX_MS) srBackoffMs = Math.min(SR_BACKOFF_MAX_MS, srBackoffMs * 2);
                    scheduleSrRestartWithBackoff();
                }

                @Override
                public void onPartialResults(Bundle partialResults) {
                    handleResultsBundle(partialResults);
                }

                @Override
                public void onResults(Bundle results) {
                    handleResultsBundle(results);
                    // successful recognition - reset backoff and restart
                    srBackoffMs = SR_RESTART_DELAY_MS;
                    srFailureCount = 0;
                    srListening = false;
                    srStarting = false;
                    scheduleSrRestartWithBackoff();
                }
            });

            // Start listening
            // Guard: don't start if starting or already listening
            if (srStarting || srListening) {
                Log.i(TAG, "SpeechRecognizer already starting/listening - skip start");
                return;
            }
            srStarting = true;
            // Cancel any previous session and then start
            try { speechRecognizer.cancel(); } catch (Exception ignored) {}
            try {
                speechRecognizer.startListening(recognizerIntent);
                Log.i(TAG, "Speech recognition started.");
            } catch (Exception e) {
                srStarting = false;
                Log.e(TAG, "Failed to start speech recognition", e);
            }
        } catch (Exception e) {
            Log.e(TAG, "Failed to start speech recognition", e);
        }
    }

    private void handleResultsBundle(Bundle results) {
        if (results == null) return;
        ArrayList<String> matches = results.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION);
        if (matches == null) return;
        for (String s : matches) {
            if (s == null) continue;
            String lower = s.toLowerCase();
            if (lower.contains("help me") || lower.contains("helpme") || lower.contains("help")) {
                Log.i(TAG, "Hotword detected via speech: '" + s + "'");
                onHotwordDetected();
                break;
            }
        }
    }

    private void scheduleSrRestartWithBackoff() {
        if (srRestartHandler == null) srRestartHandler = new Handler(Looper.getMainLooper());
        long delay = srBackoffMs;
        srRestartHandler.postDelayed(() -> {
            try {
                if (speechRecognizer != null) {
                    try { speechRecognizer.cancel(); } catch (Exception ignored) {}
                    try { speechRecognizer.stopListening(); } catch (Exception ignored) {}
                }
            } catch (Exception ignored) {}
            // only start if not already listening
            if (!srListening) startSpeechRecognition();
        }, delay);
    }

    private void stopSpeechRecognition() {
        try {
            if (srRestartHandler != null) srRestartHandler.removeCallbacksAndMessages(null);
            if (speechRecognizer != null) {
                speechRecognizer.destroy();
                speechRecognizer = null;
            }
        } catch (Exception e) {
            Log.w(TAG, "Failed to stop speech recognition", e);
        }
    }

    private void onHotwordDetected() {
        // Activation triggered by voice; provide quick feedback and capture location.
        Vibrator vibrator = (Vibrator) getSystemService(VIBRATOR_SERVICE);
        if (vibrator != null) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(VibrationEffect.createOneShot(250, VibrationEffect.DEFAULT_AMPLITUDE));
            } else {
                vibrator.vibrate(250);
            }
        }
        android.os.Handler handler = new android.os.Handler(getMainLooper());
        handler.post(() -> android.widget.Toast.makeText(this, "Activation word detected!", android.widget.Toast.LENGTH_SHORT).show());
        Log.i(TAG, "Voice activation triggered");
        // Use same handler as shake: capture location and send broadcast
        captureLocation();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel channel = new NotificationChannel(
                    CHANNEL_ID,
                    "GuessMe Foreground Service",
                    NotificationManager.IMPORTANCE_LOW
            );
            channel.setDescription("Persistent notification for GuessMe foreground service");
            NotificationManager manager = getSystemService(NotificationManager.class);
            if (manager != null) {
                manager.createNotificationChannel(channel);
            }
        }
    }

    private void acquireWakeLock() {
        PowerManager pm = (PowerManager) getSystemService(POWER_SERVICE);
        if (pm != null) {
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, TAG + ":WakeLock");
            wakeLock.setReferenceCounted(false);
            wakeLock.acquire();
        }
    }

    private void releaseWakeLock() {
        if (wakeLock != null && wakeLock.isHeld()) {
            wakeLock.release();
        }
    }
}
