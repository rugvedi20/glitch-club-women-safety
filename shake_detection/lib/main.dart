import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shake Detection',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const ShakeDetectionApp(),
    );
  }
}

class ShakeDetectionApp extends StatefulWidget {
  const ShakeDetectionApp({Key? key}) : super(key: key);

  @override
  State<ShakeDetectionApp> createState() => _ShakeDetectionAppState();
}

class _ShakeDetectionAppState extends State<ShakeDetectionApp> {
  late StreamSubscription<AccelerometerEvent> _streamSubscription;
  double _xAccel = 0;
  double _yAccel = 0;
  double _zAccel = 0;
  bool _isShaking = false;
  DateTime _lastShakeTime = DateTime.now();
  static const double _shakeThreshold = 25.0;
  static const Duration _shakeDuration = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _startListeningToAccelerometer();
  }

  void _startListeningToAccelerometer() {
    _streamSubscription =
        accelerometerEvents.listen((AccelerometerEvent event) {
      setState(() {
        _xAccel = event.x;
        _yAccel = event.y;
        _zAccel = event.z;
      });

      // Detect shake based on acceleration magnitude
      double acceleration = _calculateAcceleration(event.x, event.y, event.z);

      if (acceleration > _shakeThreshold) {
        DateTime now = DateTime.now();
        if (now.difference(_lastShakeTime) > _shakeDuration) {
          _lastShakeTime = now;
          _showShakeDetectedPopup();
        }
      }
    });
  }

  double _calculateAcceleration(double x, double y, double z) {
    return (x * x + y * y + z * z).toDouble().sqrt();
  }

  void _showShakeDetectedPopup() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('🔴 Shake Detected!'),
          content: const Text('Device shake has been detected.'),
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

  @override
  void dispose() {
    _streamSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shake Detection'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.vibration,
              size: 80,
              color: Colors.deepPurple,
            ),
            const SizedBox(height: 24),
            const Text(
              'Shake Detection Active',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 32),
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Acceleration Values',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _accelRow('X', _xAccel),
                    _accelRow('Y', _yAccel),
                    _accelRow('Z', _zAccel),
                    const SizedBox(height: 16),
                    Text(
                      'Total: ${_calculateAcceleration(_xAccel, _yAccel, _zAccel).toStringAsFixed(2)} m/s²',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _accelRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$label:',
            style: const TextStyle(fontSize: 14),
          ),
          Text(
            '${value.toStringAsFixed(2)} m/s²',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
