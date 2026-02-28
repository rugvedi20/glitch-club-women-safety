package com.example.safety_pal;

import android.hardware.Sensor;
import android.hardware.SensorEvent;
import android.hardware.SensorEventListener;
import android.hardware.SensorManager;
import android.util.Log;

public class ShakeSensorListener implements SensorEventListener {
    private static final String TAG = "ShakeSensorListener";
    
    private static final float SHAKE_THRESHOLD = 12f; // Lowered for easier testing
    private static final int SHAKE_WINDOW_TIME_MS = 2000; // 2 second window to count shakes
    private static final int MIN_SHAKE_COUNT = 2; // Need 2 shakes in the window
    private static final long ACTIVATION_COOLDOWN_MS = 3000; // Prevent rapid re-triggers
    
    private long lastShakeTime = 0;
    private int shakeCount = 0;
    private long lastActivationTime = 0;
    private OnShakeListener shakeListener;
    
    public interface OnShakeListener {
        void onShake();
    }
    
    public ShakeSensorListener(OnShakeListener listener) {
        this.shakeListener = listener;
    }
    
    @Override
    public void onSensorChanged(SensorEvent event) {
        if (event.sensor.getType() == Sensor.TYPE_ACCELEROMETER) {
            // Get acceleration values
            float x = event.values[0];
            float y = event.values[1];
            float z = event.values[2];
            
            // Normalize by gravity to get G-Force
            float gX = x / SensorManager.GRAVITY_EARTH;
            float gY = y / SensorManager.GRAVITY_EARTH;
            float gZ = z / SensorManager.GRAVITY_EARTH;
            
            // Calculate magnitude of acceleration
            float gForce = (float) Math.sqrt(gX * gX + gY * gY + gZ * gZ);
            
            long currentTime = System.currentTimeMillis();
            boolean isShaking = gForce > SHAKE_THRESHOLD;
            
            // Log sensor readings periodically for debugging
            if (currentTime % 100 < 50) {
                Log.v(TAG, String.format(
                    "[SENSOR_DATA] X=%.2f, Y=%.2f, Z=%.2f | GForce=%.2f | IsShaking=%b | Threshold=%.2f",
                    x, y, z, gForce, isShaking, SHAKE_THRESHOLD
                ));
            }
            
            if (isShaking) {
                // Reset counter if outside the detection window
                if (currentTime - lastShakeTime > SHAKE_WINDOW_TIME_MS) {
                    Log.i(TAG, "[SHAKE_RESET] Time window exceeded (" + (currentTime - lastShakeTime) + "ms). Resetting counter.");
                    shakeCount = 0;
                }
                
                shakeCount += 1;
                lastShakeTime = currentTime;
                
                Log.w(TAG, String.format(
                    "[SHAKE_DETECTED] Count: %d/%d | GForce: %.2f | Threshold: %.2f | TimeWindow: %dms",
                    shakeCount, MIN_SHAKE_COUNT, gForce, SHAKE_THRESHOLD, SHAKE_WINDOW_TIME_MS
                ));
                
                // Check if cooldown has elapsed
                boolean cooldownElapsed = (currentTime - lastActivationTime) > ACTIVATION_COOLDOWN_MS;
                
                // Trigger on shake if we've detected enough consecutive shakes and cooldown has passed
                if (shakeCount >= MIN_SHAKE_COUNT && shakeListener != null && cooldownElapsed) {
                    Log.e(TAG, "\n╔════════════════════════════════════════╗\n" +
                        "║     🚨 SHAKE THRESHOLD REACHED! 🚨     ║\n" +
                        "║  Triggering SOS SOS SOS SOS SOS SOS  ║\n" +
                        "╚════════════════════════════════════════╝");
                    
                    lastActivationTime = currentTime;
                    shakeCount = 0;
                    shakeListener.onShake();
                } else if (shakeCount < MIN_SHAKE_COUNT) {
                    Log.d(TAG, "[SHAKE_PENDING] Need " + (MIN_SHAKE_COUNT - shakeCount) + " more shake(s)");
                } else if (!cooldownElapsed) {
                    long cooldownRemaining = ACTIVATION_COOLDOWN_MS - (currentTime - lastActivationTime);
                    Log.d(TAG, "[SHAKE_COOLDOWN] Waiting " + cooldownRemaining + "ms before next trigger");
                }
            }
        }
    }
    
    @Override
    public void onAccuracyChanged(Sensor sensor, int accuracy) {
        // Not needed for this implementation
    }
    
    public void setOnShakeListener(OnShakeListener listener) {
        this.shakeListener = listener;
    }
}
