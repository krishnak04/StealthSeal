import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';

/// Enforces location-based locking by comparing the user's current
/// position against a trusted location stored in Hive.
///
/// When the user is outside the trusted radius, only the real PIN
/// can unlock the app.
class LocationLockService {
  /// Hive box used for persisting security-related state.
  static final _securityBox = Hive.box('securityBox');

  // ──────────────────────────────────────────────
  //  Configuration
  // ──────────────────────────────────────────────

  /// Saves a trusted location with the given coordinates and radius.
  ///
  /// [radius] is specified in meters (default: 200 m).
  static void setTrustedLocation({
    required double latitude,
    required double longitude,
    double radius = 200, // meters
  }) {
    _securityBox.put('locationLockEnabled', true);
    _securityBox.put('trustedLat', latitude);
    _securityBox.put('trustedLng', longitude);
    _securityBox.put('trustedRadius', radius);
  }

  /// Disables the location lock.
  static void disable() {
    _securityBox.put('locationLockEnabled', false);
  }

  /// Returns `true` if the location lock feature is enabled.
  static bool isEnabled() {
    return _securityBox.get('locationLockEnabled', defaultValue: false);
  }

  // ──────────────────────────────────────────────
  //  Location Verification
  // ──────────────────────────────────────────────

  /// Returns `true` if the user is currently outside the trusted zone.
  ///
  /// Checks location services, permissions, and then computes the
  /// distance between the current position and the trusted coordinates.
  /// Returns `true` (locked) if permissions are denied or location
  /// services are disabled.
  static Future<bool> isOutsideTrustedLocation() async {
    if (!isEnabled()) return false;

    final isServiceEnabled =
        await Geolocator.isLocationServiceEnabled();
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
