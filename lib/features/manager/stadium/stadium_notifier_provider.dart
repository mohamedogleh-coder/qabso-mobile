import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qabso_mobile/features/manager/stadium/stadium_model.dart';
import 'package:qabso_mobile/features/manager/stadium/stadium_repository.dart';

import '../../auth/app_user_notifer.dart';

/// The earliest date the app's pickers offer: the day the stadium was
/// registered. Nothing — no booking, payment or expense — happened here before
/// that, so there is nothing to look at further back.
///
/// Falls back to the start of 2026 while the stadium is still loading, which
/// is what every picker used before the stadium carried its own date.
final stadiumFirstDateProvider = Provider<DateTime>((ref) {
  final createdAt = ref.watch(stadiumNotifierProvider).value?.createdAt;

  if (createdAt == null) return DateTime(2026);

  return DateTime(createdAt.year, createdAt.month, createdAt.day);
});

final stadiumNotifierProvider =
    AsyncNotifierProvider<StadiumNotifierProvider, StadiumModel?>(
      StadiumNotifierProvider.new,
    );

class StadiumNotifierProvider extends AsyncNotifier<StadiumModel?> {
  @override
  FutureOr<StadiumModel?> build() async {
    final appUser = await ref.watch(appUserNotifierProvider.future);

    if (appUser == null) return null;

    return StadiumRepository.getCurrentManagerStadium();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(
      () => StadiumRepository.getCurrentManagerStadium(),
    );
  }

  Future<void> saveStadium(StadiumModel model) async {
    state = await AsyncValue.guard(
      () => StadiumRepository.upsertStadium(model: model),
    );
  }
}
