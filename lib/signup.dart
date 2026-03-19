import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'; // Required for modern Shadows and Gradients
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'providers/app_settings_provider.dart';
import 'main.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final box = Hive.box("database");
  bool hidePassword = true;
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();

  // --- Strivo Aesthetic Palette ---
  final Color deepNavy = const Color(0xFF001D39);   // Oxford Blue
  final Color primaryBlue = const Color(0xFF0A4174); // Accent Blue
  final Color skyBlue = const Color(0xFF7BBDE8);    // Jordy Blue (Glow color)
  final Color ultraLightBlue = const Color(0xFFF0F5F9); // Mas malinis na background

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: ultraLightBlue,
      child: SingleChildScrollView(
        child: Column(
          children: [
            // --- PREMIUM GRADIENT HEADER ---
            Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.45,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [deepNavy, primaryBlue, const Color(0xFF1E5BB0)],
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
                  // Animated-style Icon with Glow
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
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            CupertinoIcons.bolt_fill,
                            size: 45,
                            color: Colors.white,
                          ),
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
                  Text(
                    "TRACING EVERY STEP",
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Create Account",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF001D39),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Start your journey with us today.",
                    style: TextStyle(
                      fontSize: 14,
                      color: deepNavy.withOpacity(0.5),
                    ),
                  ),
                  const SizedBox(height: 35),

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
                  const SizedBox(height: 45),

                  // GRADIENT ACTION BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 65,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: LinearGradient(
                          colors: [primaryBlue, const Color(0xFF1E5BB0)],
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
                          "GET STARTED",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            fontSize: 16,
                          ),
                        ),
                        onPressed: () async {
                          if (_username.text.trim().isEmpty || _password.text.trim().isEmpty) return;

                          await box.put("username", _username.text.trim());
                          await box.put("password", _password.text.trim());
                          await box.put("biometrics", false);

                          ref.invalidate(appSettingsProvider);

                          if (!mounted) return;

                          Navigator.of(context).pushAndRemoveUntil(
                            CupertinoPageRoute(builder: (_) => const LoginPage()),
                                (route) => false,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // CUSTOM AESTHETIC INPUT BUILDER
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
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: deepNavy.withOpacity(0.4),
              letterSpacing: 1.5,
            ),
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
}