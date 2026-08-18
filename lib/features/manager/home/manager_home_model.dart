import '../events/time_slots_model.dart';

/// What the manager's home screen shows: today's games, what is still free to
/// sell, and whether anything is stopping the stadium taking bookings.
///
/// Read from `manager_home_fn`. Money the stadium has taken is deliberately
/// absent — that belongs to the reports.
class ManagerHomeModel {
  /// Games booked today, cancelled ones aside, and how many have been played.
  final int gamesToday;
  final int playedToday;

  /// Slots still free to sell before the stadium closes today.
  final int freeSlotsToday;

  /// What today's bookings are still owed.
  ///
  /// Null when the stadium sells whole slots only. Nothing can be outstanding
  /// then, so the screen leaves the whole part out rather than showing a zero
  /// that never moves.
  final double? remainingAmount;

  /// The game being played now, or the next one to come. All null once the
  /// day has nothing left in it.
  final int? nextEventId;
  final DateTime? nextEventStart;
  final DateTime? nextEventEnd;
  final int? nextFieldId;
  final EventStatus? nextEventStatus;

  /// What has to be true before a customer can book and pay. Each one that is
  /// false stops bookings on its own.
  final bool hasWorkingDays;
  final bool hasActiveMerchant;
  final bool hasBookableField;

  const ManagerHomeModel({
    required this.gamesToday,
    required this.playedToday,
    required this.freeSlotsToday,
    this.remainingAmount,
    this.nextEventId,
    this.nextEventStart,
    this.nextEventEnd,
    this.nextFieldId,
    this.nextEventStatus,
    required this.hasWorkingDays,
    required this.hasActiveMerchant,
    required this.hasBookableField,
  });

  factory ManagerHomeModel.fromJson(Map<String, dynamic> json) {
    return ManagerHomeModel(
      gamesToday: json['games_today'] as int,
      playedToday: json['played_today'] as int,
      freeSlotsToday: json['free_slots_today'] as int,
      remainingAmount: (json['remaining_amount'] as num?)?.toDouble(),
      nextEventId: json['next_event_id'] as int?,
      nextEventStart: json['next_event_start'] == null
          ? null
          : DateTime.parse(json['next_event_start'].toString()),
      nextEventEnd: json['next_event_end'] == null
          ? null
          : DateTime.parse(json['next_event_end'].toString()),
      nextFieldId: json['next_field_id'] as int?,
      nextEventStatus: json['next_event_status'] == null
          ? null
          : EventStatus.fromString(json['next_event_status'] as String),
      hasWorkingDays: json['has_working_days'] as bool,
      hasActiveMerchant: json['has_active_merchant'] as bool,
      hasBookableField: json['has_bookable_field'] as bool,
    );
  }

  /// The same day with some of its numbers changed.
  ///
  /// Only the counters can be changed here. The next game is left alone on
  /// purpose: which game comes next is a question about the whole day's
  /// bookings, and no sum on this model can answer it — the notifier reads it
  /// again instead.
  ///
  /// [remainingAmount] is passed as a function rather than a value so it can
  /// be set back to null, the way TimeSlotModel.copyWith takes its event key.
  /// A plain null there would mean "leave it alone" and there would be no way
  /// to say "there is nothing owed any more".
  ManagerHomeModel copyWith({
    int? gamesToday,
    int? playedToday,
    int? freeSlotsToday,
    double? Function()? remainingAmount,
  }) {
    return ManagerHomeModel(
      gamesToday: gamesToday ?? this.gamesToday,
      playedToday: playedToday ?? this.playedToday,
      freeSlotsToday: freeSlotsToday ?? this.freeSlotsToday,
      remainingAmount: remainingAmount != null
          ? remainingAmount()
          : this.remainingAmount,
      nextEventId: nextEventId,
      nextEventStart: nextEventStart,
      nextEventEnd: nextEventEnd,
      nextFieldId: nextFieldId,
      nextEventStatus: nextEventStatus,
      hasWorkingDays: hasWorkingDays,
      hasActiveMerchant: hasActiveMerchant,
      hasBookableField: hasBookableField,
    );
  }

  /// Games booked today that have not been played yet.
  int get upcomingToday => gamesToday - playedToday;

  bool get hasNextBooking => nextEventStart != null;

  /// Whether the next game has already started, so the screen can say it is
  /// being played now rather than calling it the next one.
  bool get isNextPlayingNow =>
      nextEventStart != null && nextEventStart!.isBefore(DateTime.now());

  /// Whether the stadium can take a booking at all. All three have to be true
  /// before a customer can book and pay.
  bool get canTakeBookings =>
      hasWorkingDays && hasActiveMerchant && hasBookableField;
}
