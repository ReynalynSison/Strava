import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'main.dart';
import 'providers/app_providers.dart';

// --- Theme Constants ---
const Color themeBlue = CupertinoColors.activeBlue;

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
    final titleColor = CupertinoColors.label.resolveFrom(context);
    final infoColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoListTile(
      onTap: onTap,
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: titleColor,
        ),
      ),
      additionalInfo: Text(
        additionalInfo,
        style: TextStyle(color: infoColor),
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

  // ─── Logic (Delete) ──────────────────────────────────────────────────────

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
    final scaffoldBg = CupertinoColors.systemGroupedBackground.resolveFrom(context);
    final sectionHeaderColor = CupertinoColors.secondaryLabel.resolveFrom(context);
    final trailingChevronColor = CupertinoColors.systemGrey2.resolveFrom(context);
    final versionColor = CupertinoColors.secondaryLabel.resolveFrom(context);

    return CupertinoPageScaffold(
      backgroundColor: scaffoldBg,
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('Settings'),
            backgroundColor: scaffoldBg.withValues(alpha: 0.85),
            border: null,
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              // ── APPEARANCE ──
              CupertinoListSection.insetGrouped(
                header: Text(
                  'APPEARANCE',
                  style: TextStyle(color: sectionHeaderColor),
                ),
                children: [
                  _tile(
                    trailing: CupertinoSwitch(
                      activeTrackColor: themeBlue,
                      trackColor: CupertinoColors.systemGrey4.resolveFrom(context),
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
                header: Text(
                  'PREFERENCES',
                  style: TextStyle(color: sectionHeaderColor),
                ),
                children: [
                  _tile(
                    trailing: CupertinoSwitch(
                      activeTrackColor: themeBlue,
                      trackColor: CupertinoColors.systemGrey4.resolveFrom(context),
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
                      activeTrackColor: themeBlue,
                      trackColor: CupertinoColors.systemGrey4.resolveFrom(context),
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
                header: Text(
                  'SECURITY & DATA',
                  style: TextStyle(color: sectionHeaderColor),
                ),
                children: [
                  _tile(
                    trailing: CupertinoSwitch(
                      activeTrackColor: themeBlue,
                      trackColor: CupertinoColors.systemGrey4.resolveFrom(context),
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
                        : Icon(
                            CupertinoIcons.chevron_forward,
                            size: 18,
                            color: trailingChevronColor,
                          ),
                    title: 'Clear All Data',
                    color: CupertinoColors.systemRed,
                    icon: CupertinoIcons.trash_fill,
                    onTap: _isDeletingAll ? null : () => _deleteAllActivities(context),
                  ),
                ],
              ),


              // ── ACCOUNT ──
              CupertinoListSection.insetGrouped(
                header: Text(
                  'ACCOUNT',
                  style: TextStyle(color: sectionHeaderColor),
                ),
                children: [
                  _tile(
                    trailing: const Icon(CupertinoIcons.power, color: CupertinoColors.systemRed, size: 20),
                    title: 'Sign Out',
                    additionalInfo: settings.username,
                    color: CupertinoColors.systemPurple,
                    icon: CupertinoIcons.person,
                    onTap: () => _showSignOutDialog(context),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Center(
                child: Text(
                  'RunTracker v1.0.4',
                  style: TextStyle(
                    fontSize: 13,
                    color: versionColor,
                  ),
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