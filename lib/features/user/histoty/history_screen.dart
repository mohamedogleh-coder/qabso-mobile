import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../utill/error_widget.dart';
import '../../../utill/loading_widget.dart';
import '../user_shell.dart';
import 'history_card_widget.dart';
import 'history_model.dart';
import 'history_repository.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  late Future<List<HistoryModel>> historyFuture;

  @override
  void initState() {
    super.initState();

    historyFuture = HistoryRepository.getHistory();
  }

  void _reload() {
    setState(() {
      historyFuture = HistoryRepository.getHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("History"),
        titleSpacing: 20,
        actions: [
          TextButton.icon(
            onPressed: () {
              setState(() {
                _reload();
              });
            },
            icon: Icon(Symbols.refresh),
            label: Text("Refresh"),
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<HistoryModel>>(
          future: historyFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingWidget();
            }

            if (snapshot.hasError) {
              final error = snapshot.error;

              return ErrorRetryWidget(
                errorMessage: error is PostgrestException
                    ? error.message
                    : error.toString(),
                onRetry: _reload,
              );
            }

            final history = snapshot.data ?? const <HistoryModel>[];

            if (history.isEmpty) return _buildEmpty();

            return _buildList(history);
          },
        ),
      ),
    );
  }

  Widget _buildList(List<HistoryModel> history) {
    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        await historyFuture;
      },
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: history.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => HistoryCardWidget(
              key: ValueKey(history[index].eventId),
              history: history[index],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
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
              onPressed: () {
                ref.read(selectedIndexProvider.notifier).state = 0;
              },
              icon: const Icon(Symbols.search),
              label: const Text("Explore now"),
            ),
          ],
        ),
      ),
    );
  }
}
