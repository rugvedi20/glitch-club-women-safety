import 'package:flutter/material.dart';

/// A large circular SOS button that handles long‑press recording state.
class SosButton extends StatelessWidget {
  final bool isRecording;
  final bool enabled;
  final VoidCallback? onLongPressStart;
  final VoidCallback? onLongPressEnd;

  const SosButton({
    required this.isRecording,
    required this.enabled,
    this.onLongPressStart,
    this.onLongPressEnd,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onLongPressStart: (_) => onLongPressStart?.call(),
        onLongPressEnd: (_) => onLongPressEnd?.call(),
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: enabled ? Colors.red : Colors.grey,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (enabled ? Colors.red : Colors.grey).withOpacity(0.3),
                spreadRadius: 5,
                blurRadius: 10,
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'SOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (isRecording)
                  const Text(
                    'Recording...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
