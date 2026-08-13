import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/features/manager/reports/reports_repository.dart';
import 'package:qabso_mobile/features/manager/stadium/stadium_notifier_provider.dart';
import 'package:qabso_mobile/utill/app_constants.dart';

import '../../../../utill/app_date_util.dart';
import '../../../../utill/error_widget.dart';
import '../../../../utill/loading_widget.dart';
import '../models/event_summery_model.dart';
import '../widgets/event_summery_card_widget.dart';

class EventsSummeryScreen extends ConsumerStatefulWidget {
  const EventsSummeryScreen({super.key});

  @override
  ConsumerState<EventsSummeryScreen> createState() =>
      _EventsSummeryScreenState();
}

class _EventsSummeryScreenState extends ConsumerState<EventsSummeryScreen> {
  late DateTimeRange selectedDateRange;
  late Future<List<EventsSummaryModel>> eventsFuture;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    selectedDateRange = DateTimeRange(start: now, end: now);
    eventsFuture = _fetchEventsSummery();
  }

  Future<List<EventsSummaryModel>> _fetchEventsSummery() async {
    final stadium = ref.read(stadiumNotifierProvider).value;

    if (stadium?.stadiumId == null) {
      throw StateError('No stadium was found for this manager.');
    }

    return ReportsRepository.eventsSummery(
      stadiumId: stadium!.stadiumId,
      startDate: selectedDateRange.start,
      endDate: selectedDateRange.end,
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
      eventsFuture = _fetchEventsSummery();
    });
  }

  void _reload() {
    setState(() {
      eventsFuture = _fetchEventsSummery();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Events Summery"),
        actions: [
          TextButton.icon(
            onPressed: _pickDateRange,
            icon: const Icon(Symbols.date_range),
            label: Text("Pick date"),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: _buildDateRangeBar(),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<List<EventsSummaryModel>>(
          future: eventsFuture,
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
            final summaries = snapshot.data ?? [];

            if (summaries.isEmpty) {
              return _buildEmpty();
            }
            return _buildList(summaries);
          },
        ),
      ),
    );
  }

  Widget _buildDateRangeBar() {
    final theme = Theme.of(context);
    return InkWell(
      onTap: _pickDateRange,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Row(
          children: [
            const Text("Report based on"),
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                children: [
                  Icon(
                    Symbols.calendar_month,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _dateRangeLabel(),
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _dateRangeLabel() {
    final start = AppDateUtil.formatDate(
      selectedDateRange.start,
      pattern: 'dd MMM yyyy',
    );
    final end = AppDateUtil.formatDate(
      selectedDateRange.end,
      pattern: 'dd MMM yyyy',
    );

    return start == end
        ? (start ==
                  AppDateUtil.formatDate(DateTime.now(), pattern: 'dd MMM yyyy')
              ? "Today"
              : start)
        : "$start  -  $end";
  }

  Widget _buildList(List<EventsSummaryModel> summaries) {
    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        await eventsFuture;
      },
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: summaries.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            EventsSummeryCardWidget(model: summaries[index]),
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
              Symbols.grass,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              "This stadium has no fields yet",
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              "Add a field to see its events here.",
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                Navigator.pushNamed(context, AppConstants.fields);
              },
              label: Text("Add Fields"),
            ),
          ],
        ),
      ),
    );
  }
}
