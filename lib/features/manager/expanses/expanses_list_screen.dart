import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../utill/app_dailogs.dart';
import '../../../utill/error_widget.dart';
import '../../../utill/loading_widget.dart';
import '../reports/widgets/report_based_widget.dart';
import '../stadium/stadium_notifier_provider.dart';
import 'expanse_card_widget.dart';
import 'expanse_model.dart';
import 'expanse_repository.dart';

/// The stadium's expenses for a chosen stretch of days, with what they came
/// to.
///
/// The dates and the type both narrow the read itself, so the list on screen
/// is exactly what the database returned.
class ExpansesListScreen extends ConsumerStatefulWidget {
  const ExpansesListScreen({super.key});

  @override
  ConsumerState<ExpansesListScreen> createState() => _ExpansesListScreenState();
}

class _ExpansesListScreenState extends ConsumerState<ExpansesListScreen> {
  late DateTimeRange selectedDateRange;
  late Future<List<ExpanseModel>> expansesFuture;

  /// The kind being shown, or null for all of them.
  ExpanseType? selectedType;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    selectedDateRange = DateTimeRange(start: now, end: now);
    expansesFuture = _fetchExpanses();
  }

  Future<List<ExpanseModel>> _fetchExpanses() async {
    final stadium = ref.read(stadiumNotifierProvider).value;

    if (stadium?.stadiumId == null) {
      throw StateError('No stadium was found for this manager.');
    }

    return ExpanseRepository.getExpanses(
      stadiumId: stadium!.stadiumId!,
      startDate: selectedDateRange.start,
      endDate: selectedDateRange.end,
      type: selectedType,
    );
  }

  Future<void> _pickDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2026),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: selectedDateRange,
    );

    if (range == null) return;

    setState(() {
      selectedDateRange = range;
      expansesFuture = _fetchExpanses();
    });
  }

  void _selectType(ExpanseType? type) {
    setState(() {
      selectedType = type;
      expansesFuture = _fetchExpanses();
    });
  }

  void _reload() {
    setState(() {
      expansesFuture = _fetchExpanses();
    });
  }

  /// What a manager can do with one expense.
  Future<void> _openExpanseActions(ExpanseModel expanse) async {
    await showAppBottomSheet<void>(
      context: context,
      title: "\$${expanse.expenseTotal.toStringAsFixed(2)}",
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Symbols.edit),
              title: const Text("Update Expense"),
              subtitle: const Text("Beddel kharashkan"),
              onTap: () {
                Navigator.pop(sheetContext);
                _updateExpanse(expanse);
              },
            ),
            ListTile(
              leading: Icon(
                Symbols.delete,
                color: Theme.of(sheetContext).colorScheme.error,
              ),
              title: Text(
                "Delete Expense",
                style: TextStyle(
                  color: Theme.of(sheetContext).colorScheme.error,
                ),
              ),
              subtitle: const Text("Ka saar kharashkan"),
              onTap: () {
                Navigator.pop(sheetContext);
                _deleteExpanse(expanse);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _updateExpanse(ExpanseModel expanse) async {
    await showNotImplementedDialog(context: context);
  }

  Future<void> _deleteExpanse(ExpanseModel expanse) async {
    await showNotImplementedDialog(context: context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Expanses"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: ReportBasedWidget(selectedDateRange: selectedDateRange),
        ),
        actions: [
          TextButton.icon(
            onPressed: _pickDateRange,
            icon: const Icon(Symbols.date_range),
            label: const Text("Pick date"),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildTypeFilter(),
            Expanded(
              child: FutureBuilder<List<ExpanseModel>>(
                future: expansesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingWidget();
                  }

                  if (snapshot.hasError) {
                    return ErrorRetryWidget(
                      errorMessage: snapshot.error.toString(),
                      onRetry: _reload,
                    );
                  }

                  final expanses = snapshot.data ?? const <ExpanseModel>[];

                  if (expanses.isEmpty) return _buildEmpty();

                  return _buildList(expanses);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          _buildTypeChip(label: "All", type: null),
          for (final type in ExpanseType.values) ...[
            const SizedBox(width: 8),
            _buildTypeChip(label: type.label, type: type),
          ],
        ],
      ),
    );
  }

  Widget _buildTypeChip({required String label, required ExpanseType? type}) {
    return ChoiceChip(
      label: Text(label),
      avatar: type == null ? null : Icon(type.iconData, size: 18),
      selected: selectedType == type,
      onSelected: (_) => _selectType(type),
    );
  }

  Widget _buildList(List<ExpanseModel> expanses) {
    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        await expansesFuture;
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: expanses.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == 0) return _buildTotal(expanses);

          final expanse = expanses[index - 1];

          return ExpanseCardWidget(
            expanse: expanse,
            onTap: () => _openExpanseActions(expanse),
          );
        },
      ),
    );
  }

  /// What the days on screen came to, counted from the rows themselves.
  Widget _buildTotal(List<ExpanseModel> expanses) {
    final theme = Theme.of(context);
    final total = expanses.fold<double>(
      0,
      (sum, expanse) => sum + expanse.expenseTotal,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          theme.colorScheme.primary.withValues(alpha: 0.12),
          theme.colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Symbols.receipt_long, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Wadarta kharashaadka", style: theme.textTheme.bodyMedium),
                const SizedBox(height: 2),
                Text(
                  "${expanses.length} kharash",
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            "\$${total.toStringAsFixed(2)}",
            style: theme.textTheme.headlineLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.receipt_long,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              "No expenses on these days",
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              "Pick another date, or another type, to see more.",
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _pickDateRange,
              icon: const Icon(Symbols.date_range),
              label: const Text("Pick date"),
            ),
          ],
        ),
      ),
    );
  }
}
