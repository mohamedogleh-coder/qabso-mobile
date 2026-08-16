import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/features/user/explore/widgets/explored_sstadium_card_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../utill/app_dailogs.dart';
import '../../../utill/error_widget.dart';
import '../../../utill/loading_widget.dart';
import 'providers/explored_stadiums_notifier.dart';
import 'providers/explored_stadiums_sort_provider.dart';

class ExploredStadiumsScreen extends ConsumerWidget {
  const ExploredStadiumsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stadiumsAsync = ref.watch(sortedExploredStadiumsProvider);
    final sort = ref.watch(exploredStadiumsSortProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          stadiumsAsync.hasValue && !stadiumsAsync.isLoading
              ? '${stadiumsAsync.value!.length} Explored'
              : 'Explored',
        ),
        actions: [
          if (stadiumsAsync.hasValue && !stadiumsAsync.isLoading)
            _buildSortButton(context, ref, sort),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: stadiumsAsync.when(
                skipLoadingOnRefresh: false,
                data: (stadiums) => stadiums.isEmpty
                    ? _buildEmpty(context)
                    : ListView.builder(
                        itemCount: stadiums.length,
                        shrinkWrap: true,
                        itemBuilder: (context, index) =>
                            ExploredStadiumCardWidget(
                              stadiumModel: stadiums[index],
                            ),
                      ),
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
      ),
    );
  }

  Widget _buildSortButton(
    BuildContext context,
    WidgetRef ref,
    ExploredStadiumsSort sort,
  ) {
    final theme = Theme.of(context);

    return OutlinedButton.icon(
      onPressed: () => _openSortSheet(context, ref),
      icon: Icon(sort.iconData, size: 18, fill: 1),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(sort.label),
          const Icon(Symbols.arrow_drop_down, size: 20),
        ],
      ),
      style: OutlinedButton.styleFrom(
        shape: const StadiumBorder(),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
        foregroundColor: theme.colorScheme.onSurface,
        textStyle: theme.textTheme.bodySmall,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        iconColor: theme.colorScheme.primary,
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
              "Isku day filters kale.",
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
