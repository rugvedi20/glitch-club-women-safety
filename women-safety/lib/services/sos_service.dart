import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:safety_pal/models/sos_record.dart';
import 'package:safety_pal/services/email_service.dart';
import 'package:safety_pal/services/native_tts_service.dart';
import 'package:safety_pal/services/sms_service.dart';

/// SOS Service — handles the entire extended SOS flow
class SOSService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // STEP 1 – Send Guardian Alerts (SMS & Email)
  // STEP 2 – Check Admin Alert Flag
  // STEP 3 – TTS Announcement with Cancel Slider
  // STEP 4 – Call Retell AI Phone Call API
  // STEP 5 – Create SOS Record in Firestore

  /// Entry point: triggers the full SOS flow
  static Future<void> triggerExtendedSOS({
    required BuildContext context,
    required Map<String, dynamic> userData,
    required List<Map<String, dynamic>> guardians,
    String audioPath = '',
    String triggerType = 'manual_button',
  }) async {
    print('[SOS_FLOW] 🚨 EXTENDED SOS FLOW INITIATED | Trigger: $triggerType');

    try {
      // STEP 1: Send alerts to guardians
      await _step1SendGuardianAlerts(guardians, userData);

      // STEP 2: Check if alertAdmin flag is enabled
      final shouldAlertAdmin = await _step2CheckAdminAlertFlag(userData);
      if (!shouldAlertAdmin) {
        print('[SOS_FLOW] ℹ️ Admin alert disabled — flow stopped.');
        return;
      }

      // STEP 3: TTS announcement with cancel slider
      final isCancelled = await _step3ShowTTSWithCancelSlider(context);
      if (isCancelled) {
        print('[SOS_FLOW] ⏹️ SOS cancelled by user via slider');
        _showCancelledDialog(context);
        return;
      }

      // STEP 4: Call Retell AI Phone Call API
      await _step4CallRetellAI(
        userData: userData,
        guardians: guardians,
      );

      // STEP 5: Create SOS record in Firestore
      await _step5CreateSOSRecord(
        userData: userData,
        audioPath: audioPath,
        triggerType: triggerType,
        guardiansNotified:
            guardians.map((g) => g['phone']?.toString() ?? '').toList(),
      );

      print('[SOS_FLOW] ✅ EXTENDED SOS FLOW COMPLETED SUCCESSFULLY');
    } catch (e) {
      print('[SOS_FLOW] ❌ ERROR: $e');
      _showErrorDialog(context, 'Error in SOS flow: $e');
    }
  }

  // ── STEP 1: Send Guardian Alerts ──────────────────────────────────────────

  static Future<void> _step1SendGuardianAlerts(
    List<Map<String, dynamic>> guardians,
    Map<String, dynamic> userData,
  ) async {
    print('[STEP_1] 📱 Sending Alerts to Guardians');

    try {
      if (guardians.isEmpty) {
        print('[STEP_1] ⚠️ No guardians configured — skipping.');
        return;
      }

      final smsSent = await SmsService.sendEmergencySms(
        guardians,
        userName: userData['name'] as String?,
      );
      print('[STEP_1] SMS: ${smsSent ? '✓ sent' : '⚠️ failed'}');

      final emailSent = await EmailService.sendEmergencyEmail(
        guardians,
        userName: userData['name'] as String?,
        userEmail: userData['email'] as String?,
        audioPath: '',
      );
      print('[STEP_1] Email: ${emailSent ? '✓ sent' : '⚠️ failed'}');
    } catch (e) {
      print('[STEP_1] ❌ Error: $e');
      rethrow;
    }
  }

  // ── STEP 2: Check Admin Alert Flag ────────────────────────────────────────

  static Future<bool> _step2CheckAdminAlertFlag(
    Map<String, dynamic> userData,
  ) async {
    print('[STEP_2] 🔍 Checking Admin Alert Flag');

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        print('[STEP_2] ❌ User not authenticated');
        return false;
      }

      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('[STEP_2] ⚠️ User document not found');
        return false;
      }

      final alertAdmin = userDoc.get('alertAdmin') as bool? ?? false;
      print('[STEP_2] alertAdmin = $alertAdmin');
      return alertAdmin;
    } catch (e) {
      print('[STEP_2] ❌ Error: $e');
      return false;
    }
  }

  // ── STEP 3: TTS Announcement with Cancel Slider ──────────────────────────

  static Future<bool> _step3ShowTTSWithCancelSlider(
      BuildContext context) async {
    print('[STEP_3] 🔊 TTS Announcement with Cancel Slider');

    try {
      const message =
          'Sending Alerts to Safety Pal Team as well. Cancel within 5 seconds to avoid.';
      await NativeTTSService.speak(message);

      return await _showCancelSliderDialog(context);
    } catch (e) {
      print('[STEP_3] ❌ Error: $e');
      return false;
    }
  }

  static Future<bool> _showCancelSliderDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const _CancelSliderDialog(),
        ) ??
        false;
  }

  // ── STEP 5: Create SOS Record in Firestore ───────────────────────────────

  static Future<String> _step5CreateSOSRecord({
    required Map<String, dynamic> userData,
    required String audioPath,
    required String triggerType,
    required List<String> guardiansNotified,
  }) async {
    print('[STEP_5] 💾 Creating SOS Record in Firestore');

    try {
      final userId = _auth.currentUser?.uid ?? 'unknown';

      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        );
        print('[STEP_5] 📍 Location: ${position.latitude}, ${position.longitude}');
      } catch (e) {
        print('[STEP_5] ⚠️ Could not get location: $e');
      }

      final sosRecord = SOSRecord(
        userId: userId,
        userName: userData['name'] as String? ?? 'Unknown',
        userEmail: userData['email'] as String? ?? '',
        userPhone: userData['phone'] as String? ?? '',
        latitude: position?.latitude,
        longitude: position?.longitude,
        triggerType: triggerType,
        status: 'active',
        createdAt: DateTime.now(),
        audioPath: audioPath.isNotEmpty ? audioPath : null,
        guardiansNotified: guardiansNotified,
        adminAlertsent: true,
      );

      final docRef =
          await _firestore.collection('sos').add(sosRecord.toFirestore());
      print('[STEP_5] ✓ SOS record created: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('[STEP_5] ❌ Error: $e');
      rethrow;
    }
  }

  // ── STEP 4: Call Retell AI Phone Call API ─────────────────────────────────

  static Future<void> _step4CallRetellAI({
    required Map<String, dynamic> userData,
    required List<Map<String, dynamic>> guardians,
  }) async {
    print('[STEP_4] 🤖 Calling Retell AI Phone Call API for ${guardians.length} guardian(s)');

    try {
      final retellApiKey = dotenv.env['RETELL_API_KEY'] ?? '';
      final fromNumber = dotenv.env['RETELL_FROM_NUMBER'] ?? '';
      final agentId = dotenv.env['RETELL_AGENT_ID'] ?? '';

      if (retellApiKey.isEmpty || fromNumber.isEmpty || agentId.isEmpty) {
        print('[STEP_4] ❌ Missing Retell env vars — skipping API call.');
        return;
      }

      if (guardians.isEmpty) {
        print('[STEP_4] ⚠️ No guardians to call — skipping.');
        return;
      }

      final victimName = userData['name'] as String? ?? 'Unknown';

      // Build victim_location from latest position (reverse-geocoded)
      String victimLocation = 'Unknown location';
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        );
        try {
          final placemarks = await placemarkFromCoordinates(
            position.latitude,
            position.longitude,
          );
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final parts = [
              p.name,
              p.subLocality,
              p.locality,
              p.administrativeArea,
              p.postalCode,
            ].where((s) => s != null && s.isNotEmpty).toList();
            victimLocation = parts.join(', ');
          }
        } catch (_) {
          victimLocation =
              'Lat: ${position.latitude}, Lng: ${position.longitude}';
        }
      } catch (_) {}

      // Fire calls to ALL guardians in parallel
      final callFutures = guardians.map((guardian) {
        final guardianName = guardian['name'] as String? ?? 'Guardian';
        final rawPhone = guardian['phone'] as String? ?? '';
        final toNumber = rawPhone.startsWith('+91') ? rawPhone : '+91$rawPhone';

        final payload = {
          'from_number': fromNumber,
          'to_number': toNumber,
          'override_agent_id': agentId,
          'retell_llm_dynamic_variables': {
            'victim_name': victimName,
            'victim_location': victimLocation,
            'victim_situation': 'Emergency SOS triggered',
            'guardian_name': guardianName,
            'additional_instructions': '',
          },
        };

        print('[STEP_4] 📤 Calling guardian "$guardianName" at $toNumber');

        return http.post(
          Uri.parse('https://api.retellai.com/v2/create-phone-call'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $retellApiKey',
          },
          body: jsonEncode(payload),
        ).then((response) {
          if (response.statusCode == 200 || response.statusCode == 201) {
            print('[STEP_4] ✓ Call to "$guardianName" initiated');
          } else {
            print('[STEP_4] ⚠️ Call to "$guardianName" failed: ${response.statusCode}');
            print('[STEP_4] Response: ${response.body}');
          }
        }).catchError((e) {
          print('[STEP_4] ❌ Error calling "$guardianName": $e');
        });
      }).toList();

      await Future.wait(callFutures);

      print('[STEP_4] ✓ All ${guardians.length} guardian call(s) processed');
    } catch (e) {
      print('[STEP_4] ❌ Error: $e');
    }
  }

  // ── Helper: Error Dialog ──────────────────────────────────────────────────

  static void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Helper: Cancelled Confirmation Dialog ─────────────────────────────────

  static void _showCancelledDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('SOS Update'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Alerts sent to your guardians.'),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.cancel, color: Colors.red, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Safety Pal team alert cancelled.'),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

// ── Cancel Slider Dialog Widget ─────────────────────────────────────────────

class _CancelSliderDialog extends StatefulWidget {
  const _CancelSliderDialog();

  @override
  State<_CancelSliderDialog> createState() => _CancelSliderDialogState();
}

class _CancelSliderDialogState extends State<_CancelSliderDialog> {
  late int secondsRemaining;
  bool isCancelled = false;

  @override
  void initState() {
    super.initState();
    secondsRemaining = 5;
    _startCountdown();
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => secondsRemaining--);
        if (secondsRemaining == 0) {
          if (mounted) Navigator.of(context).pop(false);
        } else {
          _startCountdown();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.deepOrange[50],
      title: const Text(
        '⚠️ ADMIN ALERT',
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.deepOrange,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          const Text(
            'Sending emergency alerts to Safety Pal Team...',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.2),
              border: Border.all(color: Colors.red, width: 2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  'Cancelling in',
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                Text(
                  '$secondsRemaining seconds',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(30),
            ),
            child: SliderTheme(
              data: const SliderThemeData(
                trackHeight: 50,
                thumbShape: RoundSliderThumbShape(
                  elevation: 4.0,
                  enabledThumbRadius: 28.0,
                ),
              ),
              child: Slider(
                value: isCancelled ? 1.0 : 0.0,
                onChanged: (value) {
                  if (value > 0.7) {
                    setState(() => isCancelled = true);
                    print('[SOS_SLIDER] 🛑 User cancelled SOS');
                    Navigator.of(context).pop(true);
                  }
                },
                min: 0.0,
                max: 1.0,
                activeColor: Colors.green,
                inactiveColor: Colors.grey[400],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Slide right to cancel →',
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
