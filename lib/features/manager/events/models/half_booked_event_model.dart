class HalfBookedEventModel {
  final int id;
  final DateTime eventStart;
  final DateTime eventEnd;
  final String? eventKey;
  final int extraTime;
  final double remaining;

  const HalfBookedEventModel({
    required this.id,
    required this.eventStart,
    required this.eventEnd,
    this.eventKey,
    required this.extraTime,
    required this.remaining,
  });

  String get label => '$eventStart - $eventEnd';

  factory HalfBookedEventModel.fromJson(Map<String, dynamic> json) {
    return HalfBookedEventModel(
      id: json['id'] as int,
      eventStart: DateTime.parse(json['event_start'] as String),
      eventEnd: DateTime.parse(json['event_end'] as String),
      eventKey: json['event_key'] as String?,
      extraTime: (json['extra_time'] as num).toInt(),
      remaining: (json['remaining'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'eventStart': eventStart.toIso8601String(),
      'eventEnd': eventEnd.toIso8601String(),
      'eventKey': eventKey,
      'extraTime': extraTime,
      'remaining': remaining,
    };
  }

  HalfBookedEventModel copyWith({
    int? id,
    DateTime? eventStart,
    DateTime? eventEnd,
    String? eventKey,
    int? extraTime,
    double? remaining,
  }) {
    return HalfBookedEventModel(
      id: id ?? this.id,
      eventStart: eventStart ?? this.eventStart,
      eventEnd: eventEnd ?? this.eventEnd,
      eventKey: eventKey ?? this.eventKey,
      extraTime: extraTime ?? this.extraTime,
      remaining: remaining ?? this.remaining,
    );
  }
}
