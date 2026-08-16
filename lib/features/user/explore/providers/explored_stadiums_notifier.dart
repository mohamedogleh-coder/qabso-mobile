import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../explore_stadiums_repository.dart';
import '../models/explore_stadium_filter.dart';
import '../models/explored_stadium_model.dart';
import 'explore_stadiums_filter_notifier.dart';

final exploredStadiumsNotifierProvider =
    AsyncNotifierProvider<ExploredStadiumsNotifier, List<ExploredStadiumModel>>(
      ExploredStadiumsNotifier.new,
    );

class ExploredStadiumsNotifier
    extends AsyncNotifier<List<ExploredStadiumModel>> {
  @override
  FutureOr<List<ExploredStadiumModel>> build() {
    return _search(ref.watch(exploredStadiumFilterNotifierProvider));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    state = await AsyncValue.guard(
      () => _search(ref.read(exploredStadiumFilterNotifierProvider)),
    );
  }

  Future<List<ExploredStadiumModel>> _search(ExploreStadiumFilter filter) {
    return ExploreStadiumsRepository.searchStadiums(
      capacity: filter.capacity,
      date: filter.eventDate,
      time: filter.eventTime,
      latitude: filter.aroundMe ? filter.latitude : null,
      longitude: filter.aroundMe ? filter.longitude : null,
    );
  }
}
