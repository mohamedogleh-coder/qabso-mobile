import 'package:flutter/material.dart';

class ExploreStadiumFilter {
  final int capacity;
  final double? latitude;
  final DateTime eventDate;
  final TimeOfDay? eventTime;
  final double? longitude;
  final bool aroundMe;

  const ExploreStadiumFilter({
    required this.capacity,
    required this.eventDate,
    this.latitude,
    this.longitude,
    this.aroundMe = false,
    this.eventTime,
  });

  ExploreStadiumFilter copyWith({
    int? capacity,
    DateTime? eventDate,
    TimeOfDay? Function()? eventTime,
    double? latitude,
    double? longitude,
    bool? aroundMe,
  }) {
    return ExploreStadiumFilter(
      capacity: capacity ?? this.capacity,
      eventDate: eventDate ?? this.eventDate,
      eventTime: eventTime != null ? eventTime() : this.eventTime,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      aroundMe: aroundMe ?? this.aroundMe,
    );
  }
}
