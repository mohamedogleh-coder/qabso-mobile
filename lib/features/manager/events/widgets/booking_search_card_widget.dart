import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../utill/app_dailogs.dart';
import '../../../../utill/app_date_util.dart';
import '../event_status_style.dart';
import '../models/booking_search_result_model.dart';
import 'event_details_sheet.dart';

/// One booking the search found.
///
/// The number leads, because it is what the manager typed and what they are
/// about to ring. The day sits in a block on the left so a list of results
/// reads down the edge, and the whole card opens the booking.
class BookingSearchCardWidget extends StatelessWidget {
  final BookingSearchResultModel result;

  const BookingSearchCardWidget({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = result.eventStatus.color;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            EventDetailsSheet.show(context, eventId: result.eventId),
        splashColor: color.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildDateBlock(theme, color),
              const SizedBox(width: 12),
              Expanded(child: _buildDetails(theme, color)),
              const SizedBox(width: 4),
              _buildCopyButton(context, theme),
            ],
          ),
        ),
      ),
    );
  }

  /// The day of the game, in the booking's own colour.
  Widget _buildDateBlock(ThemeData theme, Color color) {
    return Container(
      height: 54,
      width: 54,
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: 0.14),
          theme.colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            AppDateUtil.formatDate(result.eventStart, pattern: 'dd'),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            AppDateUtil.formatDate(
              result.eventStart,
              pattern: 'MMM',
            ).toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  /// The number, the hour, and where the booking stands.
  Widget _buildDetails(ThemeData theme, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          result.phoneNumber,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Icon(
              Symbols.schedule,
              size: 15,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
            Text(
              AppDateUtil.formatSlot(result.eventStart, result.eventEnd),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              height: 8,
              width: 8,
              decoration: BoxDecoration(shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 6),
            Text(
              result.eventStatus.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Puts the number on the clipboard, since the whole point of keeping it is
  /// being able to ring the customer.
  Widget _buildCopyButton(BuildContext context, ThemeData theme) {
    return IconButton(
      onPressed: () async {
        await Clipboard.setData(ClipboardData(text: result.phoneNumber));

        if (!context.mounted) return;

        showSuccessSnackBar(
          context: context,
          message: "Taleefanka waa la koobiyeeyay.",
        );
      },
      tooltip: "Copy number",
      icon: Icon(Symbols.content_copy, color: theme.colorScheme.primary),
    );
  }
}
