package com.example.safety_pal

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.speech.tts.TextToSpeech
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.*

class MainActivity: FlutterActivity() {
    private val SHAKE_CHANNEL = "com.example.safety_pal/shake"
    private val TTS_CHANNEL = "com.example.safety_pal/tts"
    private lateinit var methodChannel: MethodChannel
    private lateinit var ttsChannel: MethodChannel
    private var sosReceiver: BroadcastReceiver? = null
    private var textToSpeech: TextToSpeech? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        Log.d("MainActivity", "═══════════════════════════════════════════");
        Log.d("MainActivity", "[FLUTTER_ENGINE] Configuring Flutter Engine")
        Log.d("MainActivity", "═══════════════════════════════════════════");
        
        // Setup method channel for shake detection
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHAKE_CHANNEL)
        Log.i("MainActivity", "[METHOD_CHANNEL] Created: $SHAKE_CHANNEL")
        
        methodChannel.setMethodCallHandler { call, result ->
            Log.d("MainActivity", "═══════════════════════════════════════════");
            Log.i("MainActivity", "[METHOD_CALL] Received: ${call.method}")
            Log.d("MainActivity", "  → Arguments: ${call.arguments}")
            
            when (call.method) {
                "startShakeDetection" -> {
                    Log.w("MainActivity", "✓ [START_SHAKE_DETECTION] Method called")
                    startShakeDetection()
                    result.success("Shake detection started")
                    Log.i("MainActivity", "✓ [START_SHAKE_DETECTION] Service started successfully")
                }
                "stopShakeDetection" -> {
                    Log.w("MainActivity", "✓ [STOP_SHAKE_DETECTION] Method called")
                    stopShakeDetection()
                    result.success("Shake detection stopped")
                    Log.i("MainActivity", "✓ [STOP_SHAKE_DETECTION] Service stopped successfully")
                }
                "isShakeDetectionActive" -> {
                    val isActive = isServiceRunning()
                    Log.i("MainActivity", "[CHECK_STATUS] Service running: $isActive")
                    result.success(isActive)
                }
                else -> {
                    Log.e("MainActivity", "✗ [UNKNOWN_METHOD] Method not implemented: ${call.method}")
                    result.notImplemented()
                }
            }
            Log.d("MainActivity", "═══════════════════════════════════════════");
        }
        
        // Setup TTS method channel
        setupTTSChannel(flutterEngine)
        
        // Register broadcast receiver for SOS events
        registerSOSReceiver()
        
        Log.d("MainActivity", "═══════════════════════════════════════════");
        Log.i("MainActivity", "[SETUP_COMPLETE] Method channels configured successfully")
        Log.d("MainActivity", "═══════════════════════════════════════════");
    }
    
    /**
     * Setup Text-to-Speech method channel
     */
    private fun setupTTSChannel(flutterEngine: FlutterEngine) {
        Log.d("MainActivity", "[TTS_SETUP] Initializing Text-to-Speech channel");
        
        ttsChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TTS_CHANNEL)
        Log.i("MainActivity", "[TTS_CHANNEL] Created: $TTS_CHANNEL")
        
        ttsChannel.setMethodCallHandler { call, result ->
            Log.d("MainActivity", "═══════════════════════════════════════════");
            Log.i("MainActivity", "[TTS_METHOD_CALL] Received: ${call.method}")
            
            when (call.method) {
                "speak" -> {
                    val text = call.argument<String>("text") ?: ""
                    Log.i("MainActivity", "[TTS_SPEAK] Speaking: \"$text\"")
                    speakText(text)
                    result.success("Speaking")
                }
                "stop" -> {
                    Log.i("MainActivity", "[TTS_STOP] Stopping TTS")
                    stopSpeaking()
                    result.success("Stopped")
                }
                "isAvailable" -> {
                    val available = textToSpeech != null
                    Log.i("MainActivity", "[TTS_CHECK] Available: $available")
                    result.success(available)
                }
                else -> {
                    Log.e("MainActivity", "✗ [TTS_UNKNOWN] Unknown method: ${call.method}")
                    result.notImplemented()
                }
            }
            Log.d("MainActivity", "═══════════════════════════════════════════");
        }
        
        // Initialize TextToSpeech
        initializeTextToSpeech()
        Log.i("MainActivity", "✓ [TTS_SETUP] Text-to-Speech setup completed")
    }
    
    /**
     * Initialize TextToSpeech engine
     */
    private fun initializeTextToSpeech() {
        Log.d("MainActivity", "[TTS_INIT] Initializing TextToSpeech engine");
        
        textToSpeech = TextToSpeech(this) { status ->
            if (status == TextToSpeech.SUCCESS) {
                textToSpeech?.language = Locale.US
                textToSpeech?.setSpeechRate(0.8f)
                Log.i("MainActivity", "✓ [TTS_INIT] TextToSpeech initialized successfully")
            } else {
                Log.e("MainActivity", "✗ [TTS_INIT] TextToSpeech initialization failed: $status")
            }
        }
    }
    
    /**
     * Speak text using TextToSpeech
     */
    private fun speakText(text: String) {
        try {
            if (textToSpeech != null && !text.isEmpty()) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    textToSpeech?.speak(text, TextToSpeech.QUEUE_FLUSH, null)
                } else {
                    @Suppress("DEPRECATION")
                    textToSpeech?.speak(text, TextToSpeech.QUEUE_FLUSH, null)
                }
                Log.i("MainActivity", "✓ [TTS_SPEAK] Text queued for speaking")
            } else {
                Log.w("MainActivity", "⚠️ [TTS_SPEAK] TextToSpeech not initialized or empty text")
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "✗ [TTS_SPEAK] Error speaking text: ${e.message}", e)
        }
    }
    
    /**
     * Stop current speech
     */
    private fun stopSpeaking() {
        try {
            if (textToSpeech != null) {
                textToSpeech?.stop()
                Log.i("MainActivity", "✓ [TTS_STOP] Speech stopped")
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "✗ [TTS_STOP] Error stopping speech: ${e.message}", e)
        }
    }
    
    /**
     * Start shake detection service
     */
    private fun startShakeDetection() {
        Log.d("MainActivity", "═══════════════════════════════════════════");
        Log.w("MainActivity", "[START_SERVICE] Starting ShakeDetectionService");
        Log.d("MainActivity", "  → Android Version: ${Build.VERSION.SDK_INT}")
        
        val serviceIntent = Intent(this, ShakeDetectionService::class.java)
        
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Log.d("MainActivity", "[START_SERVICE] Using startForegroundService (Android 8.0+)")
                startForegroundService(serviceIntent)
            } else {
                Log.d("MainActivity", "[START_SERVICE] Using startService (Android <8.0)")
                startService(serviceIntent)
            }
            Log.i("MainActivity", "✓ [SERVICE_STARTED] ShakeDetectionService started successfully")
        } catch (e: Exception) {
            Log.e("MainActivity", "✗ [SERVICE_ERROR] Failed to start service: ${e.message}", e)
        }
        Log.d("MainActivity", "═══════════════════════════════════════════");
    }
    
    /**
     * Stop shake detection service
     */
    private fun stopShakeDetection() {
        Log.d("MainActivity", "═══════════════════════════════════════════");
        Log.w("MainActivity", "[STOP_SERVICE] Stopping ShakeDetectionService");
        
        try {
            val serviceIntent = Intent(this, ShakeDetectionService::class.java)
            val result = stopService(serviceIntent)
            
            if (result) {
                Log.i("MainActivity", "✓ [SERVICE_STOPPED] ShakeDetectionService stopped successfully")
            } else {
                Log.w("MainActivity", "✗ [STOP_WARNING] Service was not running")
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "✗ [SERVICE_ERROR] Failed to stop service: ${e.message}", e)
        }
        Log.d("MainActivity", "═══════════════════════════════════════════");
    }
    
    /**
     * Check if the service is running
     */
    private fun isServiceRunning(): Boolean {
        Log.d("MainActivity", "[CHECK_SERVICE_STATUS] Checking if ShakeDetectionService is running...")
        
        try {
            val manager = getSystemService(ACTIVITY_SERVICE) as android.app.ActivityManager
            val runningServices = manager.getRunningServices(Integer.MAX_VALUE)
            
            Log.d("MainActivity", "  → Total running services: ${runningServices.size}")
            
            for (service in runningServices) {
                if (ShakeDetectionService::class.java.name == service.service.className) {
                    Log.i("MainActivity", "✓ [SERVICE_RUNNING] ShakeDetectionService is ACTIVE")
                    Log.d("MainActivity", "  → Process ID: ${service.pid}")
                    Log.d("MainActivity", "  → Foreground: ${service.foreground}")
                    return true
                }
            }
            
            Log.i("MainActivity", "✗ [SERVICE_NOT_RUNNING] ShakeDetectionService is INACTIVE")
            return false
        } catch (e: Exception) {
            Log.e("MainActivity", "✗ [ERROR] Failed to check service status: ${e.message}", e)
            return false
        }
    }
    
    /**
     * Register broadcast receiver for SOS events
     */
    private fun registerSOSReceiver() {
        Log.d("MainActivity", "═══════════════════════════════════════════");
        Log.d("MainActivity", "[BROADCAST_RECEIVER] Registering SOS receiver");
        
        sosReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                Log.d("MainActivity", "═══════════════════════════════════════════");
                Log.w("MainActivity", "[BROADCAST_RECEIVED] BroadcastReceiver.onReceive() called")
                Log.d("MainActivity", "  → Action: ${intent?.action}")
                Log.d("MainActivity", "  → Time: ${System.currentTimeMillis()}")
                
                if (intent?.action == "com.example.safety_pal.SOS_TRIGGERED") {
                    Log.e("MainActivity", "\n╔════════════════════════════════════════╗\n" +
                        "║  [CRITICAL] SOS EVENT RECEIVED!       ║\n" +
                        "║         Invoking Flutter Method        ║\n" +
                        "║            onShakeDetected()           ║\n" +
                        "╚════════════════════════════════════════╝")
                    
                    try {
                        methodChannel.invokeMethod("onShakeDetected", null)
                        Log.i("MainActivity", "✓ [FLUTTER_METHOD_INVOKED] Successfully called onShakeDetected()")
                    } catch (e: Exception) {
                        Log.e("MainActivity", "✗ [FLUTTER_ERROR] Failed to invoke method: ${e.message}", e)
                    }
                } else {
                    Log.w("MainActivity", "✗ [UNEXPECTED_BROADCAST] Received unexpected broadcast action")
                }
                Log.d("MainActivity", "═══════════════════════════════════════════");
            }
        }
        
        val intentFilter = IntentFilter("com.example.safety_pal.SOS_TRIGGERED")
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                registerReceiver(sosReceiver, intentFilter, Context.RECEIVER_EXPORTED)
                Log.i("MainActivity", "✓ [RECEIVER_REGISTERED] SOS receiver registered (Android 8.0+)")
            } else {
                registerReceiver(sosReceiver, intentFilter)
                Log.i("MainActivity", "✓ [RECEIVER_REGISTERED] SOS receiver registered (Android <8.0)")
            }
            Log.d("MainActivity", "  → Action: com.example.safety_pal.SOS_TRIGGERED")
        } catch (e: Exception) {
            Log.e("MainActivity", "✗ [RECEIVER_ERROR] Failed to register receiver: ${e.message}", e)
        }
        Log.d("MainActivity", "═══════════════════════════════════════════");
    }
    
    /**
     * Unregister broadcast receiver when activity is destroyed
     */
    override fun onDestroy() {
        super.onDestroy()
        Log.d("MainActivity", "═══════════════════════════════════════════");
        Log.w("MainActivity", "[ACTIVITY_LIFECYCLE] onDestroy() called")
        
        // Cleanup TextToSpeech
        try {
            textToSpeech?.let {
                it.stop()
                it.shutdown()
                Log.i("MainActivity", "✓ [TTS_CLEANUP] TextToSpeech shut down")
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "✗ [TTS_CLEANUP_ERROR] Failed to cleanup TTS: ${e.message}", e)
        }
        
        try {
            sosReceiver?.let { 
                unregisterReceiver(it)
                Log.i("MainActivity", "✓ [RECEIVER_UNREGISTERED] SOS receiver unregistered")
            }
        } catch (e: Exception) {
            Log.e("MainActivity", "✗ [CLEANUP_ERROR] Failed to unregister receiver: ${e.message}", e)
        }
        Log.d("MainActivity", "═══════════════════════════════════════════");
    }
}
