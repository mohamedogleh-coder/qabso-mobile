import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AppDateUtil {
  AppDateUtil._();

  static String formatDate(DateTime date, {String pattern = 'yyyy-MM-dd'}) {
    return DateFormat(pattern).format(date);
  }

  static String formatReadableDate(DateTime date) {
    return DateFormat('EEEE, dd MMM yyyy').format(date);
  }

  static String formatDateTime(DateTime date) {
    return DateFormat('yyyy-MM-dd HH:mm').format(date);
  }

  static String formatTime(DateTime date) {
    return DateFormat('HH:mm').format(date);
  }

  static String formatTimeOfTheDayTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';

    return '$hour:$minute $period';
  }

  /// Renders [time] as zero-padded 24-hour `HH:mm` — the form stored in
  /// Postgres `time` columns, unlike the 12-hour
  /// [formatTimeOfTheDayTime] used for display.
  static String formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  /// Parses `HH:mm` (or `HH:mm:ss` — seconds ignored) back into a
  /// [TimeOfDay]. Returns `null` for anything unparseable so callers can
  /// fall back to a default instead of handling an exception.
  static TimeOfDay? parseTimeOfDay(String? value) {
    if (value == null) return null;

    final parts = value.trim().split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    return TimeOfDay(hour: hour, minute: minute);
  }

  static String formatSlot(DateTime start, DateTime end) {
    final startTime = DateFormat('HH:mm').format(start);
    final endTime = DateFormat('HH:mm').format(end);

    return '$startTime - $endTime';
  }
}
