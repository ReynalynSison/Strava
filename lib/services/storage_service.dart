import 'package:hive_flutter/hive_flutter.dart';
import '../models/activity_model.dart';

/// Handles all persistence of [ActivityModel] objects in the Hive "activities" box.
/// The box is opened at app startup in main.dart.
class StorageService {
  static const String _boxName = 'activities';

  Box get _box => Hive.box(_boxName);

  // ─── Save ──────────────────────────────────────────────────────────────────

  /// Saves an activity to Hive. Uses activity.id as the key.
  Future<void> saveActivity(ActivityModel activity) async {
    await _box.put(activity.id, activity.toJson());
  }

  // ─── Load All ─────────────────────────────────────────────────────────────

  /// Loads all activities, sorted newest first.
  Future<List<ActivityModel>> loadAllActivities() async {
    final List<ActivityModel> activities = [];

    for (final key in _box.keys) {
      final data = _box.get(key);
      if (data == null) continue;
      try {
        activities.add(
          ActivityModel.fromJson(Map<String, dynamic>.from(data as Map)),
        );
      } catch (_) {
        // Skip any corrupted entries silently
      }
    }

    // Newest first
    activities.sort((a, b) => b.date.compareTo(a.date));
    return activities;
  }

  // ─── Load Single ──────────────────────────────────────────────────────────

  /// Loads a single activity by its ID. Returns null if not found.
  Future<ActivityModel?> loadActivity(String id) async {
    final data = _box.get(id);
    if (data == null) return null;
    try {
      return ActivityModel.fromJson(Map<String, dynamic>.from(data as Map));
    } catch (_) {
      return null;
    }
  }

  // ─── Delete ───────────────────────────────────────────────────────────────

  /// Deletes a single activity by its ID.
  Future<void> deleteActivity(String id) async {
    await _box.delete(id);
  }

  // ─── Clear All ────────────────────────────────────────────────────────────

  /// Deletes all saved activities. Used in Phase 13 Settings.
  Future<void> clearAllActivities() async {
    await _box.clear();
  }
}

