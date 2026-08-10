class WorkingDayModel {
  /// Indexed by `dayOfWeek - 1`, matching the table's 1..7 (Monday first).
  static const List<String> dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  final int? id;
  final int dayOfWeek;
  final String openTime;
  final String closeTime;
  final bool isOpen;

  String get dayName => dayNames[dayOfWeek - 1];

  const WorkingDayModel({
    this.id,
    required this.dayOfWeek,
    required this.openTime,
    required this.closeTime,
    required this.isOpen,
  });

  factory WorkingDayModel.fromJson(Map<String, dynamic> json) {
    return WorkingDayModel(
      id: json['id'],
      dayOfWeek: json['day_of_week'],
      openTime: json['open_time'],
      closeTime: json['close_time'],
      isOpen: json['is_open'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'day_of_week': dayOfWeek,
      'open_time': openTime,
      'close_time': closeTime,
      'is_open': isOpen,
    };
  }

  WorkingDayModel copyWith({
    int? id,
    int? dayOfWeek,
    String? openTime,
    String? closeTime,
    bool? isOpen,
  }) {
    return WorkingDayModel(
      id: id ?? this.id,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
      isOpen: isOpen ?? this.isOpen,
    );
  }
}
