import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';

class LocationLockService {
  static final _securityBox = Hive.box('securityBox');

  static void setTrustedLocation({
    required double latitude,
    required double longitude,
    double radius = 200,
  }) {
    _securityBox.put('locationLockEnabled', true);
    _securityBox.put('trustedLat', latitude);
    _securityBox.put('trustedLng', longitude);
    _securityBox.put('trustedRadius', radius);
  }

  static void disable() {
    _securityBox.put('locationLockEnabled', false);
  }

  static bool isEnabled() {
    return _securityBox.get('locationLockEnabled', defaultValue: false);
  }

  static Future<bool> isOutsideTrustedLocation() async {
    if (!isEnabled()) return false;

    final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isServiceEnabled) return true;

    LocationPermission permission =
        await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return true;
    }

    final currentPosition = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final trustedLat = _securityBox.get('trustedLat');
    final trustedLng = _securityBox.get('trustedLng');
    final trustedRadius =
        _securityBox.get('trustedRadius', defaultValue: 200);

    final distanceInMeters = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      trustedLat,
      trustedLng,
    );

    return distanceInMeters > trustedRadius;
  }
}
