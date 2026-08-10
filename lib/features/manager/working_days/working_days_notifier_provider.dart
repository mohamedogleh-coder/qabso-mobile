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

  Future<WorkingDayModel> saveDay(WorkingDayModel day) async {
    final week = await saveDays([day]);

    return _dayIn(week, day.dayOfWeek);
  }

  static WorkingDayModel _dayIn(List<WorkingDayModel> week, int dayOfWeek) {
    return week.firstWhere(
      (day) => day.dayOfWeek == dayOfWeek,
      orElse: () => throw StateError('No working day $dayOfWeek on file.'),
    );
  }
}
