import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../utill/card_list_shimmer_widget.dart';
import '../../../utill/error_widget.dart';
import '../user_shell.dart';
import 'history_card_widget.dart';
import 'history_group.dart';
import 'history_model.dart';
import 'history_notifier_provider.dart';

/// The booking history on the user's home screen.
///
/// It shows the newest few bookings and sends the user to the history tab
/// for the rest. The list it reads is the same one that tab reads, so the
/// two always agree.
class HistoryHomeSectionWidget extends ConsumerWidget {
  const HistoryHomeSectionWidget({super.key});

  /// How many bookings the home screen shows before it sends the user to the
  /// full list.
  static const _limit = 5;

  /// The history tab in [UserShell].
  static const _historyTab = 2;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(historyNotifierProvider)
        .when(
          skipLoadingOnRefresh: false,
          loading: () => const CardListShimmerWidget(showHeader: true),
          error: (error, stackTrace) => ErrorRetryWidget(
            errorMessage: error is PostgrestException
                ? error.message
                : error.toString(),
            onRetry: () => ref.read(historyNotifierProvider.notifier).refresh(),
          ),
          data: (history) => history.isEmpty
              ? _buildEmpty(context)
              : _buildSection(context, ref, history),
        );
  }

  Widget _buildSection(
    BuildContext context,
    WidgetRef ref,
    List<HistoryModel> history,
  ) {
    final latest = history.take(_limit).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, ref, history.length),
        const SizedBox(height: 12),
        _buildGroups(context, groupHistory(latest)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, int total) {
    return Row(
      children: [
        Text("($total) Booking History"),
        const Spacer(),
        if (total > _limit)
          TextButton(
            onPressed: () =>
                ref.read(selectedIndexProvider.notifier).state = _historyTab,
            child: const Text("See all"),
          ),
      ],
    );
  }

  Widget _buildGroups(
    BuildContext context,
    Map<HistoryGroup, List<HistoryModel>> grouped,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              entry.key.label.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
              ),
            ),
          ),
          for (final booking in entry.value) ...[
            HistoryCardWidget(key: ValueKey(booking.eventId), history: booking),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Symbols.history, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text("No bookings yet", style: theme.textTheme.bodyLarge),
          const SizedBox(height: 8),
          Text(
            "Garoon booko, kadibna halkan ayaad ka arki doontaa "
            "dhammaan bookingyadaada.",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
