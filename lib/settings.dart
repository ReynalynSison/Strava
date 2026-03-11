import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'main.dart';
import 'models/activity_model.dart';
import 'services/storage_service.dart';

class Settings extends StatefulWidget {
  const Settings({super.key});

  @override
  State<Settings> createState() => _SettingsState();
}

class _SettingsState extends State<Settings> {
  final box = Hive.box("database");

  // ─── Tile builder ─────────────────────────────────────────────────────────

  Widget _tile({
    required Widget trailing,
    required String title,
    required Color color,
    required IconData icon,
    String additionalInfo = '',
    VoidCallback? onTap,
  }) {
    final tile = CupertinoListTile(
      title: Text(title),
      additionalInfo: Text(additionalInfo),
      trailing: trailing,
      leading: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: color,
        ),
        child: Icon(icon, size: 17),
      ),
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: tile);
    }
    return tile;
  }

  // ─── Seed Test Data ───────────────────────────────────────────────────────

  Future<void> _seedTestRun(BuildContext ctx) async {
    // A realistic ~5 km run around a city block (Barcelona, Spain area)
    // Coordinates form a proper loop so the polyline looks like a real route
    final List<Map<String, double>> coords = [
      {'lat': 41.3851, 'lng': 2.1734},
      {'lat': 41.3858, 'lng': 2.1742},
      {'lat': 41.3865, 'lng': 2.1750},
      {'lat': 41.3872, 'lng': 2.1761},
      {'lat': 41.3880, 'lng': 2.1775},
      {'lat': 41.3889, 'lng': 2.1789},
      {'lat': 41.3895, 'lng': 2.1802},
      {'lat': 41.3900, 'lng': 2.1815},
      {'lat': 41.3905, 'lng': 2.1830},
      {'lat': 41.3910, 'lng': 2.1845},
      {'lat': 41.3912, 'lng': 2.1858},
      {'lat': 41.3910, 'lng': 2.1872},
      {'lat': 41.3905, 'lng': 2.1885},
      {'lat': 41.3898, 'lng': 2.1895},
      {'lat': 41.3890, 'lng': 2.1902},
      {'lat': 41.3880, 'lng': 2.1907},
      {'lat': 41.3870, 'lng': 2.1908},
      {'lat': 41.3860, 'lng': 2.1905},
      {'lat': 41.3851, 'lng': 2.1898},
      {'lat': 41.3845, 'lng': 2.1888},
      {'lat': 41.3840, 'lng': 2.1875},
      {'lat': 41.3838, 'lng': 2.1861},
      {'lat': 41.3838, 'lng': 2.1847},
      {'lat': 41.3840, 'lng': 2.1833},
      {'lat': 41.3843, 'lng': 2.1819},
      {'lat': 41.3847, 'lng': 2.1807},
      {'lat': 41.3851, 'lng': 2.1734}, // loop back to start
    ];

    final activity = ActivityModel(
      distance: 4820,       // ~4.82 km in meters
      durationSeconds: 1680, // 28:00 min
      pace: 5.79,            // ~5'47"/km
      date: DateTime.now().subtract(const Duration(hours: 2)),
      routeCoordinates: coords,
    );

    await StorageService().saveActivity(activity);
    if (!mounted) return;

    showCupertinoDialog(
      context: ctx,
      builder: (_) => CupertinoAlertDialog(
        title: const Text('Test Run Added ✅'),
        content: const Text(
          'A ~4.8 km test run has been saved.\nCheck Home and History tabs.',
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('OK'),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (context, Box db, _) {
        return CupertinoPageScaffold(
          navigationBar: const CupertinoNavigationBar(
            middle: Text('Settings'),
          ),
          child: ListView(
            children: [
              // ── APPEARANCE ────────────────────────────────────────
              CupertinoListSection.insetGrouped(
                header: const Text('APPEARANCE'),
                children: [
                  _tile(
                    trailing: CupertinoSwitch(
                      value: db.get("darkMode", defaultValue: false),
                      onChanged: (v) => box.put("darkMode", v),
                    ),
                    title: 'Dark Mode',
                    color: CupertinoColors.systemIndigo,
                    icon: CupertinoIcons.moon_fill,
                  ),
                ],
              ),

              // ── UNITS ─────────────────────────────────────────────
              CupertinoListSection.insetGrouped(
                header: const Text('UNITS'),
                children: [
                  _tile(
                    trailing: CupertinoSwitch(
                      value: db.get("useMetric", defaultValue: true),
                      onChanged: (v) => box.put("useMetric", v),
                    ),
                    title: 'Use Metric',
                    additionalInfo: db.get("useMetric", defaultValue: true)
                        ? 'km'
                        : 'miles',
                    color: CupertinoColors.systemTeal,
                    icon: CupertinoIcons.globe,
                  ),
                ],
              ),

              // ── SECURITY ──────────────────────────────────────────
              CupertinoListSection.insetGrouped(
                header: const Text('SECURITY'),
                children: [
                  _tile(
                    trailing: CupertinoSwitch(
                      value: db.get("biometrics", defaultValue: false),
                      onChanged: (v) => box.put("biometrics", v),
                    ),
                    title: 'Biometrics',
                    color: CupertinoColors.systemGreen,
                    icon: CupertinoIcons.lock_shield_fill,
                  ),
                ],
              ),


              // ── DEV / TESTING ─────────────────────────────────────────
              CupertinoListSection.insetGrouped(
                header: const Text('DEV / TESTING'),
                children: [
                  _tile(
                    trailing: const Icon(CupertinoIcons.plus_circle_fill,
                        color: CupertinoColors.systemGreen),
                    title: 'Seed Test Run',
                    additionalInfo: '~4.8 km',
                    color: CupertinoColors.systemGreen,
                    icon: CupertinoIcons.hare_fill,
                    onTap: () => _seedTestRun(context),
                  ),
                ],
              ),

              // ── ACCOUNT ───────────────────────────────────────────
              CupertinoListSection.insetGrouped(
                header: const Text('ACCOUNT'),
                children: [
                  _tile(
                    trailing: const Icon(CupertinoIcons.chevron_forward),
                    title: 'Sign Out',
                    color: CupertinoColors.systemPurple,
                    icon: CupertinoIcons.square_arrow_left,
                    additionalInfo: db.get("username") ?? '',
                    onTap: () {
                      showCupertinoDialog(
                        context: context,
                        builder: (ctx) => CupertinoAlertDialog(
                          title: const Text('Sign Out?'),
                          content: const Text(
                              'You will need your username and password to sign back in.'),
                          actions: [
                            CupertinoDialogAction(
                              isDestructiveAction: true,
                              child: const Text('Sign Out'),
                              onPressed: () {
                                Navigator.pop(ctx);
                                Navigator.pushReplacement(
                                  context,
                                  CupertinoPageRoute(
                                      builder: (_) => const LoginPage()),
                                );
                              },
                            ),
                            CupertinoDialogAction(
                              isDefaultAction: true,
                              child: const Text('Cancel'),
                              onPressed: () => Navigator.pop(ctx),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

