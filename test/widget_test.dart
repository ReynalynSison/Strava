import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import 'package:faceid/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('strava_test_');
    Hive.init(tempDir.path);
    await Hive.openBox('database');
    await Hive.openBox('activities');
  });

  tearDown(() async {
    await Hive.box('database').clear();
    await Hive.box('activities').clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  testWidgets('app boots to signup when there is no local account',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    expect(find.text('Create A local Account'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
  });
}
