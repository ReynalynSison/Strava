import 'package:hive_flutter/hive_flutter.dart';
import '../models/activity_model.dart';

/// Handles all persistence of [ActivityModel] objects in the Hive "activities" box.
/// The box is opened at app startup in main.dart.
/// 
/// IMPORTANT: Route coordinates are stored as raw GPS points (lat/lng) to preserve
/// accurate visualization. No filtering or smoothing is applied during save/load
/// to maintain 1:1 correspondence with live tracking display.
class StorageService {
  static const String _boxName = 'activities';

  Box get _box => Hive.box(_boxName);

  // ─── Save ──────────────────────────────────────────────────────────────────

  /// Saves an activity to Hive. Uses activity.id as the key.
  /// 
  /// Coordinates are saved as-is without modification to preserve accuracy.
  Future<void> saveActivity(ActivityModel activity) async {
    // Validate coordinates before saving
    final validCoordinates = _validateCoordinates(activity.routeCoordinates);
    
    final json = activity.toJson();
    json['routeCoordinates'] = validCoordinates;
    
    await _box.put(activity.id, json);
  }

  // ─── Load All ─────────────────────────────────────────────────────────────

  /// Loads all activities, sorted newest first.
  /// 
  /// Validates coordinates during load to ensure data integrity.
  Future<List<ActivityModel>> loadAllActivities() async {
    final List<ActivityModel> activities = [];

    for (final key in _box.keys) {
      final data = _box.get(key);
      if (data == null) continue;
      try {
        final json = Map<String, dynamic>.from(data as Map);
        
        // Validate coordinates before creating model
        if (json['routeCoordinates'] != null) {
          json['routeCoordinates'] = _validateCoordinates(
            (json['routeCoordinates'] as List)
                .map((p) => Map<String, dynamic>.from(p as Map))
                .toList(),
          );
        }
        
        activities.add(ActivityModel.fromJson(json));
      } catch (e) {
        // Skip any corrupted entries silently
        print('Failed to load activity $key: $e');
      }
    }

    // Newest first
    activities.sort((a, b) => b.date.compareTo(a.date));
    return activities;
  }

  // ─── Load Single ──────────────────────────────────────────────────────────

  /// Loads a single activity by its ID. Returns null if not found.
  /// 
  /// Validates coordinates during load to ensure data integrity.
  Future<ActivityModel?> loadActivity(String id) async {
    final data = _box.get(id);
    if (data == null) return null;
    try {
      final json = Map<String, dynamic>.from(data as Map);
      
      // Validate coordinates before creating model
      if (json['routeCoordinates'] != null) {
        json['routeCoordinates'] = _validateCoordinates(
          (json['routeCoordinates'] as List)
              .map((p) => Map<String, dynamic>.from(p as Map))
              .toList(),
        );
      }
      
      return ActivityModel.fromJson(json);
    } catch (e) {
      print('Failed to load activity $id: $e');
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

  // ─── Validation ───────────────────────────────────────────────────────────

  /// Validates route coordinates to ensure they have required lat/lng fields.
  /// 
  /// Fixes any missing or swapped coordinates.
  List<Map<String, double>> _validateCoordinates(
    List<dynamic> rawCoordinates,
  ) {
    final List<Map<String, double>> validated = [];

    for (final item in rawCoordinates) {
      try {
        final coord = Map<String, dynamic>.from(item as Map);
        
        // Check if lat/lng are present (not swapped)
        if (!coord.containsKey('lat') || !coord.containsKey('lng')) {
          // Try to auto-fix swapped coordinates
          if (coord.containsKey('lng') && coord.containsKey('lat')) {
            // Already has lat/lng, skip
          } else if (coord.containsKey('latitude') && coord.containsKey('longitude')) {
            // Swapped naming, fix it
            coord['lat'] = coord.remove('latitude');
            coord['lng'] = coord.remove('longitude');
          } else {
            // Invalid, skip this point
            continue;
          }
        }
        
        // Convert to double
        final lat = (coord['lat'] as num).toDouble();
        final lng = (coord['lng'] as num).toDouble();
        
        // Validate lat/lng are within valid ranges
        if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
          print('Invalid coordinates: lat=$lat, lng=$lng (skipped)');
          continue;
        }
        
        validated.add({'lat': lat, 'lng': lng});
      } catch (e) {
        print('Failed to validate coordinate: $e (skipped)');
        continue;
      }
    }

    return validated;
  }
}

