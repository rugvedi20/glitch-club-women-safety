package com.example.safety_pal;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Build;
import android.util.Log;

public class BootReceiver extends BroadcastReceiver {
    
    private static final String LOG_TAG = "BootReceiver";
    
    @Override
    public void onReceive(Context context, Intent intent) {
        if (Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) {
            Log.i(LOG_TAG, "═══════════════════════════════════════════════════════════════");
            Log.i(LOG_TAG, "📱 BOOT_COMPLETED received");
            Log.i(LOG_TAG, "═══════════════════════════════════════════════════════════════");
            
            try {
                Intent serviceIntent = new Intent(context, ShakeDetectionService.class);
                
                // Start foreground service on Android 8.0+
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(serviceIntent);
                    Log.i(LOG_TAG, "✓ Shake detection started via startForegroundService");
                } else {
                    context.startService(serviceIntent);
                    Log.i(LOG_TAG, "✓ Shake detection started via startService");
                }
            } catch (Exception e) {
                Log.e(LOG_TAG, "✗ Failed to start ShakeDetectionService: " + e.getMessage(), e);
            }
        }
    }
}
