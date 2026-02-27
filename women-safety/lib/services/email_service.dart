import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  static const String _senderEmail = 'darshangentyal02@gmail.com';
  static const String _senderPassword = 'gglv egcq njgt tuga';

  static Future<bool> sendEmergencyEmail(
    List<Map<String, dynamic>> guardians, {
    String? userName,
    String? userEmail,
    String? audioPath,
  }) async {
    try {
      final recipients = guardians
          .map((g) => g['email'] as String?)
          .where((e) => e != null && _isValidEmail(e))
          .cast<String>()
          .toList();

      if (recipients.isEmpty) return false;

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final link =
          'https://maps.google.com/?q=${pos.latitude},${pos.longitude}';

      final now = DateTime.now();
      final time = DateFormat('HH:mm:ss').format(now);

      final message = Message()
        ..from = Address(_senderEmail, 'Emergency Alert')
        ..recipients.addAll(recipients)
        ..subject = 'Emergency Alert - Immediate Attention Needed!'
        ..text = '''
Hello,

An emergency alert has been triggered.

User Details:
Name: ${userName ?? 'Unknown'}
Email: ${userEmail ?? 'Not provided'}
Location: $link
Time: $time

Please check on them immediately.
''';

      if (audioPath != null && audioPath.isNotEmpty) {
        message.attachments.add(
          FileAttachment(File(audioPath))
            ..location = Location.attachment,
        );
      }

      final smtpServer = gmail(_senderEmail, _senderPassword);

      await send(message, smtpServer);

      print("Email sent successfully");
      return true;
    } catch (e) {
      print("Email sending failed: $e");
      return false;
    }
  }

  static bool _isValidEmail(String email) {
    final regex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return regex.hasMatch(email);
  }
}