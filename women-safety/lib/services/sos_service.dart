import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:safety_pal/models/sos_record.dart';
import 'package:safety_pal/services/email_service.dart';
import 'package:safety_pal/services/native_tts_service.dart';
import 'package:safety_pal/services/sms_service.dart';
import 'package:safety_pal/theme/app_theme.dart';

/// Callback type for reporting SOS progress.
/// [step] is one of: 'sms', 'email', 'admin_check', 'calling', 'team_cancelled', 'record_created'
/// [success] indicates whether the step completed successfully.
typedef SOSProgressCallback = void Function(String step, bool success);

/// SOS Service — handles the entire extended SOS flow
class SOSService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // STEP 1a – Send SMS to Guardians
  // STEP 1b – Send Email to Guardians
  // STEP 2  – Check Admin Alert Flag
  // STEP 3  – Premium Countdown for Safety Pal Team Alert
  // STEP 4  – Call Retell AI Phone Call API
  // STEP 5  – Create SOS Record in Firestore

  /// Entry point: triggers the full SOS flow.
  /// Pass [cancelToken] to allow external cancellation at any point.
  static Future<void> triggerExtendedSOS({
    required BuildContext context,
    required Map<String, dynamic> userData,
    required List<Map<String, dynamic>> guardians,
    String audioPath = '',
    String triggerType = 'manual_button',
    SOSProgressCallback? onProgress,
    ValueNotifier<bool>? cancelToken,
  }) async {
    print('[SOS_FLOW] 🚨 EXTENDED SOS FLOW INITIATED | Trigger: $triggerType');

    bool isCancelled() => cancelToken?.value == true;

    try {
      // STEP 1a: Send SMS to guardians
      if (isCancelled()) return;
      final smsSent = await _step1aSendSMS(guardians, userData);
      if (isCancelled()) return;
      onProgress?.call('sms', smsSent);

      // STEP 1b: Send Email to guardians
      if (isCancelled()) return;
      final emailSent = await _step1bSendEmail(guardians, userData, audioPath);
      if (isCancelled()) return;
      onProgress?.call('email', emailSent);

      // STEP 2: Check if alertAdmin flag is enabled
      if (isCancelled()) return;
      final shouldAlertAdmin = await _step2CheckAdminAlertFlag(userData);
      onProgress?.call('admin_check', shouldAlertAdmin);
      if (!shouldAlertAdmin) {
        print('[SOS_FLOW] ℹ️ Admin alert disabled — flow complete.');
        return;
      }

      // STEP 3: Premium countdown for Safety Pal team alert
      if (isCancelled()) return;
      final teamAlertCancelled =
          await _step3ShowTeamAlertCountdown(context, cancelToken);
      if (teamAlertCancelled || isCancelled()) {
        print('[SOS_FLOW] ⏹️ Safety Pal team alert cancelled by user');
        onProgress?.call('team_cancelled', true);
        return;
      }

      // STEP 4: Call Retell AI Phone Call API
      if (isCancelled()) return;
      await _step4CallRetellAI(
        userData: userData,
        guardians: guardians,
      );
      if (isCancelled()) return;
      onProgress?.call('calling', true);

      // STEP 5: Create SOS record in Firestore
      if (isCancelled()) return;
      await _step5CreateSOSRecord(
        userData: userData,
        audioPath: audioPath,
        triggerType: triggerType,
        guardiansNotified:
            guardians.map((g) => g['phone']?.toString() ?? '').toList(),
      );
      onProgress?.call('record_created', true);

      print('[SOS_FLOW] ✅ EXTENDED SOS FLOW COMPLETED SUCCESSFULLY');
    } catch (e) {
      print('[SOS_FLOW] ❌ ERROR: $e');
      if (!isCancelled()) {
        _showErrorDialog(context, 'Error in SOS flow: $e');
      }
    }
  }

  // ── STEP 1a: Send SMS to Guardians ────────────────────────────────────────

  static Future<bool> _step1aSendSMS(
    List<Map<String, dynamic>> guardians,
    Map<String, dynamic> userData,
  ) async {
    print('[STEP_1a] 📱 Sending SMS to Guardians');

    try {
      if (guardians.isEmpty) {
        print('[STEP_1a] ⚠️ No guardians configured — skipping.');
        return false;
      }

      final smsSent = await SmsService.sendEmergencySms(
        guardians,
        userName: userData['name'] as String?,
      );
      print('[STEP_1a] SMS: ${smsSent ? '✓ sent' : '⚠️ failed'}');
      return smsSent;
    } catch (e) {
      print('[STEP_1a] ❌ Error: $e');
      return false;
    }
  }

  // ── STEP 1b: Send Email to Guardians ──────────────────────────────────────

  static Future<bool> _step1bSendEmail(
    List<Map<String, dynamic>> guardians,
    Map<String, dynamic> userData,
    String audioPath,
  ) async {
    print('[STEP_1b] 📧 Sending Email to Guardians');

    try {
      if (guardians.isEmpty) {
        print('[STEP_1b] ⚠️ No guardians configured — skipping.');
        return false;
      }

      final emailSent = await EmailService.sendEmergencyEmail(
        guardians,
        userName: userData['name'] as String?,
        userEmail: userData['email'] as String?,
        audioPath: audioPath,
      );
      print('[STEP_1b] Email: ${emailSent ? '✓ sent' : '⚠️ failed'}');
      return emailSent;
    } catch (e) {
      print('[STEP_1b] ❌ Error: $e');
      return false;
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

  // ── STEP 3: Safety Pal Team Alert Countdown ──────────────────────────────

  static Future<bool> _step3ShowTeamAlertCountdown(
      BuildContext context, ValueNotifier<bool>? cancelToken) async {
    print('[STEP_3] 🔊 Safety Pal Team Alert Countdown');

    try {
      const message =
          'Sending alerts to Safety Pal Team. Cancel within 10 seconds to stop.';
      await NativeTTSService.speak(message);
    } catch (e) {
      print('[STEP_3] ⚠️ TTS error: $e');
    }

    if (cancelToken?.value == true) return true;

    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black54,
          builder: (_) =>
              _SafetyPalCountdownDialog(cancelToken: cancelToken),
        ) ??
        false;
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

  // ── STEP 5: Create SOS Record in Firestore ───────────────────────────────

  static Future<String> _step5CreateSOSRecord({
    required Map<String, dynamic> userData,
    required String audioPath,
    required String triggerType,
    required List<String> guardiansNotified,
  }) async {
    print('[STEP_5] 💾 Creating SOS Record in Firestore');

    try {
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

      final sosData = {
        'userName': userData['name'] as String? ?? 'Unknown',
        'email': userData['email'] as String? ?? '',
        'phone': userData['phone'] as String? ?? '',
        'latitude': position?.latitude,
        'longitude': position?.longitude,
        'createdAt': FieldValue.serverTimestamp(),
        'guardiansNotified': guardiansNotified,
      };

      final docRef =
          await _firestore.collection('sos').add(sosData);
      print('[STEP_5] ✓ SOS record created: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('[STEP_5] ❌ Error: $e');
      rethrow;
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

}

// ── Safety Pal Team Alert Countdown Dialog ──────────────────────────────────

class _SafetyPalCountdownDialog extends StatefulWidget {
  final ValueNotifier<bool>? cancelToken;
  const _SafetyPalCountdownDialog({this.cancelToken});

  @override
  State<_SafetyPalCountdownDialog> createState() =>
      _SafetyPalCountdownDialogState();
}

class _SafetyPalCountdownDialogState
    extends State<_SafetyPalCountdownDialog> {
  int _countdown = 10;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Listen to external cancellation (e.g. Cancel Request button)
    widget.cancelToken?.addListener(_onCancelTokenChanged);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 1) {
        timer.cancel();
        if (mounted) Navigator.of(context).pop(false); // Not cancelled → proceed
      } else {
        if (mounted) setState(() => _countdown--);
      }
    });
  }

  void _onCancelTokenChanged() {
    if (widget.cancelToken?.value == true && mounted) {
      _timer?.cancel();
      Navigator.of(context).pop(true); // Cancelled externally
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.cancelToken?.removeListener(_onCancelTokenChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          boxShadow: AppTheme.elevatedShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Shield icon
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.dangerLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.shield_rounded,
                color: AppTheme.primaryRed,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Alerting Safety Pal Team',
              style: AppTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Team will be notified in',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.textTertiary,
              ),
            ),
            const SizedBox(height: 24),
            // Countdown circle
            SizedBox(
              width: 90,
              height: 90,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: CircularProgressIndicator(
                      value: _countdown / 10,
                      strokeWidth: 5,
                      backgroundColor: AppTheme.divider,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryRed),
                    ),
                  ),
                  Text(
                    '$_countdown',
                    style: AppTheme.displayMedium.copyWith(
                      color: AppTheme.primaryRed,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            // Cancel button
            GestureDetector(
              onTap: () {
                _timer?.cancel();
                Navigator.of(context).pop(true); // Cancelled by user
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.divider),
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Center(
                  child: Text(
                    'CANCEL TEAM ALERT',
                    style: AppTheme.labelLarge.copyWith(
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
