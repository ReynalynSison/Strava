import 'package:geolocator/geolocator.dart';

/// Handles GPS location permissions and coordinate tracking.
class LocationService {
  /// Requests location permission from the user.
  /// Returns true if permission is granted (always or whileInUse).
  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Gets the user's current GPS position.
  Future<Position> getCurrentLocation() async {
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  /// Returns a stream of position updates for real-time tracking.
  /// Position updates every ~10 meters of movement.
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    );
  }

  /// Calculates the total distance in meters from a list of GPS coordinates.
  /// Uses the Haversine formula via Geolocator.distanceBetween.
  double calculateDistance(List<Map<String, double>> coordinates) {
    if (coordinates.length < 2) return 0.0;

    double totalDistance = 0.0;
    for (int i = 0; i < coordinates.length - 1; i++) {
      final lat1 = coordinates[i]['lat']!;
      final lng1 = coordinates[i]['lng']!;
      final lat2 = coordinates[i + 1]['lat']!;
      final lng2 = coordinates[i + 1]['lng']!;

      totalDistance += Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
    }

    return totalDistance;
  }
}


