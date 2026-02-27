import 'package:permission_handler/permission_handler.dart';
import 'package:telephony/telephony.dart';
import 'package:geolocator/geolocator.dart';

/// Encapsulates the various runtime permissions the app requires.
class PermissionService {
  static Future<bool> requestAllPermissions() async {
    final Map<Permission, String> permissions = {
      Permission.microphone:
          'Microphone access for emergency audio recording',
      Permission.location: 'Location access for emergency alerts',
      Permission.locationWhenInUse: 'Location access when app is in use',
      Permission.sms: 'SMS access to send emergency messages',
      Permission.phone: 'Phone access for emergency calls',
    };

    final denied = <Permission>[];

    for (var p in permissions.keys) {
      if (!await p.isGranted) denied.add(p);
    }

    if (denied.isNotEmpty) {
      final statuses = await denied.request();
      if (statuses.values.any((s) => !s.isGranted)) {
        return false;
      }
    }

    // telephony plugin requires its own call
    final Telephony telephony = Telephony.instance;
    final bool? telPermissions = await telephony.requestPhoneAndSmsPermissions;
    if (telPermissions == null || !telPermissions) return false;

    return true;
  }

  static Future<bool> checkLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }
}
