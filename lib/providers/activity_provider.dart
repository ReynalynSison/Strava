import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/activity_model.dart';
import '../services/storage_service.dart';

class MotivationSummary {
  final ActivityModel? longestRun;
  final ActivityModel? bestPaceRun;
  final int currentStreakDays;

  const MotivationSummary({
    required this.longestRun,
    required this.bestPaceRun,
    required this.currentStreakDays,
  });

  bool get hasAnyAchievement =>
      longestRun != null || bestPaceRun != null || currentStreakDays > 0;
}

class ActivityState {
  final List<ActivityModel> activities;
  final bool isLoading;

  const ActivityState({
    required this.activities,
    required this.isLoading,
  });

  const ActivityState.initial()
      : activities = const [],
        isLoading = true;

  ActivityState copyWith({
    List<ActivityModel>? activities,
    bool? isLoading,
  }) {
    return ActivityState(
      activities: activities ?? this.activities,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ActivityNotifier extends StateNotifier<ActivityState> {
  final StorageService _storage;
  late final ValueListenable<Box> _listenable;

  ActivityNotifier(this._storage) : super(const ActivityState.initial()) {
    _listenable = Hive.box('activities').listenable();
    _listenable.addListener(_syncFromStorage);
    loadActivities();
  }

  Future<void> _syncFromStorage() async {
    final activities = await _storage.loadAllActivities();
    state = state.copyWith(activities: activities, isLoading: false);
  }

  Future<void> loadActivities() async {
    state = state.copyWith(isLoading: true);
    final activities = await _storage.loadAllActivities();
    state = state.copyWith(activities: activities, isLoading: false);
  }

  Future<void> addActivity(ActivityModel activity) async {
    await _storage.saveActivity(activity);
    await _syncFromStorage();
  }

  Future<void> deleteActivity(String id) async {
    await _storage.deleteActivity(id);
    await _syncFromStorage();
  }

  Future<void> clearActivities() async {
    await _storage.clearAllActivities();
    await _syncFromStorage();
  }

  @override
  void dispose() {
    _listenable.removeListener(_syncFromStorage);
    super.dispose();
  }
}

final activityProvider =
    StateNotifierProvider<ActivityNotifier, ActivityState>((ref) {
  return ActivityNotifier(StorageService());
});

final motivationSummaryProvider = Provider<MotivationSummary>((ref) {
  final activities = ref.watch(activityProvider.select((state) => state.activities));

  ActivityModel? longestRun;
  for (final activity in activities) {
    if (longestRun == null || activity.distance > longestRun.distance) {
      longestRun = activity;
    }
  }

  const minDistanceMetersForPacePb = 1000.0;
  final validPaceRuns = activities.where((activity) {
    return activity.distance >= minDistanceMetersForPacePb &&
        activity.durationSeconds > 0 &&
        activity.pace > 0 &&
        activity.pace.isFinite;
  });

  ActivityModel? bestPaceRun;
  for (final activity in validPaceRuns) {
    if (bestPaceRun == null || activity.pace < bestPaceRun.pace) {
      bestPaceRun = activity;
    }
  }

  final activeDays = activities
      .map((activity) => DateTime(activity.date.year, activity.date.month, activity.date.day))
      .toSet();

  final today = DateTime.now();
  final normalizedToday = DateTime(today.year, today.month, today.day);
  final normalizedYesterday = normalizedToday.subtract(const Duration(days: 1));

  DateTime? cursor;
  if (activeDays.contains(normalizedToday)) {
    cursor = normalizedToday;
  } else if (activeDays.contains(normalizedYesterday)) {
    cursor = normalizedYesterday;
  }

  var streak = 0;
  while (cursor != null && activeDays.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return MotivationSummary(
    longestRun: longestRun,
    bestPaceRun: bestPaceRun,
    currentStreakDays: streak,
  );
});


