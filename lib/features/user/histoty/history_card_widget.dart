import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../utill/app_date_util.dart';
import '../../manager/events/event_status_style.dart';
import '../../manager/events/widgets/event_details_sheet.dart';
import 'history_model.dart';

/// One booking in the user's history.
///
/// The state of the booking is carried by the icon at the front and the pill
/// beside the stadium name, so the card itself stays a plain surface and a
/// list of them reads as one list.
class HistoryCardWidget extends StatelessWidget {
  final HistoryModel history;

  const HistoryCardWidget({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = history.eventStatus.color;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => EventDetailsSheet.show(context, eventId: history.eventId),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        leading: _buildLeadingIcon(color),
        title: _buildTitle(theme, color),
        subtitle: _buildSubtitle(theme),
      ),
    );
  }

  Widget _buildLeadingIcon(Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Symbols.history, size: 20, fill: 1, color: color),
    );
  }

  Widget _buildTitle(ThemeData theme, Color color) {
    return Row(
      children: [
        Expanded(
          child: Text(
            history.stadiumName,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          history.eventStatus.label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.3,
          ),
        ),
        // _buildStatusPill(theme, color),
      ],
    );
  }

  Widget _buildStatusPill(ThemeData theme, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        history.eventStatus.label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// When the game is, and what this user paid for it.
  Widget _buildSubtitle(ThemeData theme) {
    final date = AppDateUtil.formatDate(history.eventStart, pattern: 'dd MMM');
    final slot = AppDateUtil.formatSlot(history.eventStart, history.eventEnd);

    return Row(
      mainAxisAlignment: .spaceBetween,
      children: [
        Expanded(
          child: Text(
            "$date · $slot",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          "\$${history.amountPaid.toStringAsFixed(2)}",
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
