import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safety_pal/providers/shake_sos_provider.dart';
import 'package:safety_pal/providers/auth_provider.dart';
import 'package:safety_pal/services/sos_service.dart';

/// Widget to show SOS status and control shake detection
class ShakeSOSWidget extends StatelessWidget {
  final VoidCallback? onSOSTriggered;
  
  const ShakeSOSWidget({
    Key? key,
    this.onSOSTriggered,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ShakeSOSProvider>(
      builder: (context, shakeSOSProvider, child) {
        return Card(
          margin: const EdgeInsets.all(16),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: shakeSOSProvider.isShakeDetectionActive
                    ? [Colors.red.shade100, Colors.pink.shade100]
                    : [Colors.grey.shade100, Colors.grey.shade200],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status Indicator
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: shakeSOSProvider.isShakeDetectionActive
                            ? Colors.red
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        shakeSOSProvider.isShakeDetectionActive
                            ? 'SOS Shake Detection Active'
                            : 'SOS Shake Detection Inactive',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: shakeSOSProvider.isShakeDetectionActive
                              ? Colors.red
                              : Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Status Message
                if (shakeSOSProvider.statusMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      shakeSOSProvider.statusMessage!,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                
                // Toggle Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (shakeSOSProvider.isShakeDetectionActive) {
                        await shakeSOSProvider.disableShakeDetection();
                      } else {
                        // Set the callback for when shake is detected
                        await shakeSOSProvider.enableShakeDetection(
                          () async {
                            // ════════════════════════════════════════════════════════════
                        // SHAKE DETECTED: Trigger Extended SOS Flow
                        // ════════════════════════════════════════════════════════════
                        await _handleShakeDetectedSOS(context);
                      },
                    );
                  }
                },
                    icon: Icon(
                      shakeSOSProvider.isShakeDetectionActive
                          ? Icons.stop_circle
                          : Icons.play_circle,
                    ),
                    label: Text(
                      shakeSOSProvider.isShakeDetectionActive
                          ? 'Stop Detection'
                          : 'Start Detection',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: shakeSOSProvider.isShakeDetectionActive
                          ? Colors.red
                          : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // SHAKE DETECTED HANDLER: Extended SOS Flow
  // ════════════════════════════════════════════════════════════════════════════
  Future<void> _handleShakeDetectedSOS(BuildContext context) async {
    print('[ShakeSOSWidget] 🚨 SHAKE DETECTED - Initiating extended SOS');

    try {
      // Get user data from AuthProvider
      final authProvider = context.read<AuthProvider>();
      final userData = authProvider.userData;

      if (userData == null) {
        print('[ShakeSOSWidget] ⚠️ User data not loaded');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User profile not loaded. SOS cannot be sent.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Extract guardians list
      final List<Map<String, dynamic>> guardians = [];
      if (userData['guardians'] is List) {
        guardians.addAll(
            List<Map<String, dynamic>>.from(userData['guardians']));
      } else if (userData['trustedGuardians'] is List) {
        guardians.addAll(
            List<Map<String, dynamic>>.from(userData['trustedGuardians']));
      }

      if (guardians.isEmpty) {
        print('[ShakeSOSWidget] ⚠️ No guardians configured');
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('No Trusted Contacts'),
                content: const Text(
                  'You have not added any trusted contacts. Please configure them first.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
        }
        return;
      }

      // ════════════════════════════════════════════════════════════════════════
      // TRIGGER EXTENDED SOS SERVICE
      // Handles: Guardian alerts, Admin flag check, TTS announcement,
      // DB record creation, and AI model API call
      // ════════════════════════════════════════════════════════════════════════
      if (context.mounted) {
        await SOSService.triggerExtendedSOS(
          context: context,
          userData: userData,
          guardians: guardians,
          audioPath: '',
          triggerType: 'shake_detected',
        );
      }

      // Execute custom callback if provided
      if (onSOSTriggered != null) {
        onSOSTriggered!();
      }

      print('[ShakeSOSWidget] ✓ Shake SOS flow completed');
    } catch (e) {
      print('[ShakeSOSWidget] ❌ Error in shake SOS: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
