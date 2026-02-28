

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

class EmergencyButtons extends StatelessWidget {
  const EmergencyButtons({super.key});

 Future<void> _makeCall(String number) async {
  try {
    bool? res = await FlutterPhoneDirectCaller.callNumber(number);

    if (res == false) {
      debugPrint("Call failed or permission denied");
    }
  } catch (e) {
    debugPrint("Direct call error: $e");
  }
}
  Widget _buildButton({
    required IconData icon,
    required Color color,
    required String label,
    required String number,
  }) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => _makeCall(number),
          child: CircleAvatar(
            radius: 28,
            backgroundColor: color,
            child: Icon(icon, color: Colors.white, size: 26),
          ),
        ),
        const SizedBox(height: 6),
        Text(label),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildButton(
          icon: Icons.local_police,
          color: Colors.blue,
          label: "Police",
          number: "100",
        ),
        _buildButton(
          icon: Icons.local_hospital,
          color: Colors.red,
          label: "Ambulance",
          number: "102",
        ),
        _buildButton(
          icon: Icons.local_fire_department,
          color: Colors.orange,
          label: "Fire",
          number: "101",
        ),
      ],
    );
  }
}