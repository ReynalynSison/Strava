import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:local_auth/local_auth.dart';

import 'homepage.dart';
import 'signup.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox("database");
  await Hive.openBox("activities");
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _State();
}

class _State extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    final box = Hive.box("database");

    // ValueListenableBuilder rebuilds the entire app when any Hive key changes,
    // which includes the "darkMode" toggle set from Settings.
    return ValueListenableBuilder(
      valueListenable: box.listenable(),
      builder: (context, Box db, _) {
        final isDark = db.get("darkMode", defaultValue: false) as bool;
        return CupertinoApp(
          theme: CupertinoThemeData(
            brightness: isDark ? Brightness.dark : Brightness.light,
          ),
          debugShowCheckedModeBanner: false,
          home: db.get("username") != null
              ? const LoginPage()
              : const SignupPage(),
        );
      },
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
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Login", style: TextStyle(fontSize: 30, fontWeight: FontWeight.w200)),
              const SizedBox(height: 10),
              CupertinoTextField(
                controller: _username,
                placeholder: "Username",
                autofillHints: const [],
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(CupertinoIcons.person),
                ),
                padding: const EdgeInsets.all(10),
              ),
              const SizedBox(height: 5),
              CupertinoTextField(
                controller: _password,
                placeholder: "Password",
                autofillHints: const [],
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 8.0),
                  child: Icon(CupertinoIcons.padlock),
                ),
                padding: const EdgeInsets.all(10),
                obscureText: hidePassword,
                suffix: CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Icon(hidePassword ? CupertinoIcons.eye : CupertinoIcons.eye_slash),
                    onPressed: () => setState(() => hidePassword = !hidePassword)),
              ),
              Center(
                child: Column(
                  children: [
                    CupertinoButton(
                        child: const Text('Sign In'),
                        onPressed: () {
                          if (_username.text.trim() == box.get("username") &&
                              _password.text.trim() == box.get("password")) {
                            Navigator.pushReplacement(context, CupertinoPageRoute(builder: (context) => const Homepage()));
                          } else {
                            setState(() => msg = "Invalid Username or Password");
                          }
                        }),

                    if (box.get("biometrics", defaultValue: false))
                      CupertinoButton(
                        child: const Icon(CupertinoIcons.lock_shield_fill, size: 50),
                        onPressed: () async {
                          try {
                            // In v3.0.0, use 'biometricOnly' and 'persistAcrossBackgrounding' directly
                            final bool didAuthenticate = await auth.authenticate(
                              localizedReason: 'Login to your account',
                              // ignore: deprecated_member_use
                              biometricOnly: true,
                              // replaces stickyAuth in v3.0.0
                              persistAcrossBackgrounding: true,
                            );

                            if (didAuthenticate) {
                              Navigator.pushReplacement(context, CupertinoPageRoute(builder: (context) => const Homepage()));
                            }
                          } catch (e) {
                            setState(() => msg = "Auth Error: $e");
                          }
                        },
                      ),

                    CupertinoButton(
                        child: const Text('Reset Data', style: TextStyle(color: CupertinoColors.destructiveRed)),
                        onPressed: () {
                          showCupertinoDialog(
                              context: context,
                              builder: (context) => CupertinoAlertDialog(
                                title: const Text("Delete all local data?"),
                                content: const Text("Authenticate with Face ID / biometrics to continue."),
                                actions: [
                                  CupertinoButton(
                                      child: const Text('Yes'),
                                      onPressed: () async {
                                        try {
                                          final bool didAuthenticate = await auth.authenticate(
                                            localizedReason: 'Authenticate to reset app data',
                                            // ignore: deprecated_member_use
                                            biometricOnly: true,
                                            persistAcrossBackgrounding: true,
                                          );

                                          if (!mounted) return;

                                          if (didAuthenticate) {
                                            await box.clear();
                                            if (!mounted) return;
                                            Navigator.pushReplacement(context, CupertinoPageRoute(builder: (context) => const SignupPage()));
                                          } else {
                                            Navigator.pop(context);
                                            setState(() => msg = 'Authentication required to reset data');
                                          }
                                        } catch (e) {
                                          if (!mounted) return;
                                          Navigator.pop(context);
                                          setState(() => msg = 'Auth Error: $e');
                                        }
                                      }),
                                  CupertinoButton(
                                      child: const Text('No'),
                                      onPressed: () => Navigator.pop(context)),
                                ],
                              ));
                        }),
                    const SizedBox(height: 10),
                    Text(msg, style: const TextStyle(color: CupertinoColors.destructiveRed), textAlign: TextAlign.center,)
                  ],
                ),
              )
            ],
          ),
        ));
  }
}