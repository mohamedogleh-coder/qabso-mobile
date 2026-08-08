import 'package:geolocator/geolocator.dart';

/// Thrown when the user has denied location permission (but not permanently).
class LocationPermissionDeniedException implements Exception {
  const LocationPermissionDeniedException();

  @override
  String toString() => 'Location permission was denied.';
}

/// Thrown when the user has permanently denied location permission.
///
/// The only way to recover from this state is for the user to grant the
/// permission from the device settings, see [AppUtilityService.openAppSettings].
class LocationPermissionPermanentlyDeniedException implements Exception {
  const LocationPermissionPermanentlyDeniedException();

  @override
  String toString() => 'Location permission is permanently denied.';
}

/// Thrown when the device's location service (GPS) is turned off.
class LocationServiceDisabledException implements Exception {
  const LocationServiceDisabledException();

  @override
  String toString() => 'Location services are disabled.';
}

abstract class AppUtilityService {
  static Future<bool> isLocationServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  static Future<LocationPermission> checkLocationPermission() {
    return Geolocator.checkPermission();
  }

  static Future<LocationPermission> requestLocationPermission() {
    return Geolocator.requestPermission();
  }

  static Future<Position> getCurrentLocation() async {
    if (!await isLocationServiceEnabled()) {
      throw const LocationServiceDisabledException();
    }

    LocationPermission permission = await checkLocationPermission();
    if (permission == LocationPermission.denied) {
      permission = await requestLocationPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationPermissionDeniedException();
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermissionPermanentlyDeniedException();
    }

    return Geolocator.getCurrentPosition();
  }

  static Future<bool> openAppSettings() {
    return Geolocator.openAppSettings();
  }

  static Future<bool> openLocationServiceSettings() {
    return Geolocator.openLocationSettings();
  }
}
