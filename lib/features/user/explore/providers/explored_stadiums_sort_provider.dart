import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../models/explored_stadium_model.dart';
import 'explored_stadiums_notifier.dart';

enum ExploredStadiumsSort {
  nearest,
  cheapest,
  biggest;

  String get label => switch (this) {
    ExploredStadiumsSort.nearest => "Nearest",
    ExploredStadiumsSort.cheapest => "Lowest cost",
    ExploredStadiumsSort.biggest => "Biggest field",
  };

  IconData get iconData => switch (this) {
    ExploredStadiumsSort.nearest => Symbols.near_me,
    ExploredStadiumsSort.cheapest => Symbols.payments,
    ExploredStadiumsSort.biggest => Symbols.group,
  };
}

final exploredStadiumsSortProvider = StateProvider<ExploredStadiumsSort>(
  (ref) => ExploredStadiumsSort.nearest,
);

final sortedExploredStadiumsProvider =
    Provider<AsyncValue<List<ExploredStadiumModel>>>((ref) {
      final stadiums = ref.watch(exploredStadiumsNotifierProvider);
      final sort = ref.watch(exploredStadiumsSortProvider);

      return stadiums.whenData((found) {
        final sorted = [...found];

        switch (sort) {
          case ExploredStadiumsSort.nearest:
            sorted.sort((a, b) {
              if (a.distance == null) return 1;
              if (b.distance == null) return -1;

              return a.distance!.compareTo(b.distance!);
            });
          case ExploredStadiumsSort.cheapest:
            sorted.sort(
              (a, b) => (a.capacity * a.cost).compareTo(b.capacity * b.cost),
            );
          case ExploredStadiumsSort.biggest:
            sorted.sort((a, b) => b.capacity.compareTo(a.capacity));
        }

        return sorted;
      });
    });
