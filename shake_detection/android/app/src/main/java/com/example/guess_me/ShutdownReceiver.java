package com.example.guess_me;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.util.Log;

public class ShutdownReceiver extends BroadcastReceiver {
    private static final String TAG = "ShutdownReceiver";

    @Override
    public void onReceive(Context context, Intent intent) {
        if (intent == null) return;
        if (!Intent.ACTION_SHUTDOWN.equals(intent.getAction())) return;

        final PendingResult pendingResult = goAsync();
        SharedPreferences prefs = context.getSharedPreferences("guessme_prefs", Context.MODE_PRIVATE);
        String lat = prefs.getString("last_lat", null);
        String lon = prefs.getString("last_lon", null);
        long time = prefs.getLong("last_time", 0);

        if (lat == null || lon == null || time == 0) {
            Log.w(TAG, "No cached location to send on shutdown.");
            return;
        }

        String subject = "Device shutdown location";
        String body = "Device is shutting down. Last cached location:\n" +
                "Lat: " + lat + "\n" +
                "Lon: " + lon + "\n" +
                "Time(ms since epoch): " + time;

        // Mark as not sent (BootReceiver will retry if needed)
        SharedPreferences.Editor edit = prefs.edit();
        edit.putBoolean("shutdown_email_sent", false)
            // Flag that this was an ORDERLY shutdown so BootReceiver does not
            // also raise a forced-shutdown alert for the same event.
            .putBoolean("orderly_shutdown", true)
            .apply();

        // Fire-and-forget email; best-effort within shutdown window.
        EmailSender.sendAsync(subject, body);
        Log.i(TAG, "Shutdown detected, email queued.");
        new android.os.Handler().postDelayed(() -> {
            edit.putBoolean("shutdown_email_sent", true).apply();
            pendingResult.finish();
        }, 500);
    }
}
