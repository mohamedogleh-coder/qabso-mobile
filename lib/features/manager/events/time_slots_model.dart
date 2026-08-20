import 'package:equatable/equatable.dart';

import '../../../utill/app_date_util.dart';

enum EventStatus {
  available,
  pending,
  confirmed,
  completed,
  cancelled;

  static EventStatus fromString(String value) {
    return EventStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => EventStatus.available,
    );
  }

  String get value => name;
}

class TimeSlotModel extends Equatable {
  final DateTime startTime;
  final DateTime endTime;
  final int? eventId;
  final String? eventKey;
  final EventStatus eventStatus;

  /// True when the signed-in customer paid for this booking.
  final bool isMine;

  /// The phone number of whoever paid, so the manager can call them back.
  final String? referenceNumber;

  const TimeSlotModel({
    required this.startTime,
    required this.endTime,
    this.eventId,
    this.eventKey,
    required this.eventStatus,
    this.isMine = false,
    this.referenceNumber,
  });

  factory TimeSlotModel.fromJson(Map<String, dynamic> json) {
    return TimeSlotModel(
      startTime: DateTime.parse(json['startTime'].toString()),
      endTime: DateTime.parse(json['endTime'].toString()),
      eventId: json['eventId'] as int?,
      eventKey: json['eventKey'] as String?,
      eventStatus: EventStatus.fromString(json['eventStatus']),
      isMine: json['isMine'] as bool? ?? false,
      referenceNumber: json['reference_number'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'eventId': eventId,
      'eventKey': eventKey,
      'eventStatus': eventStatus.value,
      'isMine': isMine,
      'reference_number': referenceNumber,
    };
  }

  TimeSlotModel copyWith({
    DateTime? startTime,
    DateTime? endTime,
    int? eventId,
    String? Function()? eventKey,
    EventStatus? eventStatus,
    bool? isMine,
    String? Function()? referenceNumber,
  }) {
    return TimeSlotModel(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      eventId: eventId ?? this.eventId,
      eventKey: eventKey != null ? eventKey() : this.eventKey,
      eventStatus: eventStatus ?? this.eventStatus,
      isMine: isMine ?? this.isMine,
      referenceNumber: referenceNumber != null
          ? referenceNumber()
          : this.referenceNumber,
    );
  }

  String get label =>
      '${AppDateUtil.formatTime(startTime)} - ${AppDateUtil.formatTime(endTime)}';

  bool get isPrivate => eventKey != null;

  bool get isAvailable => eventStatus == EventStatus.available;

  /// True when this hour has already started, so it is gone.
  bool get isPast => startTime.isBefore(DateTime.now());

  @override
  List<Object?> get props => [
    startTime,
    endTime,
    eventId,
    eventKey,
    eventStatus,
    isMine,
    referenceNumber,
  ];
}
