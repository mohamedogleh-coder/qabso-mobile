import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../utill/app_constants.dart';
import '../manager_home_model.dart';

/// What is stopping the stadium taking bookings, and where to go and fix it.
///
/// Nothing here is decoration. Each row is something that on its own means no
/// customer can book or pay, so a stadium that was set up halfway says so
/// instead of quietly taking nothing all week.
///
/// Shows nothing at all when the stadium is ready.
class HomeBlockersWidget extends StatelessWidget {
  final ManagerHomeModel home;

  const HomeBlockersWidget({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    if (home.canTakeBookings) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Color.alphaBlend(
          colorScheme.error.withValues(alpha: 0.10),
          colorScheme.surface,
        ),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.warning, fill: 1, color: colorScheme.error),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Nobody can book yet",
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            "The stadium takes no bookings until these are set up.",
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          if (!home.hasWorkingDays)
            _buildBlocker(
              context,
              icon: Symbols.calendar_month,
              title: "No working days",
              message: "Nobody can book on a day the stadium never opens.",
              route: AppConstants.workingDays,
            ),
          if (!home.hasBookableField)
            _buildBlocker(
              context,
              icon: Symbols.grass,
              title: "No field open",
              message: "There is nothing for a customer to take.",
              route: AppConstants.fields,
            ),
          if (!home.hasActiveMerchant)
            _buildBlocker(
              context,
              icon: Symbols.account_balance_wallet,
              title: "No payment number",
              message: "There is no way for the money to reach you.",
              route: AppConstants.merchants,
            ),
        ],
      ),
    );
  }

  /// One thing to fix, and the tap that opens the screen that fixes it.
  Widget _buildBlocker(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
    required String route,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.of(context).pushNamed(route),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(icon, size: 22, fill: 1, color: colorScheme.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Symbols.chevron_right,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
