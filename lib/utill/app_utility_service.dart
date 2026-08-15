import 'package:flutter/material.dart';
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

  // ---------------------------------------------------------------------
  // Date / time pickers
  // ---------------------------------------------------------------------

  /// Shows the app's time picker and resolves with the picked time, or
  /// `null` if the user cancelled.
  ///
  /// [use24HourFormat] forces the 24-hour dial regardless of device locale;
  /// pass `false` to follow the device instead.
  static Future<TimeOfDay?> pickTime({
    required BuildContext context,
    TimeOfDay? initialTime,
    String? helpText,
    bool use24HourFormat = true,
    TimePickerEntryMode initialEntryMode = TimePickerEntryMode.dial,
  }) {
     return showTimePicker(
      context: context,
      initialTime: initialTime ?? TimeOfDay.now(),
      helpText: helpText,
      initialEntryMode: initialEntryMode,
      builder: (pickerContext, child) => _pickerTheme(
        context: pickerContext,
        child: child,
        use24HourFormat: use24HourFormat,
      ),
    );
  }

  /// Shows the app's date picker and resolves with the picked date, or
  /// `null` if the user cancelled. [firstDate] and [lastDate] default to a
  /// five-year window either side of today.
  static Future<DateTime?> pickDate({
    required BuildContext context,
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
    String? helpText,
  }) {
    final now = DateTime.now();

    return showDatePicker(
      context: context,
      initialDate: initialDate ?? now,
      firstDate: firstDate ?? DateTime(now.year - 5),
      lastDate: lastDate ?? DateTime(now.year + 5),
      helpText: helpText,
      builder: (pickerContext, child) =>
          _pickerTheme(context: pickerContext, child: child),
    );
  }

  /// Keeps both pickers on the app's own surface, shape, and colors instead
  /// of Material's defaults, so they read as part of the app in either
  /// theme.
  static Widget _pickerTheme({
    required BuildContext context,
    required Widget? child,
    bool use24HourFormat = false,
  }) {
    final theme = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
    );

    final themed = Theme(
      data: theme.copyWith(
        timePickerTheme: TimePickerThemeData(
          shape: shape,
          backgroundColor: theme.colorScheme.surface,
          hourMinuteTextColor: theme.colorScheme.primary,
          dialHandColor: theme.colorScheme.primary,
          helpTextStyle: theme.textTheme.headlineMedium,
        ),
        datePickerTheme: DatePickerThemeData(
          shape: shape,
          backgroundColor: theme.colorScheme.surface,
          headerHelpStyle: theme.textTheme.headlineMedium,
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );

    if (!use24HourFormat) return themed;

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: themed,
    );
  }
}
