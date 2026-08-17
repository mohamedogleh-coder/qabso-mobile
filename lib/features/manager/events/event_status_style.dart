import 'package:flutter/material.dart';

import '../../../utill/app_constants.dart';
import 'time_slots_model.dart';

/// How each booking state is named and coloured, kept in one place so the
/// history card, the details sheet and anything else that shows a booking
/// always agree.
extension EventStatusStyle on EventStatus {
  String get label => switch (this) {
    EventStatus.available => "Open",
    EventStatus.pending => "Half paid",
    EventStatus.confirmed => "Booked",
    EventStatus.completed => "Played",
    EventStatus.cancelled => "Cancelled",
  };

  Color get color => switch (this) {
    EventStatus.available => AppConstants.secondary,
    EventStatus.pending => AppConstants.warning,
    EventStatus.confirmed => AppConstants.primary,
    EventStatus.completed => AppConstants.tertiary,
    EventStatus.cancelled => AppConstants.error,
  };
}
