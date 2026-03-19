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
      desiredAccuracy: LocationAccuracy.bestForNavigation,
    );
  }

  /// Opens the device location settings screen.
  Future<bool> openLocationSettings() {
    return Geolocator.openLocationSettings();
  }

  /// Returns a stream of position updates for real-time tracking.
  /// Position updates every 2 meters of movement to filter GPS jitter.
  /// Accepts readings up to 25m accuracy for good balance between responsiveness and noise filtering.
  Stream<Position> getPositionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 2, // Update every 2 meters to reduce GPS jitter
      ),
    ).where((pos) => pos.accuracy <= 25.0); // Accept up to 25m accuracy, stricter for stationary detection
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