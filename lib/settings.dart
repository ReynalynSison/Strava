import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'main.dart';
import 'models/activity_model.dart';
import 'providers/app_providers.dart';

// --- Theme Constants ---
const Color themeBlue = CupertinoColors.activeBlue;
const Color themeTeal = Color(0xFF64FFDA);

class Settings extends ConsumerStatefulWidget {
  const Settings({super.key});

  @override
  ConsumerState<Settings> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<Settings> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _isDeletingAll = false;

  // ─── Refined Tile Builder ─────────────────────────────────────────────────
  Widget _tile({
    required Widget trailing,
    required String title,
    required Color color,
    required IconData icon,
    String additionalInfo = '',
    VoidCallback? onTap,
  }) {
    return CupertinoListTile(
      onTap: onTap,
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      additionalInfo: Text(
        additionalInfo,
        style: const TextStyle(color: CupertinoColors.secondaryLabel),
      ),
      trailing: trailing,
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: color,
        ),
        child: Icon(icon, size: 18, color: CupertinoColors.white),
      ),
    );
  }

  // ─── Logic (Seed & Delete) ───────────────────────────────────────────────
  // (Pinanatili ko ang iyong original logic dito para sa functionality)

  Future<void> _seedTestRun(BuildContext ctx) async {
    final List<Map<String, double>> coords = [
      {'lat': 41.3851, 'lng': 2.1734},
      {'lat': 41.3858, 'lng': 2.1742},
      {'lat': 41.3851, 'lng': 2.1734},
    ];

    final activity = ActivityModel(
      distance: 4820,
      durationSeconds: 1680,
      pace: 5.79,
      date: DateTime.now().subtract(const Duration(hours: 2)),
      routeCoordinates: coords,
    );

    await ref.read(activityProvider.notifier).addActivity(activity);
    if (!mounted) return;

    showCupertinoDialog(
      context: ctx,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Test Run Added ✅'),
        content: const Text('A ~4.8 km test run has been saved.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAllActivities(BuildContext ctx) async {
    final biometricsEnabled = ref.read(appSettingsProvider).biometrics;
    if (biometricsEnabled) {
      try {
        final authenticated = await _auth.authenticate(
          localizedReason: 'Confirm deleting all activities',
        );
        if (!authenticated) return;
      } catch (e) {
        // Biometric auth failed, continue without it
      }
    }

    if (!mounted) return;

    showCupertinoDialog(
      context: ctx,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Delete All Activities?'),
        content: const Text('This will permanently delete every recorded run.'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isDeletingAll = true);
              await ref.read(activityProvider.notifier).clearActivities();
              if (mounted) setState(() => _isDeletingAll = false);
              Navigator.of(ctx).popUntil((r) => r.isFirst);
            },
            child: const Text('Delete All'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    return CupertinoPageScaffold(
      backgroundColor: isDark ? CupertinoColors.black : const Color(0xFFF2F2F7),
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Settings'),
            backgroundColor: (isDark ? CupertinoColors.black : const Color(0xFFF2F2F7)).withOpacity(0.8),
            border: null,
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              // ── APPEARANCE ──
              CupertinoListSection.insetGrouped(
                header: const Text('APPEARANCE'),
                children: [
                  _tile(
                    trailing: CupertinoSwitch(
                      activeColor: themeBlue,
                      value: settings.darkMode,
                      onChanged: notifier.toggleDarkMode,
                    ),
                    title: 'Dark Mode',
                    color: CupertinoColors.systemIndigo,
                    icon: CupertinoIcons.moon_fill,
                  ),
                ],
              ),

              // ── PREFERENCES ──
              CupertinoListSection.insetGrouped(
                header: const Text('PREFERENCES'),
                children: [
                  _tile(
                    trailing: CupertinoSwitch(
                      activeColor: themeBlue,
                      value: settings.useMetric,
                      onChanged: notifier.toggleUnits,
                    ),
                    title: 'Use Metric Units',
                    additionalInfo: settings.useMetric ? 'Kilometers' : 'Miles',
                    color: themeBlue,
                    icon: CupertinoIcons.arrow_up_down_circle_fill,
                  ),
                  _tile(
                    trailing: CupertinoSwitch(
                      activeColor: themeBlue,
                      value: settings.runNotificationsEnabled,
                      onChanged: notifier.toggleRunNotifications,
                    ),
                    title: 'Run Notifications',
                    additionalInfo: settings.runNotificationsEnabled ? 'Active' : 'Muted',
                    color: CupertinoColors.systemOrange,
                    icon: CupertinoIcons.bell_circle_fill,
                  ),
                ],
              ),

              // ── SECURITY & DATA ──
              CupertinoListSection.insetGrouped(
                header: const Text('SECURITY & DATA'),
                children: [
                  _tile(
                    trailing: CupertinoSwitch(
                      activeColor: themeBlue,
                      value: settings.biometrics,
                      onChanged: notifier.toggleBiometrics,
                    ),
                    title: 'Biometric Lock',
                    color: CupertinoColors.systemGreen,
                    icon: CupertinoIcons.lock_shield_fill,
                  ),
                  _tile(
                    trailing: _isDeletingAll
                        ? const CupertinoActivityIndicator()
                        : const Icon(CupertinoIcons.chevron_forward, size: 18, color: CupertinoColors.systemGrey2),
                    title: 'Clear All Data',
                    color: CupertinoColors.systemRed,
                    icon: CupertinoIcons.trash_fill,
                    onTap: _isDeletingAll ? null : () => _deleteAllActivities(context),
                  ),
                ],
              ),

              // ── DEVELOPER TOOLS ──
              CupertinoListSection.insetGrouped(
                header: const Text('DEVELOPER'),
                children: [
                  _tile(
                    trailing: const Icon(CupertinoIcons.add_circled_solid, color: themeTeal, size: 22),
                    title: 'Seed Test Run',
                    additionalInfo: 'Add 5km Activity',
                    color: themeTeal.withOpacity(0.8),
                    icon: CupertinoIcons.lab_flask_solid,
                    onTap: () => _seedTestRun(context),
                  ),
                ],
              ),

              // ── ACCOUNT ──
              CupertinoListSection.insetGrouped(
                header: const Text('ACCOUNT'),
                children: [
                  _tile(
                    trailing: const Icon(CupertinoIcons.power, color: CupertinoColors.systemRed, size: 20),
                    title: 'Sign Out',
                    additionalInfo: settings.username,
                    color: CupertinoColors.systemPurple,
                    icon: CupertinoIcons.person_crop_circle_fill_badge_exclam,
                    onTap: () => _showSignOutDialog(context),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              const Center(
                child: Text(
                  'RunTracker v1.0.4',
                  style: TextStyle(color: CupertinoColors.systemGrey, fontSize: 13),
                ),
              ),
              const SizedBox(height: 60),
            ]),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Make sure you remember your credentials to sign back in.'),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacement(context, CupertinoPageRoute(builder: (_) => const LoginPage()));
            },
            child: const Text('Sign Out'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}