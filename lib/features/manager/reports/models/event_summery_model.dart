class EventsSummaryModel {
  final int fieldId;
  final int capacity;
  final int totalEvents;
  final int pendingEvents;
  final int confirmedEvents;
  final int completedEvents;
  final int canceledEvents;

  const EventsSummaryModel({
    required this.fieldId,
    required this.capacity,
    required this.totalEvents,
    required this.pendingEvents,
    required this.confirmedEvents,
    required this.completedEvents,
    required this.canceledEvents,
  });

  factory EventsSummaryModel.fromJson(Map<String, dynamic> json) {
    return EventsSummaryModel(
      fieldId: json['fieldId'] ?? 0,
      capacity: json['capacity'] ?? 0,
      totalEvents: json['totalEvents'] ?? 0,
      pendingEvents: json['pendingEvents'] ?? 0,
      confirmedEvents: json['confirmedEvents'] ?? 0,
      completedEvents: json['completedEvents'] ?? 0,
      canceledEvents: json['canceledEvents'] ?? 0,
    );
  }
}
