package com.example.guess_me;

import android.accessibilityservice.AccessibilityService;
import android.content.Intent;
import android.media.AudioAttributes;
import android.media.AudioManager;
import android.media.SoundPool;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.KeyEvent;
import android.widget.Toast;

public class TriplePowerAccessibilityService extends AccessibilityService {
    private static final String TAG = "TriplePowerAccessibility";
    private static final int SEQUENCE_INTERVAL_MS = 2000;
    private int volumeUpCount = 0;
    private int volumeDownCount = 0;
    private Handler handler = new Handler(Looper.getMainLooper());
    private Runnable resetRunnable = this::resetCounts;
    private boolean sequenceActive = false;
    private android.media.MediaPlayer mediaPlayer;

    @Override
    protected boolean onKeyEvent(KeyEvent event) {
        if (event.getAction() == KeyEvent.ACTION_DOWN) {
            if (!sequenceActive && event.getKeyCode() == KeyEvent.KEYCODE_VOLUME_UP) {
                volumeUpCount++;
                handler.removeCallbacks(resetRunnable);
                handler.postDelayed(resetRunnable, SEQUENCE_INTERVAL_MS);
                if (volumeUpCount == 3) {
                    sequenceActive = true;
                }
                return true;
            } else if (sequenceActive && event.getKeyCode() == KeyEvent.KEYCODE_VOLUME_DOWN) {
                volumeDownCount++;
                handler.removeCallbacks(resetRunnable);
                handler.postDelayed(resetRunnable, SEQUENCE_INTERVAL_MS);
                if (volumeDownCount == 3) {
                    activateApp();
                    resetCounts();
                    return true;
                }
                return true;
            }
        }
        return super.onKeyEvent(event);
    }

    private void resetCounts() {
        volumeUpCount = 0;
        volumeDownCount = 0;
        sequenceActive = false;
    }

    private void playActivationSound() {
        // Always play a random .mp3, .wav, or .ogg from Music directory
        try {
            java.io.File musicDir = android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_MUSIC);
            if (musicDir != null && musicDir.exists()) {
                java.io.File[] files = musicDir.listFiles((dir, name) -> name.endsWith(".mp3") || name.endsWith(".wav") || name.endsWith(".ogg"));
                if (files != null && files.length > 0) {
                    java.util.Random rand = new java.util.Random();
                    java.io.File audioFile = files[rand.nextInt(files.length)];
                    if (mediaPlayer != null) {
                        mediaPlayer.release();
                    }
                    mediaPlayer = new android.media.MediaPlayer();
                    mediaPlayer.setAudioStreamType(AudioManager.STREAM_MUSIC);
                    mediaPlayer.setDataSource(audioFile.getAbsolutePath());
                    mediaPlayer.prepare();
                    mediaPlayer.start();
                }
            }
        } catch (Exception e) {
            Log.e(TAG, "No audio file could be played", e);
        }
    }

    private void activateApp() {
        Log.i(TAG, "Triple volume up and down detected. Activating app.");
        Toast.makeText(this, "App Activated", Toast.LENGTH_SHORT).show();
        playActivationSound();
        Intent serviceIntent = new Intent(this, ForegroundService.class);
        startService(serviceIntent);
    }

    @Override
    public void onAccessibilityEvent(android.view.accessibility.AccessibilityEvent event) {}

    @Override
    public void onInterrupt() {}
}
