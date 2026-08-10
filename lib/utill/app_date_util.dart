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

  static String formatSlot(DateTime start, DateTime end) {
    final startTime = DateFormat('HH:mm').format(start);
    final endTime = DateFormat('HH:mm').format(end);

    return '$startTime - $endTime';
  }
}
