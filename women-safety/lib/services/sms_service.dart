
import 'package:geolocator/geolocator.dart';
import 'package:telephony/telephony.dart';


/// Helper that sends emergency SMS messages to a list of guardians.
class SmsService {
  static final Telephony _telephony = Telephony.instance;

  /// Sends an alert SMS to every guardian in [guardianList].
  ///
  /// [guardianList] should be a list of maps that contain a `phone` key.
  /// Returns `true` if at least one message was queued.
 static Future<bool> sendEmergencySms(
  List<Map<String, dynamic>> guardianList, {
  String? userName,
}) async {
  print("========== SMS DEBUG START ==========");

  try {
    print("Step 1: Requesting SMS permission...");
    final bool? permissionsGranted =
        await _telephony.requestSmsPermissions;

    print("Permission result: $permissionsGranted");

    if (permissionsGranted != true) {
      print("❌ SMS Permission not granted");
      return false;
    }

    print("Step 2: Extracting phone numbers...");
    final phones = guardianList
        .map((g) {
          print("Guardian raw data: $g");
          return g['phone'] as String?;
        })
        .where((p) => p != null && p.isNotEmpty)
        .cast<String>()
        .toList();

    print("Extracted phone numbers: $phones");

    if (phones.isEmpty) {
      print("❌ No valid phone numbers found");
      return false;
    }

    print("Step 3: Fetching current location...");
    final Position pos =
        await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high);

    print("Location fetched: ${pos.latitude}, ${pos.longitude}");

    final link =
        'https://maps.google.com/?q=${pos.latitude},${pos.longitude}';

    final now = DateTime.now();
    final currentTime =
        '${now.hour}:${now.minute}:${now.second}';

    final message = '''
Emergency Alert:

Name: ${userName ?? 'Unknown'}
Location: $link
Time: $currentTime

Please check immediately.
''';

    print("Step 4: SMS Message Constructed:");
    print(message);

    print("Step 5: Sending SMS to each number...");

    for (final number in phones) {
      try {
        String formattedNumber =
            number.startsWith('+') ? number : '+91$number';

        print("Sending to: $formattedNumber");

        await _telephony.sendSms(
          to: formattedNumber,
          message: message,
          statusListener: (SendStatus status) {
            print(
                "📨 Status for $formattedNumber: $status");
          },
        );

        print("SMS send request triggered for $formattedNumber");
      } catch (e) {
        print("❌ Failed sending to $number");
        print("Error: $e");
      }
    }

    print("========== SMS DEBUG END ==========");
    return true;
  } catch (e, stack) {
    print("❌ CRITICAL ERROR in SMS Service");
    print("Error: $e");
    print("Stacktrace: $stack");
    print("========== SMS DEBUG END ==========");
    return false;
  }
}}
