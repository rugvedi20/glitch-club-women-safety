import 'package:flutter/services.dart';

/// Text-to-Speech service using native Android TextToSpeech
/// No external dependencies - uses Android native API directly
class NativeTTSService {
  static const platform = MethodChannel('com.example.safety_pal/tts');

  /// Speak text using native Android TTS
  static Future<void> speak(String text) async {
    try {
      print('[NativeTTS] 🔊 Speaking: "$text"');
      await platform.invokeMethod('speak', {'text': text});
      print('[NativeTTS] ✓ TTS completed');
    } catch (e) {
      print('[NativeTTS] ⚠️ TTS error: $e');
      // Don't rethrow - TTS failure shouldn't block SOS flow
    }
  }

  /// Stop current speech
  static Future<void> stop() async {
    try {
      await platform.invokeMethod('stop');
      print('[NativeTTS] ✓ TTS stopped');
    } catch (e) {
      print('[NativeTTS] ⚠️ Error stopping TTS: $e');
    }
  }

  /// Check if TTS is available
  static Future<bool> isAvailable() async {
    try {
      final result = await platform.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } catch (e) {
      print('[NativeTTS] ⚠️ Error checking TTS availability: $e');
      return false;
    }
  }
}
