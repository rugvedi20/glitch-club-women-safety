import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'package:safety_pal/theme/app_theme.dart';
import 'package:safety_pal/providers/auth_provider.dart' as app;
import 'package:safety_pal/services/user_service.dart';
import 'package:safety_pal/widgets/shared_components.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _locationEnabled = true;
  bool _microphoneEnabled = true;
  bool _notificationsEnabled = true;

  // Device states
  bool _deviceConnected = false;
  bool _gpsConnected = false;
  bool _networkActive = false;
  int _batteryPercent = 0;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  Widget build(BuildContext context) {
    return Consumer<app.AuthProvider>(
      builder: (context, authProvider, _) {
        final userData = authProvider.userData;
        final name = userData?['name'] as String? ?? 'User';
        final phone = userData?['phone'] as String? ?? '--';
        final email = userData?['email'] as String? ?? '--';
        final rawGuardians = userData?['guardians'] as List? ??
            userData?['trustedGuardians'] as List? ??
            [];
        final guardians = rawGuardians
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(
                    child: _buildUserInfoCard(name, phone, email)),
                SliverToBoxAdapter(
                    child: _buildGuardiansSection(guardians, authProvider)),
                SliverToBoxAdapter(child: _buildPermissionsSection()),
                SliverToBoxAdapter(child: _buildDeviceSection()),
                SliverToBoxAdapter(
                    child: _buildLogoutButton(authProvider)),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Text('Profile', style: AppTheme.displayMedium),
    );
  }

  Widget _buildUserInfoCard(String name, String phone, String email) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardWhite,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: Center(
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.phone_rounded,
                          size: 14, color: AppTheme.textTertiary),
                      const SizedBox(width: 4),
                      Text(phone, style: AppTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.email_rounded,
                          size: 14, color: AppTheme.textTertiary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          email,
                          style: AppTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── GUARDIANS SECTION ─────────────────────────────────────────────────

  Widget _buildGuardiansSection(
      List<Map<String, dynamic>> guardians, app.AuthProvider authProvider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Trusted Guardians', style: AppTheme.headlineMedium),
              GestureDetector(
                onTap: () => _showAddGuardianDialog(authProvider),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRed.withOpacity(0.1),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded,
                          size: 16, color: AppTheme.primaryRed),
                      const SizedBox(width: 4),
                      Text(
                        'Add',
                        style: AppTheme.labelMedium.copyWith(
                          color: AppTheme.primaryRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (guardians.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.cardWhite,
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusLG),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  const Icon(Icons.group_outlined,
                      size: 40, color: AppTheme.textTertiary),
                  const SizedBox(height: 12),
                  Text("No guardians added yet",
                      style: AppTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(
                    "Add trusted contacts for emergency alerts",
                    style: AppTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ...guardians.asMap().entries.map((entry) {
              final index = entry.key;
              final guardian = entry.value;
              return _buildGuardianCard(
                  index, guardian, guardians, authProvider);
            }),
        ],
      ),
    );
  }

  Widget _buildGuardianCard(int index, Map<String, dynamic> guardian,
      List<Map<String, dynamic>> allGuardians, app.AuthProvider authProvider) {
    final colors = [AppTheme.info, AppTheme.success, AppTheme.warning, AppTheme.coral];
    final color = colors[index % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardWhite,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: Center(
              child: Icon(Icons.person_rounded, color: color, size: 22),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guardian['name'] as String? ?? 'Guardian ${index + 1}',
                  style: AppTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  guardian['phone'] as String? ?? '--',
                  style: AppTheme.bodySmall,
                ),
                if ((guardian['email'] as String? ?? '').isNotEmpty)
                  Text(
                    guardian['email'] as String,
                    style: AppTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          // Edit button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showEditGuardianDialog(guardian, authProvider);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
              child: const Icon(Icons.edit_rounded,
                  size: 18, color: AppTheme.info),
            ),
          ),
          const SizedBox(width: 6),
          // Delete button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _showDeleteGuardianDialog(guardian, authProvider);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.dangerLight,
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  size: 18, color: AppTheme.danger),
            ),
          ),
        ],
      ),
    );
  }

  // ── ADD GUARDIAN ──────────────────────────────────────────────────────

  void _showAddGuardianDialog(app.AuthProvider authProvider) {
    final nameC = TextEditingController();
    final phoneC = TextEditingController();
    final emailC = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => _GuardianFormDialog(
        title: 'Add Guardian',
        nameController: nameC,
        phoneController: phoneC,
        emailController: emailC,
        onSave: () async {
          if (nameC.text.trim().isEmpty || phoneC.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Name and phone are required')),
            );
            return;
          }
          Navigator.pop(ctx);
          try {
            await UserService.addGuardian(
              uid: _uid!,
              guardianName: nameC.text.trim(),
              guardianPhone: phoneC.text.trim(),
              guardianEmail: emailC.text.trim(),
            );
            await authProvider.refreshUserData();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Guardian added successfully')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error adding guardian: $e')),
              );
            }
          }
        },
      ),
    );
  }

  // ── EDIT GUARDIAN ─────────────────────────────────────────────────────

  void _showEditGuardianDialog(
      Map<String, dynamic> oldGuardian, app.AuthProvider authProvider) {
    final nameC =
        TextEditingController(text: oldGuardian['name'] as String? ?? '');
    final phoneC =
        TextEditingController(text: oldGuardian['phone'] as String? ?? '');
    final emailC =
        TextEditingController(text: oldGuardian['email'] as String? ?? '');

    showDialog(
      context: context,
      builder: (ctx) => _GuardianFormDialog(
        title: 'Edit Guardian',
        nameController: nameC,
        phoneController: phoneC,
        emailController: emailC,
        onSave: () async {
          if (nameC.text.trim().isEmpty || phoneC.text.trim().isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Name and phone are required')),
            );
            return;
          }
          Navigator.pop(ctx);
          try {
            // Remove old, add new (Firestore arrayUnion/arrayRemove)
            await UserService.removeGuardian(
                uid: _uid!, guardian: oldGuardian);
            await UserService.addGuardian(
              uid: _uid!,
              guardianName: nameC.text.trim(),
              guardianPhone: phoneC.text.trim(),
              guardianEmail: emailC.text.trim(),
            );
            await authProvider.refreshUserData();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Guardian updated successfully')),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error updating guardian: $e')),
              );
            }
          }
        },
      ),
    );
  }

  // ── DELETE GUARDIAN ────────────────────────────────────────────────────

  void _showDeleteGuardianDialog(
      Map<String, dynamic> guardian, app.AuthProvider authProvider) {
    final name = guardian['name'] as String? ?? 'this guardian';
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.dangerLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_rounded,
                    color: AppTheme.danger, size: 28),
              ),
              const SizedBox(height: 16),
              Text('Remove Guardian?', style: AppTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to remove $name from your trusted guardians?',
                style: AppTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.divider),
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusMD),
                        ),
                        child: Center(
                          child:
                              Text('Cancel', style: AppTheme.labelLarge),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx);
                        try {
                          await UserService.removeGuardian(
                              uid: _uid!, guardian: guardian);
                          await authProvider.refreshUserData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Guardian removed successfully')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(
                                      'Error removing guardian: $e')),
                            );
                          }
                        }
                      },
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: AppTheme.danger,
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusMD),
                        ),
                        child: Center(
                          child: Text('Remove',
                              style: AppTheme.buttonText),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── PERMISSIONS ───────────────────────────────────────────────────────

  Widget _buildPermissionsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Privacy & Permissions', style: AppTheme.headlineMedium),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.cardWhite,
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                _buildPermissionTile(
                  icon: Icons.location_on_rounded,
                  label: 'Location',
                  subtitle: 'Required for emergency alerts',
                  value: _locationEnabled,
                  onChanged: (v) =>
                      setState(() => _locationEnabled = v),
                ),
                const Divider(height: 1, indent: 56),
                _buildPermissionTile(
                  icon: Icons.mic_rounded,
                  label: 'Microphone',
                  subtitle: 'For emergency recording',
                  value: _microphoneEnabled,
                  onChanged: (v) =>
                      setState(() => _microphoneEnabled = v),
                ),
                const Divider(height: 1, indent: 56),
                _buildPermissionTile(
                  icon: Icons.notifications_rounded,
                  label: 'Notifications',
                  subtitle: 'Stay informed about alerts',
                  value: _notificationsEnabled,
                  onChanged: (v) =>
                      setState(() => _notificationsEnabled = v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child:
                Icon(icon, color: AppTheme.primaryRed, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTheme.titleMedium),
                Text(subtitle, style: AppTheme.bodySmall),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.primaryRed,
            activeTrackColor: AppTheme.coralLight,
            inactiveThumbColor: AppTheme.iconGrey,
            inactiveTrackColor: AppTheme.divider,
          ),
        ],
      ),
    );
  }

  // ── DEVICE SECTION ────────────────────────────────────────────────────

  Widget _buildDeviceSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Suraksha Netra Device', style: AppTheme.headlineMedium),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.cardWhite,
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
              boxShadow: AppTheme.cardShadow,
            ),
            child: _deviceConnected
                ? _buildDeviceConnectedView()
                : _buildDeviceNotConnectedView(),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceNotConnectedView() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.bluetooth_disabled_rounded,
              size: 40, color: AppTheme.textTertiary),
        ),
        const SizedBox(height: 16),
        Text('Device not connected', style: AppTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Connect your Suraksha Netra device\nto enable hardware safety features.',
          style: AppTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        SPOutlinedButton(
          text: 'Connect Device',
          icon: Icons.bluetooth_rounded,
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildDeviceConnectedView() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildDeviceStatus(
              Icons.gps_fixed_rounded,
              'GPS',
              _gpsConnected ? 'Connected' : 'Off',
              _gpsConnected ? AppTheme.success : AppTheme.textTertiary,
            ),
            _buildDeviceStatus(
              Icons.wifi_rounded,
              'Network',
              _networkActive ? 'Active' : 'Off',
              _networkActive ? AppTheme.success : AppTheme.textTertiary,
            ),
            _buildDeviceStatus(
              Icons.battery_charging_full_rounded,
              'Battery',
              '$_batteryPercent%',
              _batteryPercent > 20
                  ? AppTheme.success
                  : AppTheme.danger,
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SPOutlinedButton(
                text: 'Test Device',
                onPressed: () {},
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SPOutlinedButton(
                text: 'Device Info',
                onPressed: () {},
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDeviceStatus(
      IconData icon, String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(label, style: AppTheme.labelMedium),
        Text(value,
            style: AppTheme.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            )),
      ],
    );
  }

  // ── LOGOUT ────────────────────────────────────────────────────────────

  Widget _buildLogoutButton(app.AuthProvider authProvider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: GestureDetector(
        onTap: () => _showLogoutConfirmation(authProvider),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.cardWhite,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Center(
            child: Text(
              'Logout',
              style: AppTheme.labelLarge.copyWith(
                color: AppTheme.danger,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirmation(app.AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                  color: AppTheme.dangerLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded,
                    color: AppTheme.danger, size: 28),
              ),
              const SizedBox(height: 16),
              Text('Logout?', style: AppTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to logout?\nYou can login again anytime.',
                style: AppTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.divider),
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusMD),
                        ),
                        child: Center(
                          child: Text('Cancel',
                              style: AppTheme.labelLarge),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(context);
                        await authProvider.logout();
                        if (mounted) {
                          Navigator.of(context)
                              .pushReplacementNamed('/');
                        }
                      },
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: AppTheme.danger,
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusMD),
                        ),
                        child: Center(
                          child: Text('Logout',
                              style: AppTheme.buttonText),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// GUARDIAN ADD/EDIT FORM DIALOG
// ════════════════════════════════════════════════════════════════════════════

class _GuardianFormDialog extends StatelessWidget {
  final String title;
  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final VoidCallback onSave;

  const _GuardianFormDialog({
    required this.title,
    required this.nameController,
    required this.phoneController,
    required this.emailController,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTheme.headlineMedium),
            const SizedBox(height: 20),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Name *',
                prefixIcon: const Icon(Icons.person_outline_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: phoneController,
              decoration: InputDecoration(
                labelText: 'Phone *',
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email (optional)',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.divider),
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMD),
                      ),
                      child: Center(
                        child: Text('Cancel', style: AppTheme.labelLarge),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: onSave,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMD),
                      ),
                      child: Center(
                        child: Text('Save', style: AppTheme.buttonText),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
