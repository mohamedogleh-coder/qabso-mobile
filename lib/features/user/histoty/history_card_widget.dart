import 'package:flutter/material.dart';

import '../../../utill/app_date_util.dart';
import '../../manager/events/event_status_style.dart';
import '../../manager/events/widgets/event_details_sheet.dart';
import 'history_model.dart';

class HistoryCardWidget extends StatelessWidget {
  final HistoryModel history;

  const HistoryCardWidget({super.key, required this.history});

  bool get _hasRemaining => history.remaining > 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = history.eventStatus.color;

    return Material(
      color: Color.alphaBlend(
        color.withValues(alpha: 0.08),
        theme.colorScheme.surface,
      ),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            EventDetailsSheet.show(context, eventId: history.eventId),
        splashColor: color.withValues(alpha: 0.14),
        // The row is measured first so the stripe can be told to fill the
        // card's height. Without this the stripe has no height of its own to
        // take.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // A plain filled box rather than a left border, because a border
              // cannot be thick on one side only while the card is rounded.
              Container(width: 6, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitleRow(theme),
                      const SizedBox(height: 4),
                      _buildWhen(theme),
                      const SizedBox(height: 8),
                      _buildStatusRow(theme, color),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The stadium, and what this user paid for the slot.
  Widget _buildTitleRow(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            history.stadiumName,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          "\$${history.amountPaid.toStringAsFixed(2)}",
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  /// The day the game is on, and the hour it runs.
  Widget _buildWhen(ThemeData theme) {
    final date = AppDateUtil.formatDate(
      history.eventStart,
      pattern: 'dd MMM yyyy',
    );
    final slot = AppDateUtil.formatSlot(history.eventStart, history.eventEnd);

    return Text(
      "$date · $slot",
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// The state of the booking, and what is still owed on it.
  Widget _buildStatusRow(ThemeData theme, Color color) {
    return Row(
      children: [
        Container(
          height: 8,
          width: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          history.eventStatus.label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (_hasRemaining) ...[
          Text(
            " · ",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outlineVariant,
            ),
          ),
          Expanded(
            child: Text(
              "Remaining \$${history.remaining.toStringAsFixed(2)}",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
