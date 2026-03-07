import 'package:uuid/uuid.dart';

/// Represents a single recorded running activity.
/// Stored in Hive box "activities" as JSON via [toJson] / [fromJson].
class ActivityModel {
  final String id;

  /// Total distance in meters.
  final double distance;

  /// Total elapsed time in seconds.
  final int durationSeconds;

  /// Pace in minutes per kilometer.
  final double pace;

  /// Date and time the activity was recorded.
  final DateTime date;

  /// GPS coordinates recorded during the run.
  /// Each point is stored as {"lat": double, "lng": double}.
  final List<Map<String, double>> routeCoordinates;

  ActivityModel({
    String? id,
    required this.distance,
    required this.durationSeconds,
    required this.pace,
    required this.date,
    required this.routeCoordinates,
  }) : id = id ?? const Uuid().v4();

  // ─── Serialization ────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'distance': distance,
      'durationSeconds': durationSeconds,
      'pace': pace,
      'date': date.toIso8601String(),
      'routeCoordinates': routeCoordinates,
    };
  }

  factory ActivityModel.fromJson(Map<String, dynamic> json) {
    // routeCoordinates stored as List<dynamic> in Hive — cast safely
    final rawCoords = json['routeCoordinates'] as List<dynamic>;
    final coords = rawCoords.map((point) {
      final p = Map<String, dynamic>.from(point as Map);
      return {
        'lat': (p['lat'] as num).toDouble(),
        'lng': (p['lng'] as num).toDouble(),
      };
    }).toList();

    return ActivityModel(
      id: json['id'] as String,
      distance: (json['distance'] as num).toDouble(),
      durationSeconds: json['durationSeconds'] as int,
      pace: (json['pace'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
      routeCoordinates: coords,
    );
  }

  // ─── Utility ──────────────────────────────────────────────────────────────

  ActivityModel copyWith({
    String? id,
    double? distance,
    int? durationSeconds,
    double? pace,
    DateTime? date,
    List<Map<String, double>>? routeCoordinates,
  }) {
    return ActivityModel(
      id: id ?? this.id,
      distance: distance ?? this.distance,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      pace: pace ?? this.pace,
      date: date ?? this.date,
      routeCoordinates: routeCoordinates ?? this.routeCoordinates,
    );
  }

  @override
  String toString() {
    return 'ActivityModel(id: $id, distance: ${distance.toStringAsFixed(1)}m, '
        'duration: ${durationSeconds}s, pace: ${pace.toStringAsFixed(2)} min/km, '
        'date: $date, points: ${routeCoordinates.length})';
  }
}

