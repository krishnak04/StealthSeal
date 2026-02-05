import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';

class LocationLockService {
  static final _box = Hive.box('securityBox');

  /// Save trusted location
  static void setTrustedLocation({
    required double latitude,
    required double longitude,
    double radius = 200, // meters
  }) {
    _box.put('locationLockEnabled', true);
    _box.put('trustedLat', latitude);
    _box.put('trustedLng', longitude);
    _box.put('trustedRadius', radius);
  }

  static void disable() {
    _box.put('locationLockEnabled', false);
  }

  static bool isEnabled() {
    return _box.get('locationLockEnabled', defaultValue: false);
  }

  /// Check if user is outside trusted location
  static Future<bool> isOutsideTrustedLocation() async {
    if (!isEnabled()) return false;

    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return true;

    LocationPermission permission =
        await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return true;
    }

    final current = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final trustedLat = _box.get('trustedLat');
    final trustedLng = _box.get('trustedLng');
    final radius = _box.get('trustedRadius', defaultValue: 200);

    final distance = Geolocator.distanceBetween(
      current.latitude,
      current.longitude,
      trustedLat,
      trustedLng,
    );

    return distance > radius;
  }
}
