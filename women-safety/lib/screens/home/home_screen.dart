import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:telephony/telephony.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

// services
import 'package:safety_pal/services/permission_service.dart';
import 'package:safety_pal/services/sms_service.dart';
import 'package:safety_pal/services/email_service.dart';
import 'package:safety_pal/providers/auth_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  final Telephony telephony = Telephony.instance;

  bool _isRecording = false;
  String? _audioFilePath;
  bool _isEmailSending = false;
  bool _permissionsGranted = false;
  bool _isLoadingPermissions = true;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Request all permissions first
    await _requestAllPermissions();

    // Then initialize audio components
    await _initializeRecorder();
    await _initializePlayer();

    _animationController.forward();
  }

  Future<void> _requestAllPermissions() async {
    try {
      setState(() {
        _isLoadingPermissions = true;
      });

      // Check location services
      bool locationServiceEnabled =
          await PermissionService.checkLocationServiceEnabled();

      if (!locationServiceEnabled) {
        await _showLocationServiceDialog();
      }

      // Request all permissions
      bool allPermissionsGranted =
          await PermissionService.requestAllPermissions();

      setState(() {
        _permissionsGranted = allPermissionsGranted;
        _isLoadingPermissions = false;
      });

      if (!allPermissionsGranted) {
        await _showPermissionDialog();
      }
    } catch (e) {
      print("Error during permission initialization: $e");
      setState(() {
        _permissionsGranted = false;
        _isLoadingPermissions = false;
      });
    }
  }

  Future<void> _showLocationServiceDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Location Services Required'),
          content: const Text(
            'This app requires location services to send emergency alerts with your location. Please enable location services in your device settings.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openLocationSettings();
              },
            ),
            TextButton(
              child: const Text('Continue Anyway'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showPermissionDialog() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permissions Required'),
          content: const Text(
            'This app requires several permissions to function properly:\n\n'
            '• Microphone: For emergency audio recording\n'
            '• Location: To send your location in emergency alerts\n'
            '• SMS & Phone: To send emergency messages\n\n'
            'Some features may not work without these permissions.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () async {
                Navigator.of(context).pop();
                // await openAppSettings();
              },
            ),
            TextButton(
              child: const Text('Retry'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _requestAllPermissions();
              },
            ),
            TextButton(
              child: const Text('Continue Anyway'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _initializeRecorder() async {
    try {
      await _recorder.openRecorder();
      await _recorder
          .setSubscriptionDuration(const Duration(milliseconds: 500));
    } catch (e) {
      print("Error initializing recorder: $e");
    }
  }

  Future<void> _initializePlayer() async {
    try {
      await _player.openPlayer();
    } catch (e) {
      print("Error initializing player: $e");
    }
  }

  Future<void> _startRecording() async {
    // Permission should already be granted, but double-check
    if (_permissionsGranted) {
      try {
        final directory = await getApplicationDocumentsDirectory();
        _audioFilePath = '${directory.path}/recorded_audio.aac';
        await _recorder.startRecorder(toFile: _audioFilePath);
        setState(() {
          _isRecording = true;
        });
      } catch (e) {
        print('Error starting recording: $e');
      }
    } else {
      print('Microphone permission not granted');
      _showPermissionSnackBar(
          'Microphone permission is required for emergency recording');
    }
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder.stopRecorder();
      setState(() {
        _isRecording = false;
      });
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  void _showPermissionSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: () => (),
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _getUserData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final registerFilePath = '${directory.path}/register_data.json';
      final aboutUserFilePath = '${directory.path}/about_user_data.json';
      final guardiansFilePath = '${directory.path}/guardians_data.json';

      final registerFile = File(registerFilePath);
      final aboutUserFile = File(aboutUserFilePath);
      final guardiansFile = File(guardiansFilePath);

      Map<String, dynamic> userData = {};

      if (await registerFile.exists()) {
        final registerContents = await registerFile.readAsString();
        userData.addAll(json.decode(registerContents));
      }

      if (await aboutUserFile.exists()) {
        final aboutUserContents = await aboutUserFile.readAsString();
        userData.addAll(json.decode(aboutUserContents));
      }

      if (await guardiansFile.exists()) {
        final guardiansContents = await guardiansFile.readAsString();
        userData.addAll(json.decode(guardiansContents));
      }

      return userData;
    } catch (e) {
      print('Error reading user data: $e');
      return {};
    }
  }

  void _showUserDataPopup(BuildContext context) async {
    if (!_permissionsGranted) {
      _showPermissionSnackBar(
          'Permissions are required to send emergency alerts');
      return;
    }

    setState(() {
      _isEmailSending = true;
    });

    try {
      final userData = await _getUserData();

      // extract guardian list from saved data
      final List<Map<String, dynamic>> guardians = [];
      if (userData['trustedGuardians'] is List) {
        guardians.addAll(
            List<Map<String, dynamic>>.from(userData['trustedGuardians']));
      }

      // Send SMS first
      final smsSent = await SmsService.sendEmergencySms(
        guardians,
        userName: userData['name'] as String?,
      );

      // Then send Email
      final emailSent = await EmailService.sendEmergencyEmail(
        guardians,
        userName: userData['name'] as String?,
        userEmail: userData['email'] as String?,
        audioPath: _audioFilePath,
      );

      setState(() {
        _isEmailSending = false;
      });

      // Show Result Dialog
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text((smsSent && emailSent)
                ? 'Emergency Alerts Sent'
                : 'Some Alerts Failed'),
            content: Text(
              (smsSent && emailSent)
                  ? 'Both SMS and Email have been sent to your trusted contacts.'
                  : (!smsSent && !emailSent)
                      ? 'Failed to send both SMS and Email. Please check your permissions and network connection.'
                      : smsSent
                          ? 'SMS sent, but email failed.'
                          : 'Email sent, but SMS failed.',
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
    } catch (e) {
      setState(() {
        _isEmailSending = false;
      });
      print("Error in emergency alert: $e");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending emergency alert: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Safety Pal',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
            actions: [
              PopupMenuButton(
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem(
                    child: const Row(
                      children: [
                        Icon(Icons.person, size: 20),
                        SizedBox(width: 8),
                        Text('Profile'),
                      ],
                    ),
                    onTap: () {
                      // TODO: Navigate to profile page
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile coming soon!')),
                      );
                    },
                  ),
                  PopupMenuItem(
                    child: const Row(
                      children: [
                        Icon(Icons.logout, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Logout', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                    onTap: () {
                      _showLogoutConfirmation(context, authProvider);
                    },
                  ),
                ],
                icon: const Icon(Icons.menu, color: Colors.black),
              ),
            ],
          ),
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color.fromARGB(181, 255, 255, 255),
                  const Color.fromARGB(255, 254, 255, 246),
                  Colors.purple[100]!
                ],
              ),
            ),
            child: SafeArea(
              child: Stack(
                children: [
                  if (_isLoadingPermissions)
                    const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Setting up permissions...',
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  else
                    FutureBuilder<Map<String, dynamic>>(
                      future: _getUserData(),
                      builder: (context, snapshot) {
                        String userName = 'User';
                        if (snapshot.connectionState == ConnectionState.done) {
                          userName = snapshot.data?['name'] ?? 'User';
                        }
                        return Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildHeader(userName),
                                const SizedBox(height: 16),
                                _buildPermissionStatus(),
                                const SizedBox(height: 16),
                                _buildSafetyTip(),
                                const SizedBox(height: 32),
                                _buildSOSButton(context),
                                const SizedBox(height: 32),
                                _buildActionButtons(context),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  if (_isEmailSending)
                    Container(
                      color: Colors.black54,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text(
                              'Sending emergency alerts...',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showLogoutConfirmation(
      BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await authProvider.logout();
                if (mounted) {
                  Navigator.of(context).pushReplacementNamed('/');
                }
              },
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPermissionStatus() {
    if (_permissionsGranted) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[700], size: 20),
            const SizedBox(width: 8),
            const Text(
              'All permissions granted - Ready for emergencies',
              style: TextStyle(color: Colors.black87, fontSize: 12),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange[700], size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Some permissions missing - Tap to grant permissions',
                style: TextStyle(color: Colors.black87, fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: _requestAllPermissions,
              child: const Text('Grant', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildHeader(String userName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hi $userName,',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const Text(
          'Stay Safe!',
          style: TextStyle(
            fontSize: 18,
            color: Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyTip() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.yellow[100],
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.yellow.withOpacity(0.3),
            spreadRadius: 5,
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: Colors.orange[700]),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Share your location with trusted contacts when traveling alone.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSOSButton(BuildContext context) {
    return Center(
      child: GestureDetector(
        onLongPressStart: (_) async {
          if (_permissionsGranted) {
            await _startRecording();
          } else {
            _showPermissionSnackBar(
                'Permissions required for SOS functionality');
          }
        },
        onLongPressEnd: (_) async {
          if (_permissionsGranted && _isRecording) {
            await _stopRecording();
            _showUserDataPopup(context);
          }
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 20),
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            color: _permissionsGranted ? Colors.red : Colors.grey,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: (_permissionsGranted ? Colors.red : Colors.grey)
                    .withOpacity(0.3),
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
                if (_isRecording)
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

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        _buildAnimatedActionButton(
          icon: Icons.shield,
          title: 'Nearest Safe Zone',
          color: Colors.blue,
          onTap: () {
            Navigator.pushNamed(context, '/safeZones');
          },
        ),
        const SizedBox(height: 20),
        _buildAnimatedActionButton(
          icon: Icons.map,
          title: 'WayFinder',
          color: Colors.blue,
          onTap: () {
            Navigator.pushNamed(context, '/kidsNavi');
          },
        ),
        const SizedBox(height: 20),
        _buildAnimatedActionButton(
          icon: Icons.warning,
          title: 'Risky Zones',
          color: Colors.red,
          onTap: () {
            Navigator.pushNamed(context, '/dangerZones');
          },
        ),
      ],
    );
  }

  Widget _buildAnimatedActionButton({
    required IconData icon,
    required String title,
    required Color color,
    VoidCallback? onTap,
  }) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(-1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      )),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 3,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _recorder.closeRecorder();
    _player.closePlayer();
    _animationController.dispose();
    super.dispose();
  }
}
