import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class AppSettingsState {
  final String username;
  final bool darkMode;
  final bool useMetric;
  final bool biometrics;
  final bool runNotificationsEnabled;

  const AppSettingsState({
    required this.username,
    required this.darkMode,
    required this.useMetric,
    required this.biometrics,
    required this.runNotificationsEnabled,
  });

  bool get hasAccount => username.trim().isNotEmpty;

  AppSettingsState copyWith({
    String? username,
    bool? darkMode,
    bool? useMetric,
    bool? biometrics,
    bool? runNotificationsEnabled,
  }) {
    return AppSettingsState(
      username: username ?? this.username,
      darkMode: darkMode ?? this.darkMode,
      useMetric: useMetric ?? this.useMetric,
      biometrics: biometrics ?? this.biometrics,
      runNotificationsEnabled:
          runNotificationsEnabled ?? this.runNotificationsEnabled,
    );
  }

  static AppSettingsState fromBox(Box box) {
    return AppSettingsState(
      username: (box.get('username', defaultValue: '') as String?) ?? '',
      darkMode: box.get('darkMode', defaultValue: false) as bool,
      useMetric: box.get('useMetric', defaultValue: true) as bool,
      biometrics: box.get('biometrics', defaultValue: false) as bool,
      runNotificationsEnabled:
          box.get('runNotificationsEnabled', defaultValue: true) as bool,
    );
  }
}

class AppSettingsNotifier extends StateNotifier<AppSettingsState> {
  final Box _box;
  late final ValueListenable<Box> _listenable;

  AppSettingsNotifier(this._box) : super(AppSettingsState.fromBox(_box)) {
    _listenable = _box.listenable(
      keys: const [
        'username',
        'darkMode',
        'useMetric',
        'biometrics',
        'runNotificationsEnabled',
      ],
    );
    _listenable.addListener(_syncFromHive);
  }

  void _syncFromHive() {
    state = AppSettingsState.fromBox(_box);
  }

  Future<void> toggleDarkMode(bool value) async {
    await _box.put('darkMode', value);
    state = state.copyWith(darkMode: value);
  }

  Future<void> toggleUnits(bool value) async {
    await _box.put('useMetric', value);
    state = state.copyWith(useMetric: value);
  }

  Future<void> toggleBiometrics(bool value) async {
    await _box.put('biometrics', value);
    state = state.copyWith(biometrics: value);
  }

  Future<void> toggleRunNotifications(bool value) async {
    await _box.put('runNotificationsEnabled', value);
    state = state.copyWith(runNotificationsEnabled: value);
  }

  Future<void> setUsername(String value) async {
    await _box.put('username', value);
    state = state.copyWith(username: value);
  }

  @override
  void dispose() {
    _listenable.removeListener(_syncFromHive);
    super.dispose();
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsNotifier, AppSettingsState>((ref) {
  final box = Hive.box('database');
  return AppSettingsNotifier(box);
});
