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

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Booking History"),
        titleSpacing: 20,
        // actions: [
        //   TextButton.icon(
        //     onPressed: () =>
        //         ref.read(historyNotifierProvider.notifier).refresh(),
        //     icon: const Icon(Symbols.refresh),
        //     label: const Text("Refresh"),
        //   ),
        // ],
      ),
      body: SafeArea(
        child: ref
            .watch(historyNotifierProvider)
            .when(
              skipLoadingOnRefresh: false,
              loading: () => const Padding(
                padding: EdgeInsets.all(12),
                child: CardListShimmerWidget(cards: 6),
              ),
              error: (error, stackTrace) => ErrorRetryWidget(
                errorMessage: error is PostgrestException
                    ? error.message
                    : error.toString(),
                onRetry: () =>
                    ref.read(historyNotifierProvider.notifier).refresh(),
              ),
              data: (history) => history.isEmpty
                  ? _buildEmpty(context, ref)
                  : _buildList(context, ref, history),
            ),
      ),
    );
  }

  /// Every booking, under the heading for the day its game is on.
  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<HistoryModel> history,
  ) {
    final theme = Theme.of(context);
    final grouped = groupHistory(history);

    return RefreshIndicator(
      onRefresh: () => ref.read(historyNotifierProvider.notifier).refresh(),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(12),
            physics: const AlwaysScrollableScrollPhysics(),
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
                  HistoryCardWidget(
                    key: ValueKey(booking.eventId),
                    history: booking,
                  ),
                  const SizedBox(height: 8),
                ],
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () =>
                  ref.read(selectedIndexProvider.notifier).state = 0,
              icon: const Icon(Symbols.search),
              label: const Text("Explore now"),
            ),
          ],
        ),
      ),
    );
  }
}
