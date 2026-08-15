import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/explore_stadium_filter.dart';

final exploredStadiumFilterNotifierProvider =
    NotifierProvider<ExploreStadiumFilterNotifier, ExploreStadiumFilter>(
      ExploreStadiumFilterNotifier.new,
    );

class ExploreStadiumFilterNotifier extends Notifier<ExploreStadiumFilter> {
  @override
  ExploreStadiumFilter build() {
    return ExploreStadiumFilter(
      capacity: 8,
      eventDate: DateTime.now(),
      eventTime: null,
    );
  }

  void updateCapacity(int value) {
    state = state.copyWith(capacity: value);
  }

  void updateDate(DateTime value) {
    state = state.copyWith(eventDate: value);
  }

  void updateTime(TimeOfDay? value) {
    state = state.copyWith(eventTime: () => value);
  }


}
