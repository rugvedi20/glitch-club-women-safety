package com.example.safety_pal;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

public class ShutdownReceiver extends BroadcastReceiver {
    
    private static final String LOG_TAG = "ShutdownReceiver";
    
    @Override
    public void onReceive(Context context, Intent intent) {
        if (Intent.ACTION_SHUTDOWN.equals(intent.getAction())) {
            Log.i(LOG_TAG, "═══════════════════════════════════════════════════════════════");
            Log.i(LOG_TAG, "📱 SHUTDOWN received");
            Log.i(LOG_TAG, "═══════════════════════════════════════════════════════════════");
            
            try {
                Intent serviceIntent = new Intent(context, ShakeDetectionService.class);
                context.stopService(serviceIntent);
                Log.i(LOG_TAG, "✓ Shake detection service stopped for shutdown");
            } catch (Exception e) {
                Log.e(LOG_TAG, "✗ Failed to stop ShakeDetectionService: " + e.getMessage(), e);
            }
        }
    }
}
