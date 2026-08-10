import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qabso_mobile/features/manager/working_days/working_days.dart';
import 'package:qabso_mobile/features/manager/working_days/working_days_repository.dart';

import '../stadium/stadium_notifier_provider.dart';

final workingDaysNotifierProvider =
    AsyncNotifierProvider<WorkingDaysNotifierProvider, List<WorkingDayModel>>(
      WorkingDaysNotifierProvider.new,
    );

class WorkingDaysNotifierProvider extends AsyncNotifier<List<WorkingDayModel>> {
  bool _isSaving = false;

  bool get isSaving => _isSaving;

  @override
  FutureOr<List<WorkingDayModel>> build() async {
    final stadium = await ref.watch(stadiumNotifierProvider.future);

    if (stadium?.stadiumId == null) return const [];

    return WorkingDaysRepository.getWorkingDays(stadiumId: stadium!.stadiumId!);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    final stadiumId = ref.read(stadiumNotifierProvider).value?.stadiumId;
    if (stadiumId == null) {
      state = const AsyncData([]);
      return;
    }

    state = await AsyncValue.guard(
      () => WorkingDaysRepository.getWorkingDays(stadiumId: stadiumId),
    );
  }

  /// Saves [days] — one day, a few, or the whole week — and returns the
  /// stadium's week as stored. The repository returns every day, so state is
  /// replaced with it directly; no re-fetch.
  ///
  /// Deliberately does not set `state = AsyncLoading()` first, and throws on
  /// failure instead of writing `AsyncError`, for the same reasons as the
  /// field notifier's create/update: the screen shows its own inline
  /// spinner, and a failed save shouldn't blank out a week that is loaded
  /// and displaying fine. The caller catches and shows the error.
  ///
  /// Overlapping saves are refused rather than queued: each call returns the
  /// full week as the server read it back, so two in flight at once could
  /// finish out of order and leave state showing the week *without* the
  /// change that landed last.
  Future<List<WorkingDayModel>> saveDays(List<WorkingDayModel> days) async {
    if (_isSaving) {
      throw StateError('A working days save is already in progress.');
    }

    final stadiumId = ref.read(stadiumNotifierProvider).value?.stadiumId;
    if (stadiumId == null) {
      throw StateError('Cannot save working days: no stadium yet.');
    }

    _isSaving = true;
    try {
      final week = await WorkingDaysRepository.saveWorkingDays(
        stadiumId: stadiumId,
        days: days,
      );
      state = AsyncData(week);
      return week;
    } finally {
      _isSaving = false;
    }
  }

  /// Saves a single day's open time, close time and open/closed flag, and
  /// returns it as stored.
  Future<WorkingDayModel> saveDay(WorkingDayModel day) async {
    final week = await saveDays([day]);

    return _dayIn(week, day.dayOfWeek);
  }

  /// Opens or closes [dayOfWeek], keeping its current hours — a closed day
  /// still needs times on file to satisfy the table's
  /// `close_time > open_time` check, and keeping them means reopening the
  /// day restores the hours it had.
  ///
  /// Reads the day from current state, so it only works on a day already
  /// loaded; use [saveDay] for one that has never been saved.
  Future<WorkingDayModel> setDayOpen(int dayOfWeek, bool isOpen) {
    final day = _dayIn(state.value ?? const [], dayOfWeek);

    return saveDay(day.copyWith(isOpen: isOpen));
  }

  static WorkingDayModel _dayIn(List<WorkingDayModel> week, int dayOfWeek) {
    return week.firstWhere(
      (day) => day.dayOfWeek == dayOfWeek,
      orElse: () => throw StateError('No working day $dayOfWeek on file.'),
    );
  }
}
