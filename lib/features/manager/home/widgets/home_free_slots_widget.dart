import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../utill/app_constants.dart';
import '../manager_home_model.dart';

/// What is still free to sell today.
///
/// Built like the next-game card on purpose. Those two are the only things on
/// the dashboard a manager can act on right now — one is the game in front of
/// them, the other is the hours they could still fill — so they carry the same
/// weight.
class HomeFreeSlotsWidget extends StatelessWidget {
  final ManagerHomeModel home;

  const HomeFreeSlotsWidget({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final free = home.freeSlotsToday;
    final isSoldOut = free == 0;

    // Nothing left is a good day, not a warning, so it stays the same colour
    // and only the words change.
    const color = AppConstants.tertiary;

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
              Container(
                height: 10,
                width: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                "Still free",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "Today",
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            isSoldOut ? "Fully booked" : "$free ${free == 1 ? 'slot' : 'slots'}",
            style: theme.textTheme.headlineLarge?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 30,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Symbols.event_available,
                size: 18,
                fill: 1,
                color: color,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isSoldOut
                      ? "Every hour left today is taken"
                      : "Still sellable before the stadium closes",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
