import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../utill/app_constants.dart';
import '../../../../utill/app_date_util.dart';
import '../../events/event_status_style.dart';
import '../../events/time_slots_model.dart';
import '../manager_home_model.dart';

/// The game being played right now, or the next one to come.
///
/// The one thing a manager standing at the gate wants first, so it is the
/// biggest thing on the screen.
class HomeNextGameWidget extends StatelessWidget {
  final ManagerHomeModel home;

  const HomeNextGameWidget({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    if (!home.hasNextBooking) return _buildNothingLeft(context);

    final theme = Theme.of(context);
    final status = home.nextEventStatus;
    final color = status?.color ?? theme.colorScheme.primary;
    final isNow = home.isNextPlayingNow;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Color.alphaBlend(
          color.withValues(alpha: 0.10),
          theme.colorScheme.surface,
        ),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // A game under way is called out differently from one still to
              // come, because what the manager does about it is different.
              Container(
                height: 10,
                width: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
              const SizedBox(width: 8),
              Text(
                isNow ? "Playing now" : "Next up",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (status != null) _buildStatusChip(theme, status, color),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            AppDateUtil.formatSlot(home.nextEventStart!, home.nextEventEnd!),
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 30,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Symbols.grass, size: 18, fill: 1, color: color),
              const SizedBox(width: 6),
              Text(
                "Field #${home.nextFieldId}",
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(ThemeData theme, EventStatus status, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        status.label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// The day is done, or nothing was ever booked into it. Said plainly, and
  /// pointed at what is still sellable rather than left as bad news.
  Widget _buildNothingLeft(BuildContext context) {
    final theme = Theme.of(context);
    final free = home.freeSlotsToday;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: theme.colorScheme.surfaceContainerHighest,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppConstants.tertiary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Symbols.event_available,
              fill: 1,
              color: AppConstants.tertiary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Nothing else booked today",
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  free == 0
                      ? "The day is fully spoken for."
                      : "$free ${free == 1 ? 'slot is' : 'slots are'} still "
                            "free to sell.",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
