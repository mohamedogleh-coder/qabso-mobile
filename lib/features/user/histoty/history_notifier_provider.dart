import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'history_model.dart';
import 'history_repository.dart';

final historyNotifierProvider =
    AsyncNotifierProvider<HistoryNotifier, List<HistoryModel>>(
      HistoryNotifier.new,
    );

/// Every booking the signed-in user paid on, newest game first.
///
/// One list for both screens: the home section shows the first five of it and
/// the history screen shows all of it, so the two can never disagree.
class HistoryNotifier extends AsyncNotifier<List<HistoryModel>> {
  @override
  FutureOr<List<HistoryModel>> build() {
    return HistoryRepository.getHistory();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(HistoryRepository.getHistory);
  }

  /// Puts a booking the user just made into the list, so the history shows it
  /// without reading it back from the server.
  ///
  /// It is sorted in rather than pushed on top, because the list runs by game
  /// time and a new booking is not always the furthest away one.
  void addBooking(HistoryModel booking) {
    final history = state.value;
    if (history == null) return;

    final updated = [...history, booking]
      ..sort((a, b) => b.eventStart.compareTo(a.eventStart));

    state = AsyncData(updated);
  }
}
