import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // Required for modern Shadows and Gradients
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';

import 'homepage.dart';
import 'providers/app_providers.dart';
import 'providers/app_settings_provider.dart';
import 'services/run_notification_service.dart';
import 'signup.dart';

// --- Strivo Aesthetic Palette ---
const Color deepNavy = Color(0xFF001D39);
const Color primaryBlue = Color(0xFF0A4174);
const Color skyBlue = Color(0xFF7BBDE8);
const Color ultraLightBlue = Color(0xFFF0F5F9);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox("database");
  await Hive.openBox("activities");
  await RunNotificationService.instance.initialize();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return CupertinoApp(
      theme: CupertinoThemeData(
        brightness: settings.darkMode ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: ultraLightBlue,
        primaryColor: primaryBlue,
      ),
      debugShowCheckedModeBanner: false,
      home: settings.hasAccount ? const LoginPage() : const SignupPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  String msg = "";
  bool hidePassword = true;
  final box = Hive.box("database");
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final LocalAuthentication auth = LocalAuthentication();

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: ultraLightBlue,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // --- PREMIUM GRADIENT HEADER (Glassmorphism Style) ---
            Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.45,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [deepNavy, primaryBlue, Color(0xFF1E5BB0)],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(60),
                  bottomRight: Radius.circular(60),
                ),
                boxShadow: [
                  BoxShadow(
                    color: primaryBlue.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 40),
                  // Icon with Outer Glow
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 110,
                        width: 110,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: skyBlue.withOpacity(0.4),
                              blurRadius: 40,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 90,
                        width: 90,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                        ),
                        child: const Center(
                          child: Icon(CupertinoIcons.bolt_fill, size: 45, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    "Strivo",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                    ),
                  ),
                  const Text(
                    "WELCOME BACK",
                    style: TextStyle(
                      color: skyBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
            ),

            // --- FORM SECTION ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 40),
              child: Column(
                children: [
                  _buildAestheticInput(
                    controller: _username,
                    label: "USERNAME",
                    icon: CupertinoIcons.person_solid,
                  ),
                  const SizedBox(height: 20),
                  _buildAestheticInput(
                    controller: _password,
                    label: "PASSWORD",
                    icon: CupertinoIcons.lock_shield_fill,
                    obscure: hidePassword,
                    suffix: CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: Icon(
                        hidePassword ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                        color: primaryBlue.withOpacity(0.4),
                      ),
                      onPressed: () => setState(() => hidePassword = !hidePassword),
                    ),
                  ),

                  if (msg.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: Text(msg, style: const TextStyle(color: CupertinoColors.destructiveRed, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),

                  const SizedBox(height: 40),

                  // GRADIENT SIGN IN BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 65,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          colors: [primaryBlue, Color(0xFF1E5BB0)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryBlue.withOpacity(0.3),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: CupertinoButton(
                        padding: EdgeInsets.zero,
                        child: const Text(
                          "SIGN IN",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 16),
                        ),
                        onPressed: () {
                          if (_username.text.trim() == box.get("username") &&
                              _password.text.trim() == box.get("password")) {
                            Navigator.pushReplacement(context, CupertinoPageRoute(builder: (context) => const Homepage()));
                          } else {
                            setState(() => msg = "Invalid Username or Password");
                          }
                        },
                      ),
                    ),
                  ),

                  // BIOMETRICS SECTION
                  if (box.get("biometrics", defaultValue: false))
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: CupertinoButton(
                        onPressed: _handleBiometricAuth,
                        child: Column(
                          children: [
                            Icon(CupertinoIcons.lock_shield_fill, size: 40, color: primaryBlue.withOpacity(0.6)),
                            const SizedBox(height: 5),
                            Text("Use Biometrics", style: TextStyle(color: primaryBlue.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),

                  // RESET DATA LINK
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Text(
                      "Reset all data",
                      style: TextStyle(color: deepNavy.withOpacity(0.4), fontSize: 13, decoration: TextDecoration.underline),
                    ),
                    onPressed: () => _handleResetData(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- BUILDER FOR THE AESTHETIC INPUTS ---
  Widget _buildAestheticInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10, bottom: 8),
          child: Text(
            label,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0x66001D39), letterSpacing: 1.5),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: deepNavy.withOpacity(0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: CupertinoTextField(
            controller: controller,
            placeholder: "Enter your ${label.toLowerCase()}",
            placeholderStyle: TextStyle(color: deepNavy.withOpacity(0.2), fontSize: 14),
            obscureText: obscure,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            decoration: null,
            prefix: Padding(
              padding: const EdgeInsets.only(left: 20),
              child: Icon(icon, color: primaryBlue, size: 18),
            ),
            suffix: suffix,
          ),
        ),
      ],
    );
  }

  Future<void> _handleBiometricAuth() async {
    try {
      final bool didAuth = await auth.authenticate(
        localizedReason: 'Login to your Strivo account',
        // ignore: deprecated_member_use
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      if (didAuth) {
        if (!mounted) return;
        Navigator.pushReplacement(context, CupertinoPageRoute(builder: (context) => const Homepage()));
      }
    } catch (e) {
      setState(() => msg = "Biometric Error: $e");
    }
  }

  void _handleResetData(BuildContext context) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Reset all data?"),
        content: const Text("This will permanently delete your local account and activities."),
        actions: [
          CupertinoDialogAction(
            isDestructiveAction: true,
            child: const Text('Reset'),
            onPressed: () async {
              await box.clear();
              await Hive.box("activities").clear();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(CupertinoPageRoute(builder: (_) => const SignupPage()), (route) => false);
            },
          ),
          CupertinoDialogAction(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
        ],
      ),
    );
  }
}