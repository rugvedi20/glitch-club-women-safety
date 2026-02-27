package com.example.guess_me;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

public class BootReceiver extends BroadcastReceiver {
    private static final String TAG = "BootReceiver";
    // Multiplier: if the gap since the last heartbeat is more than this many
    // intervals, we treat it as a forced / unexpected shutdown.
    private static final float FORCED_SHUTDOWN_GAP_MULTIPLIER = 2.0f;

    @Override
    public void onReceive(Context context, Intent intent) {
        if (!Intent.ACTION_BOOT_COMPLETED.equals(intent.getAction())) return;

        Log.i(TAG, "Boot completed, starting ForegroundService");
        Intent serviceIntent = new Intent(context, ForegroundService.class);
        context.startForegroundService(serviceIntent);

        android.content.SharedPreferences prefs =
                context.getSharedPreferences("guessme_prefs", Context.MODE_PRIVATE);

        String lat  = prefs.getString("last_lat", null);
        String lon  = prefs.getString("last_lon", null);
        long   time = prefs.getLong("last_time", 0);

        boolean orderly = prefs.getBoolean("orderly_shutdown", false);

        // ---- 1. Retry unsent orderly-shutdown email ----
        boolean sent = prefs.getBoolean("shutdown_email_sent", true);
        if (!sent && lat != null && lon != null && time != 0) {
            String subject = "Device shutdown location (delayed)";
            String body = "Device was previously shut down orderly.\n"
                    + "Last cached location:\n"
                    + "Lat: " + lat + "\nLon: " + lon + "\n"
                    + "Time: " + new java.util.Date(time);
            EmailSender.sendAsync(subject, body);
            prefs.edit().putBoolean("shutdown_email_sent", true).apply();
            Log.i(TAG, "Sent delayed orderly-shutdown email after boot.");
        }

        // ---- 2. Detect FORCED shutdown via heartbeat gap ----
        // Skip if there was an orderly shutdown (ShutdownReceiver already handled it).
        if (!orderly) {
            long lastHeartbeat  = prefs.getLong("last_heartbeat_time", 0);
            long intervalMs     = prefs.getLong("heartbeat_interval_ms", 30 * 60 * 1000L);
            long now            = System.currentTimeMillis();
            long gap            = now - lastHeartbeat;

            if (lastHeartbeat > 0 && gap > (long)(FORCED_SHUTDOWN_GAP_MULTIPLIER * intervalMs)) {
                Log.w(TAG, "Forced shutdown suspected. Gap since last heartbeat: "
                        + (gap / 60_000) + " min (threshold: "
                        + (long)(FORCED_SHUTDOWN_GAP_MULTIPLIER * intervalMs / 60_000) + " min)");

                String lastSeen = (lastHeartbeat > 0)
                        ? new java.util.Date(lastHeartbeat).toString()
                        : "unknown";
                String locInfo  = (lat != null && lon != null)
                        ? "Lat: " + lat + "\nLon: " + lon + "\nCaptured: " + new java.util.Date(time)
                        : "Location not available.";

                String subject = "\u26A0 ALERT: Phone was forcefully switched off";
                String body =
                        "The phone appears to have been FORCEFULLY switched off (not an orderly shutdown).\n\n"
                        + "Last seen alive: " + lastSeen + "\n"
                        + "Time since last ping: " + (gap / 60_000) + " minutes\n\n"
                        + "Last known location:\n" + locInfo;

                EmailSender.sendAsync(subject, body);
                // Persist forced-shutdown indicator and message for app UI.
                try {
                    prefs.edit()
                        .putBoolean("forced_shutdown_detected", true)
                        .putString("forced_shutdown_message", body)
                        .apply();
                } catch (Exception e) {
                    Log.w(TAG, "Failed to persist forced-shutdown flag", e);
                }
                Log.i(TAG, "Forced-shutdown alert queued and persisted.");
            } else if (lastHeartbeat > 0) {
                Log.d(TAG, "Heartbeat gap normal (" + (gap / 60_000) + " min). No forced shutdown.");
            }
        } else {
            Log.i(TAG, "Orderly shutdown flag set — skipping forced-shutdown detection.");
        }

        // Clear the orderly-shutdown flag now that boot is complete.
        prefs.edit().putBoolean("orderly_shutdown", false).apply();
    }
}
