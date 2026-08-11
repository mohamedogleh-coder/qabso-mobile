import 'package:equatable/equatable.dart';

import '../../../utill/app_date_util.dart';

enum EventStatus {
  available,
  pending,
  confirmed,
  canceled;

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

  const TimeSlotModel({
    required this.startTime,
    required this.endTime,
    this.eventId,
    this.eventKey,
    required this.eventStatus,
  });

  factory TimeSlotModel.fromJson(Map<String, dynamic> json) {
    return TimeSlotModel(
      startTime: DateTime.parse(json['startTime'].toString()),
      endTime: DateTime.parse(json['endTime'].toString()),
      eventId: json['eventId'] as int?,
      eventKey: json['eventKey'] as String?,
      eventStatus: EventStatus.fromString(json['eventStatus']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'eventId': eventId,
      'eventKey': eventKey,
      'eventStatus': eventStatus.value,
    };
  }

  TimeSlotModel copyWith({
    DateTime? startTime,
    DateTime? endTime,
    int? eventId,
    String? Function()? eventKey,
    EventStatus? eventStatus,
  }) {
    return TimeSlotModel(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      eventId: eventId ?? this.eventId,
      eventKey: eventKey != null ? eventKey() : this.eventKey,
      eventStatus: eventStatus ?? this.eventStatus,
    );
  }

  String get label =>
      '${AppDateUtil.formatTime(startTime)} - ${AppDateUtil.formatTime(endTime)}';

  bool get isPrivate => eventKey != null;

  bool get isAvailable => eventStatus == EventStatus.available;

  @override
  List<Object?> get props => [
    startTime,
    endTime,
    eventId,
    eventKey,
    eventStatus,
  ];
}
