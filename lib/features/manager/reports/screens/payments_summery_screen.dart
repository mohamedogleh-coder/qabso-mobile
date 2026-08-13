import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/features/manager/reports/models/payments_summery_model.dart';

import '../../../../utill/app_constants.dart';
import '../../../../utill/error_widget.dart';
import '../../../../utill/loading_widget.dart';
import '../../stadium/stadium_notifier_provider.dart';
import '../reports_repository.dart';
import '../widgets/merchant_row_widget.dart';
import '../widgets/report_based_widget.dart';

class PaymentsSummeryScreen extends ConsumerStatefulWidget {
  const PaymentsSummeryScreen({super.key});

  @override
  ConsumerState<PaymentsSummeryScreen> createState() =>
      _PaymentsSummeryScreenState();
}

class _PaymentsSummeryScreenState extends ConsumerState<PaymentsSummeryScreen> {
  late DateTimeRange selectedDateRange;
  late Future<PaymentsSummeryModel> merchantsFuture;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    selectedDateRange = DateTimeRange(start: now, end: now);
    merchantsFuture = _fetchMerchantsSummery();
  }

  Future<PaymentsSummeryModel> _fetchMerchantsSummery() async {
    final stadium = ref.read(stadiumNotifierProvider).value;

    if (stadium?.stadiumId == null) {
      throw StateError('No stadium was found for this manager.');
    }

    return ReportsRepository.paymentsSummery(
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
      merchantsFuture = _fetchMerchantsSummery();
    });
  }

  void _reload() {
    setState(() {
      merchantsFuture = _fetchMerchantsSummery();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Payments Summery"),
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
        child: FutureBuilder<PaymentsSummeryModel>(
          future: merchantsFuture,
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

            final summary = snapshot.data;

            if (summary == null || _movedNothing(summary)) {
              return _buildEmpty();
            }

            return _buildSummery(summary);
          },
        ),
      ),
    );
  }

  bool _movedNothing(PaymentsSummeryModel summary) {
    return summary.totalPayments == 0 &&
        summary.totalRefunds == 0 &&
        summary.totalExpenses == 0 &&
        summary.totalDiscounts == 0;
  }

  Widget _buildSummery(PaymentsSummeryModel summary) {
    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        await merchantsFuture;
      },
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _buildTotals(summary),
          const SizedBox(height: 20),
          _buildSectionTitle("Where the money is"),
          const SizedBox(height: 8),
          for (final merchant in summary.merchants) ...[
            MerchantRowWidget(model: merchant),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildTotals(PaymentsSummeryModel summary) {
    const spacing = 8.0;
    final totals = [
      (
        Symbols.payments,
        "Payments",
        summary.totalPayments,
        AppConstants.success,
      ),
      (
        Symbols.percent,
        "Discounts",
        summary.totalDiscounts,
        AppConstants.warning,
      ),
      (Symbols.undo, "Refunds", summary.totalRefunds, AppConstants.tertiary),
      (
        Symbols.receipt_long,
        "Expanses",
        summary.totalExpenses,
        AppConstants.error,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 420 ? 2 : 4;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final total in totals)
              SizedBox(
                width: width,
                child: _buildTotalTile(
                  iconData: total.$1,
                  label: total.$2,
                  amount: total.$3,
                  color: total.$4,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTotalTile({
    required IconData iconData,
    required String label,
    required double amount,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          color.withValues(alpha: 0.18),
          theme.colorScheme.surface,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(iconData, color: color, size: 20),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              "\$${amount.toStringAsFixed(2)}",
              style: theme.textTheme.titleLarge!.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Text(
            label,
            style: theme.textTheme.bodySmall!.copyWith(color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.bold),
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
              Symbols.savings,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              "No money moved on these days",
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              "Pick another date to see an earlier report.",
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
