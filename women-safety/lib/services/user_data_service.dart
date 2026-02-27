import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Reads and writes the three JSON blobs that make up the user's profile.
class UserDataService {
  static Future<File> _localFile(String filename) async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$filename');
  }

  static Future<Map<String, dynamic>> readAll() async {
    final Map<String, dynamic> data = {};
    final files = [
      'register_data.json',
      'about_user_data.json',
      'guardians_data.json',
    ];

    for (final name in files) {
      final f = await _localFile(name);
      if (await f.exists()) {
        try {
          final contents = await f.readAsString();
          data.addAll(json.decode(contents) as Map<String, dynamic>);
        } catch (_) {}
      }
    }
    return data;
  }

  static Future<void> writeRegister(Map<String, dynamic> user) async {
    final f = await _localFile('register_data.json');
    await f.writeAsString(json.encode(user));
  }

  static Future<void> writeAbout(Map<String, dynamic> details) async {
    final f = await _localFile('about_user_data.json');
    await f.writeAsString(json.encode(details));
  }

  static Future<void> writeGuardians(List<Map<String, dynamic>> guardians) async {
    final f = await _localFile('guardians_data.json');
    await f.writeAsString(json.encode({'trustedGuardians': guardians}));
  }
}
