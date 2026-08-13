import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../utill/app_constants.dart';
import '../models/event_summery_model.dart';

class EventsSummeryCardWidget extends StatelessWidget {
  final EventsSummaryModel model;

  const EventsSummeryCardWidget({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          const SizedBox(height: 14),
          _buildStats(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: AppConstants.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Symbols.grass, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Field ${model.fieldId}",
                style: theme.textTheme.bodyLarge!.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                "${model.capacity} players",
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        _buildTotal(context),
      ],
    );
  }

  // The total sits apart from the four counts because it is the sum of the
  // field's whole day, not another status.
  Widget _buildTotal(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _tinted(context, AppConstants.primary),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "${model.totalEvents}",
            style: theme.textTheme.bodyLarge!.copyWith(
              color: AppConstants.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            model.totalEvents == 1 ? "event" : "events",
            style: theme.textTheme.bodySmall!.copyWith(
              color: AppConstants.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats(BuildContext context) {
    const spacing = 8.0;
    final stats = [
      (
        Symbols.hourglass_top,
        "Pending",
        model.pendingEvents,
        AppConstants.warning,
      ),
      (
        Symbols.check_circle,
        "Confirmed",
        model.confirmedEvents,
        AppConstants.success,
      ),
      (
        Symbols.sports_soccer,
        "Completed",
        model.completedEvents,
        AppConstants.tertiary,
      ),
      (Symbols.cancel, "Canceled", model.canceledEvents, AppConstants.error),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 420 ? 2 : 4;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final stat in stats)
              SizedBox(
                width: width,
                child: _buildStatTile(
                  context,
                  iconData: stat.$1,
                  label: stat.$2,
                  count: stat.$3,
                  color: stat.$4,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStatTile(
    BuildContext context, {
    required IconData iconData,
    required String label,
    required int count,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: _tinted(context, color),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconData, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            "$count",
            style: theme.textTheme.headlineSmall!.copyWith(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall!.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Color _tinted(BuildContext context, Color color) {
    return Color.alphaBlend(
      color.withValues(alpha: 0.18),
      Theme.of(context).colorScheme.surface,
    );
  }
}
