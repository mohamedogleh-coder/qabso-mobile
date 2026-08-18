import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../utill/app_constants.dart';
import '../manager_home_model.dart';
import 'home_metric_card_widget.dart';

/// Today's two counts, side by side, with what is still owed under them.
///
/// Games today and played are the same size on purpose: they are the same kind
/// of fact, and one being bigger would say it mattered more.
///
/// The owed bar only appears when the stadium lets a slot be taken in halves.
/// A stadium selling whole slots has nothing outstanding, so a tile that
/// always read zero would be noise.
class HomeStatsWidget extends StatelessWidget {
  final ManagerHomeModel home;

  const HomeStatsWidget({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    final owed = home.remainingAmount;

    return StaggeredGrid.count(
      crossAxisCount: 4,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        StaggeredGridTile.count(
          crossAxisCellCount: 2,
          mainAxisCellCount: 2,
          child: HomeMetricCardWidget(
            icon: Symbols.sports_soccer,
            value: "${home.gamesToday}",
            label: "Games today",
            note: home.gamesToday == 0
                ? "None booked"
                : "${home.upcomingToday} still to come",
            color: AppConstants.primary,
          ),
        ),
        StaggeredGridTile.count(
          crossAxisCellCount: 2,
          mainAxisCellCount: 2,
          child: HomeMetricCardWidget(
            icon: Symbols.check_circle,
            value: "${home.playedToday}",
            label: "Played",
            note: home.playedToday == 0 ? "None yet" : "Already finished",
            color: AppConstants.success,
          ),
        ),
        if (owed != null)
          StaggeredGridTile.count(
            crossAxisCellCount: 4,
            mainAxisCellCount: 1,
            child: HomeMetricCardWidget(
              icon: Symbols.hourglass_top,
              value: "\$${owed.toStringAsFixed(2)}",
              label: "Still owed",
              note: owed == 0
                  ? "Every booking is settled"
                  : "Waiting on second halves",
              color: AppConstants.warning,
              isWide: true,
            ),
          ),
      ],
    );
  }
}
