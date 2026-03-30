import 'package:geolocator/geolocator.dart';
import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';

class LocationLockService {
  static final _securityBox = Hive.box('securityBox');

  static void setTrustedLocation({
    required double latitude,
    required double longitude,
    double radius = 200,
  }) {
    debugPrint('📍 LocationLockService: Setting trusted location');
    debugPrint('   Latitude: $latitude, Longitude: $longitude, Radius: $radius meters');
    
    _securityBox.put('locationLockEnabled', true);
    _securityBox.put('trustedLat', latitude);
    _securityBox.put('trustedLng', longitude);
    _securityBox.put('trustedRadius', radius);
    
    debugPrint('✅ Trusted location saved to Hive');
  }

  static void disable() {
    debugPrint('📍 LocationLockService: Disabling location lock');
    _securityBox.put('locationLockEnabled', false);
  }

  static bool isEnabled() {
    final enabled = _securityBox.get('locationLockEnabled', defaultValue: false);
    debugPrint('📍 LocationLockService.isEnabled(): $enabled');
    return enabled;
  }

  static bool isTrustedLocationConfigured() {
    final trustedLat = _securityBox.get('trustedLat');
    final trustedLng = _securityBox.get('trustedLng');
    final configured = trustedLat != null && trustedLng != null;
    debugPrint('📍 LocationLockService: Trusted location configured: $configured');
    return configured;
  }

  static Future<bool> isOutsideTrustedLocation() async {
    if (!isEnabled()) {
      debugPrint('📍 Location lock is DISABLED - returning false');
      return false;
    }

    if (!isTrustedLocationConfigured()) {
      debugPrint('⚠️  Trusted location NOT configured - allowing access');
      return false;
    }

    final isServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isServiceEnabled) {
      debugPrint('⚠️  Location service DISABLED on device - blocking access');
      return true;
    }

    LocationPermission permission =
        await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      debugPrint('⚠️  Location permission DENIED - blocking access');
      return true;
    }

    try {
      final currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final trustedLat = _securityBox.get('trustedLat', defaultValue: 0.0) as double;
      final trustedLng = _securityBox.get('trustedLng', defaultValue: 0.0) as double;
      final trustedRadius =
          _securityBox.get('trustedRadius', defaultValue: 200.0) as double;

      debugPrint('📍 Current position: ${currentPosition.latitude}, ${currentPosition.longitude}');
      debugPrint('📍 Trusted location: $trustedLat, $trustedLng');
      debugPrint('📍 Trusted radius: $trustedRadius meters');

      final distanceInMeters = Geolocator.distanceBetween(
        currentPosition.latitude,
        currentPosition.longitude,
        trustedLat,
        trustedLng,
      );

      debugPrint('📍 Distance: $distanceInMeters meters');

      final isOutside = distanceInMeters > trustedRadius;
      debugPrint('📍 Is outside trusted location: $isOutside');
      
      return isOutside;
    } catch (e) {
      debugPrint('❌ Error calculating distance: $e');
      
      return false;
    }
  }
}
