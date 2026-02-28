import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import 'package:safety_pal/theme/app_theme.dart';
import 'package:safety_pal/providers/auth_provider.dart';
import 'package:safety_pal/services/permission_service.dart';
import 'package:safety_pal/services/sos_service.dart';
import 'package:safety_pal/screens/main_shell.dart';
import 'package:safety_pal/widgets/shared_components.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();

  bool _isRecording = false;
  String? _audioFilePath;
  bool _isSOSActive = false;
  bool _permissionsGranted = false;
  bool _isLoadingPermissions = true;
  String? _currentAddress;
  double? _latitude;
  double? _longitude;

  late AnimationController _pulseController;
  late AnimationController _fadeInController;
  late Animation<double> _pulseAnimation;

  // SOS flow state
  int _sosFlowState = 0; // 0=idle, 1=hold, 2=recording, 3=countdown, 4=active

  // SOS status checklist
  bool _smsSent = false;
  bool _emailSent = false;
  bool _teamAlerted = false;
  ValueNotifier<bool> _sosCancelToken = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeInController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeInController.forward();

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await _requestAllPermissions();
    await _initializeRecorder();
    await _fetchLocation();

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.refreshUserData();
    } catch (_) {}
  }

  Future<void> _requestAllPermissions() async {
    try {
      setState(() => _isLoadingPermissions = true);
      bool allGranted = await PermissionService.requestAllPermissions();
      setState(() {
        _permissionsGranted = allGranted;
        _isLoadingPermissions = false;
      });
    } catch (_) {
      setState(() {
        _permissionsGranted = false;
        _isLoadingPermissions = false;
      });
    }
  }

  Future<void> _initializeRecorder() async {
    try {
      await _recorder.openRecorder();
      await _recorder.setSubscriptionDuration(const Duration(milliseconds: 500));
    } catch (_) {}
  }

  Future<void> _fetchLocation() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      List<Placemark> placemarks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        setState(() {
          _latitude = pos.latitude;
          _longitude = pos.longitude;
          _currentAddress =
              "${p.street ?? ''}, ${p.locality ?? ''}, ${p.administrativeArea ?? ''}";
        });
      }
    } catch (_) {
      setState(() => _currentAddress = "Location unavailable");
    }
  }

  Future<void> _startRecording() async {
    if (!_permissionsGranted) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      _audioFilePath = '${directory.path}/recorded_audio.aac';
      await _recorder.startRecorder(toFile: _audioFilePath);
      setState(() {
        _isRecording = true;
        _sosFlowState = 2;
      });
    } catch (_) {}
  }

  Future<void> _stopRecording() async {
    try {
      await _recorder.stopRecorder();
      setState(() {
        _isRecording = false;
      });
    } catch (_) {}
  }

  void _triggerSOS() async {
    if (!_permissionsGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Permissions required for SOS')),
      );
      return;
    }

    // Reset cancel token for fresh SOS
    _sosCancelToken.value = false;

    // Go directly to emergency active screen and start executing SOS
    setState(() {
      _sosFlowState = 4;
      _isSOSActive = true;
    });
    await _executeSOS();
  }

  Future<void> _executeSOS() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userData = authProvider.userData;
      if (userData == null) return;

      final List<Map<String, dynamic>> guardians = [];
      if (userData['guardians'] is List) {
        guardians.addAll(List<Map<String, dynamic>>.from(userData['guardians']));
      } else if (userData['trustedGuardians'] is List) {
        guardians.addAll(
            List<Map<String, dynamic>>.from(userData['trustedGuardians']));
      }

      // Reset all status flags
      setState(() {
        _smsSent = false;
        _emailSent = false;
        _teamAlerted = false;
      });

      await SOSService.triggerExtendedSOS(
        context: context,
        userData: userData,
        guardians: guardians,
        audioPath: _audioFilePath ?? '',
        triggerType: 'manual_button',
        cancelToken: _sosCancelToken,
        onProgress: (step, success) {
          if (!mounted || _sosCancelToken.value) return;
          setState(() {
            switch (step) {
              case 'sms':
                _smsSent = success;
                break;
              case 'email':
                _emailSent = success;
                break;
              case 'calling':
                _teamAlerted = success;
                break;
              case 'team_cancelled':
                // Team alert cancelled — notify user and return to idle
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                        'Guardian alerts sent. Safety Pal team alert cancelled.'),
                    backgroundColor: AppTheme.warning,
                    duration: const Duration(seconds: 3),
                  ),
                );
                _sosFlowState = 0;
                _isSOSActive = false;
                break;
            }
          });
        },
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _sosFlowState = 0;
          _isSOSActive = false;
        });
      }
    }
  }

  void _cancelSOS() {
    _sosCancelToken.value = true;
    setState(() {
      _sosFlowState = 0;
      _isSOSActive = false;
      _smsSent = false;
      _emailSent = false;
      _teamAlerted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_sosFlowState == 4) return _buildEmergencyActiveScreen();

    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final userName = authProvider.userData?['name'] as String? ?? 'User';
        return Scaffold(
          backgroundColor: AppTheme.background,
          body: _isLoadingPermissions
              ? _buildLoadingState()
              : SafeArea(
                  child: FadeTransition(
                    opacity: _fadeInController,
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _buildTopHeader(userName)),
                        SliverToBoxAdapter(child: _buildSOSSection()),
                        SliverToBoxAdapter(child: _buildQuickActions()),
                        SliverToBoxAdapter(child: _buildLocationCard()),
                        SliverToBoxAdapter(
                            child: _buildEmergencyCallSection()),
                        const SliverToBoxAdapter(
                            child: SizedBox(height: 100)),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.coralLight,
              shape: BoxShape.circle,
            ),
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryRed),
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 20),
          Text('Setting up Safety Pal...', style: AppTheme.bodyLarge),
          const SizedBox(height: 8),
          Text('Requesting permissions', style: AppTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _buildTopHeader(String userName) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you in emergency?',
                  style: AppTheme.displayMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Hi $userName, we\'re here for you',
                  style: AppTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Notification icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.cardWhite,
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              boxShadow: AppTheme.cardShadow,
            ),
            child: const Icon(
              Icons.notifications_outlined,
              color: AppTheme.textSecondary,
              size: 22,
            ),
          ),
          const SizedBox(width: 8),
          // Profile avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              boxShadow: AppTheme.cardShadow,
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 22),
          ),
        ],
      ),
    );
  }

  Widget _buildSOSSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          // SOS Button with pulsing animation
          Center(
            child: GestureDetector(
              onLongPressStart: (_) async {
                HapticFeedback.heavyImpact();
                setState(() => _sosFlowState = 1);
                if (_permissionsGranted) {
                  await _startRecording();
                }
              },
              onLongPressEnd: (_) async {
                if (_permissionsGranted && _isRecording) {
                  await _stopRecording();
                }
                _triggerSOS();
              },
              onTap: () {
                HapticFeedback.mediumImpact();
                _triggerSOS();
              },
              child: AnimatedBuilder2(
                listenable: _pulseAnimation,
                builder: (context, _) {
                  final scale = _permissionsGranted
                      ? _pulseAnimation.value
                      : 1.0;
                  return Transform.scale(
                    scale: _sosFlowState == 1 ? 0.92 : scale,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _permissionsGranted
                            ? AppTheme.sosGradient
                            : null,
                        color: _permissionsGranted
                            ? null
                            : AppTheme.textTertiary,
                        boxShadow: _permissionsGranted
                            ? AppTheme.sosShadow(
                                _sosFlowState == 1 ? 1.5 : 1.0)
                            : null,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'SOS',
                              style: TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 42,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 4,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            if (_sosFlowState == 2)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Recording...',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Hold or Shake to activate',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textTertiary,
            ),
          ),
          if (!_permissionsGranted) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _requestAllPermissions,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.warningLight,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_rounded,
                        size: 16, color: AppTheme.warning),
                    const SizedBox(width: 6),
                    Text(
                      'Permissions required — Tap to grant',
                      style: AppTheme.bodySmall
                          .copyWith(color: AppTheme.warning),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SPSectionHeader(title: 'Quick Actions'),
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildQuickActionCard(
                  icon: Icons.phone_in_talk_rounded,
                  label: 'Emergency\nCall',
                  color: AppTheme.danger,
                  onTap: () => _directCall('100'),
                ),
                const SizedBox(width: 12),
                _buildQuickActionCard(
                  icon: Icons.shield_rounded,
                  label: 'Safe\nZones',
                  color: AppTheme.safeGreen,
                  onTap: () => MainShell.switchTab?.call(1),
                ),
                const SizedBox(width: 12),
                _buildQuickActionCard(
                  icon: Icons.report_problem_rounded,
                  label: 'Report\nIncident',
                  color: AppTheme.warning,
                  onTap: () => MainShell.switchTab?.call(2),
                ),
                const SizedBox(width: 12),
                _buildQuickActionCard(
                  icon: Icons.location_on_rounded,
                  label: 'Live\nLocation',
                  color: AppTheme.info,
                  onTap: () => MainShell.switchTab?.call(1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTheme.labelMedium.copyWith(
                fontSize: 11,
                height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: SPCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: AppTheme.primaryRed,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your current address',
                      style: AppTheme.labelMedium),
                  const SizedBox(height: 4),
                  Text(
                    _currentAddress ?? 'Detecting location...',
                    style: AppTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _fetchLocation,
              icon: const Icon(Icons.refresh_rounded,
                  color: AppTheme.textTertiary, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyCallSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SPSectionHeader(title: 'Emergency Services'),
          Row(
            children: [
              Expanded(
                  child: _buildEmergencyServiceCard(
                Icons.local_police_rounded,
                'Police',
                '100',
                AppTheme.info,
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildEmergencyServiceCard(
                Icons.local_hospital_rounded,
                'Ambulance',
                '102',
                AppTheme.danger,
              )),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildEmergencyServiceCard(
                Icons.local_fire_department_rounded,
                'Fire',
                '101',
                AppTheme.warning,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyServiceCard(
      IconData icon, String label, String number, Color color) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.mediumImpact();
        // Direct call using flutter_phone_direct_caller
        import_call(number);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label, style: AppTheme.labelMedium),
            Text(number, style: AppTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  void import_call(String number) async {
    try {
      await FlutterPhoneDirectCaller.callNumber(number);
    } catch (e) {
      debugPrint('[CALL] Error calling $number: $e');
    }
  }

  void _directCall(String number) {
    HapticFeedback.mediumImpact();
    import_call(number);
  }

  // ── EMERGENCY ACTIVE SCREEN ──────────────────────────────────────────────
  Widget _buildEmergencyActiveScreen() {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(gradient: AppTheme.emergencyActiveGradient),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              // Animated ambulance icon
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.local_hospital_rounded,
                        color: Colors.white,
                        size: 56,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Emergency Alert Sent',
                      style: AppTheme.displayMedium.copyWith(
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Help is on the way. Stay safe.',
                      style: AppTheme.bodyLarge.copyWith(
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // Status checklist
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildStatusItem(
                          'SMS Sent to Guardians', _smsSent,
                          isLoading: !_smsSent),
                      const SizedBox(height: 16),
                      _buildStatusItem(
                          'Email Alert Sent', _emailSent,
                          isLoading: _smsSent && !_emailSent),
                      const SizedBox(height: 16),
                      _buildStatusItem(
                          'Safety Pal Team Alerted', _teamAlerted,
                          isLoading: _emailSent && !_teamAlerted),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              // Action buttons
              Padding(
                padding: const EdgeInsets.all(24),
                child: GestureDetector(
                  onTap: _cancelSOS,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMD),
                    ),
                    child: Center(
                      child: Text(
                        'Cancel Request',
                        style: AppTheme.buttonText.copyWith(
                          color: AppTheme.primaryRed,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, bool completed,
      {bool isLoading = false}) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: completed
                ? Colors.white.withOpacity(0.2)
                : Colors.white.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isLoading && !completed
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withOpacity(0.7),
                      ),
                    ),
                  )
                : Icon(
                    completed ? Icons.check_rounded : Icons.hourglass_empty,
                    size: 16,
                    color: Colors.white,
                  ),
          ),
        ),
        const SizedBox(width: 14),
        Text(
          label,
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 16,
            fontWeight: completed ? FontWeight.w600 : FontWeight.w400,
            color: Colors.white.withOpacity(completed ? 1.0 : 0.7),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _sosCancelToken.dispose();
    _recorder.closeRecorder();
    _pulseController.dispose();
    _fadeInController.dispose();
    super.dispose();
  }
}
