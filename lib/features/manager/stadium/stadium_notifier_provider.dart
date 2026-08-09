import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qabso_mobile/features/manager/stadium/stadium_model.dart';
import 'package:qabso_mobile/features/manager/stadium/stadium_repository.dart';

import '../../auth/app_user_notifer.dart';

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
}
