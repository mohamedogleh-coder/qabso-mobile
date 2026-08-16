import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../utill/app_dailogs.dart';
import '../../../utill/error_widget.dart';
import '../../../utill/loading_widget.dart';
import 'models/explored_stadium_model.dart';
import 'providers/explored_stadiums_notifier.dart';
import 'providers/explored_stadiums_sort_provider.dart';

/// The stadiums the search found, shown after the user taps "Raadi".
///
/// The search itself stays on the previous screen. This one only reads what
/// the filter already asked for, and lets the user put the results in the
/// order they want.
class ExploredStadiumsScreen extends ConsumerWidget {
  const ExploredStadiumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stadiumsAsync = ref.watch(sortedExploredStadiumsProvider);

    return Scaffold(
      appBar: AppBar(titleSpacing: 20, title: const Text("Stadiums found")),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: stadiumsAsync.when(
              skipLoadingOnRefresh: false,
              data: (stadiums) => stadiums.isEmpty
                  ? _buildEmpty(context)
                  : _buildResults(context, ref, stadiums),
              error: (error, stackTrace) => ErrorRetryWidget(
                errorMessage: error is PostgrestException
                    ? error.message
                    : error.toString(),
                onRetry: () => ref
                    .read(exploredStadiumsNotifierProvider.notifier)
                    .refresh(),
              ),
              loading: () => const LoadingWidget(),
            ),
          ),
        ),
      ),
    );
  }

  /// How many stadiums were found, and the button that opens the sort sheet.
  Widget _buildResults(
    BuildContext context,
    WidgetRef ref,
    List<ExploredStadiumModel> stadiums,
  ) {
    return Column(
      children: [
        _buildSortBar(context, ref, stadiums.length),
        const Divider(height: 1),
        Expanded(child: _buildList(context, ref, stadiums)),
      ],
    );
  }

  Widget _buildSortBar(BuildContext context, WidgetRef ref, int found) {
    final theme = Theme.of(context);
    final sort = ref.watch(exploredStadiumsSortProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              found == 1 ? "1 stadium found" : "$found stadiums found",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          TextButton.icon(
            onPressed: () => _openSortSheet(context, ref),
            icon: Icon(sort.iconData, size: 18),
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(sort.label),
                const Icon(Symbols.arrow_drop_down, size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openSortSheet(BuildContext context, WidgetRef ref) async {
    final current = ref.read(exploredStadiumsSortProvider);

    final picked = await showAppBottomSheet<ExploredStadiumsSort>(
      context: context,
      title: "Sort by",
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in ExploredStadiumsSort.values)
              ListTile(
                leading: Icon(
                  option.iconData,
                  fill: option == current ? 1 : 0,
                  color: option == current
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                title: Text(
                  option.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: option == current
                        ? FontWeight.bold
                        : FontWeight.w500,
                  ),
                ),
                trailing: option == current
                    ? Icon(Symbols.check, color: theme.colorScheme.primary)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
            const SizedBox(height: 8),
          ],
        );
      },
    );

    if (picked == null) return;

    ref.read(exploredStadiumsSortProvider.notifier).state = picked;
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    List<ExploredStadiumModel> stadiums,
  ) {
    return RefreshIndicator(
      onRefresh: () =>
          ref.read(exploredStadiumsNotifierProvider.notifier).refresh(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
        itemCount: stadiums.length,
        itemBuilder: (context, index) =>
            _buildStadiumCard(context, stadiums[index]),
      ),
    );
  }

  /// The card the stadium will live in. It carries the name only, because the
  /// stadium card itself is still to be built.
  Widget _buildStadiumCard(BuildContext context, ExploredStadiumModel stadium) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          stadium.stadiumName,
          style: theme.textTheme.headlineMedium,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Symbols.search_off,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 8),
            Text(
              "No stadiums found matching your filters.",
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Isku day taariikh kale, wakhti kale, ama tiro ciyaartoy oo yar.",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Symbols.tune),
              label: const Text("Change filters"),
            ),
          ],
        ),
      ),
    );
  }
}
