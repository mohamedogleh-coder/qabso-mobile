import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../utill/app_date_util.dart';
import '../../../utill/error_widget.dart';
import '../../../utill/loading_widget.dart';
import 'expanse_card_widget.dart';
import 'expanse_receipt_model.dart';
import 'expanse_repository.dart';

/// The full record of one expense, read fresh so it shows what the database
/// holds now rather than what the list was showing.
class ExpanseReceiptWidget extends StatefulWidget {
  final int expenseId;

  const ExpanseReceiptWidget({super.key, required this.expenseId});

  @override
  State<ExpanseReceiptWidget> createState() => _ExpanseReceiptWidgetState();
}

class _ExpanseReceiptWidgetState extends State<ExpanseReceiptWidget> {
  /// Held in state rather than built in `build`: a future created inline would
  /// re-read on every rebuild.
  late Future<ExpanseReceiptModel> _receiptFuture;

  @override
  void initState() {
    super.initState();
    _receiptFuture = _fetchReceipt();
  }

  Future<ExpanseReceiptModel> _fetchReceipt() =>
      ExpanseRepository.getExpanseReceipt(expenseId: widget.expenseId);

  void _reload() {
    setState(() {
      _receiptFuture = _fetchReceipt();
    });
  }

  static String _money(double value) => "\$${value.toStringAsFixed(2)}";

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ExpanseReceiptModel>(
      future: _receiptFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: LoadingWidget(),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: ErrorRetryWidget(
              errorMessage: snapshot.error.toString(),
              onRetry: _reload,
            ),
          );
        }

        final receipt = snapshot.data;
        if (receipt == null) return const SizedBox.shrink();

        return _buildReceipt(receipt);
      },
    );
  }

  Widget _buildReceipt(ExpanseReceiptModel receipt) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(receipt),
          const SizedBox(height: 16),
          _buildFacts(receipt),
          const SizedBox(height: 16),
          _buildPayments(receipt),
        ],
      ),
    );
  }

  /// The amount and the kind, which is what a receipt is looked at for.
  Widget _buildHeader(ExpanseReceiptModel receipt) {
    final theme = Theme.of(context);
    final color = receipt.expanseType.color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Color.alphaBlend(
          color.withValues(alpha: 0.12),
          theme.colorScheme.surface,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  receipt.expanseType.iconData,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  receipt.expanseType.label,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                _money(receipt.expenseTotal),
                style: theme.textTheme.headlineLarge?.copyWith(color: color),
              ),
            ],
          ),
          if ((receipt.description ?? '').isNotEmpty) ...[
            const Divider(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                receipt.description!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFacts(ExpanseReceiptModel receipt) {
    return _buildSection(
      icon: Symbols.info,
      title: "Macluumaadka",
      child: Column(
        children: [
          _buildFactRow(
            label: "Taariikhda kharashka",
            value: AppDateUtil.formatReadableDate(receipt.expenseDate),
          ),
          if (receipt.transactionDate != null)
            _buildFactRow(
              label: "Lacagta waxa la bixiyay",
              value: AppDateUtil.formatDateTime(receipt.transactionDate!),
            ),
          if (receipt.processedByName != null)
            _buildFactRow(
              label: "Waxaa bixiyay",
              value: receipt.processedByName!,
            ),
          if (receipt.processedByPhone != null)
            _buildFactRow(label: "Taleefan", value: receipt.processedByPhone!),
          if (receipt.updatedAt != null)
            _buildFactRow(
              label: "Markii ugu dambeysay ee la beddelay",
              value: AppDateUtil.formatDateTime(receipt.updatedAt!),
            ),
        ],
      ),
    );
  }

  Widget _buildPayments(ExpanseReceiptModel receipt) {
    final theme = Theme.of(context);
    final payments = receipt.payments;

    return _buildSection(
      icon: Symbols.account_balance_wallet,
      title: "Meesha lacagtu ka baxday",
      child: Column(
        children: [
          if (payments.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Lacag bixin lama helin kharashkan.",
                style: theme.textTheme.bodySmall,
              ),
            ),
          for (final payment in payments) ...[
            _buildPaymentRow(payment),
            const SizedBox(height: 10),
          ],
          if (payments.isNotEmpty) ...[
            const Divider(height: 8),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Wadarta", style: theme.textTheme.headlineMedium),
                Text(
                  _money(
                    payments.fold<double>(
                      0,
                      (sum, payment) => sum + payment.amountPaid,
                    ),
                  ),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentRow(ExpansePaymentModel payment) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          payment.isCash ? Symbols.payments : Symbols.account_balance_wallet,
          size: 20,
          fill: 1,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                payment.methodName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!payment.isCash) ...[
                const SizedBox(height: 2),
                Text(
                  [
                    payment.merchantNumber,
                    payment.providerName,
                  ].where((part) => part != null).join(" · "),
                  style: theme.textTheme.labelMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _money(payment.amountPaid),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildFactRow({required String label, required String value}) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The bordered group both halves share, the same one the payment sheet
  /// uses, so a receipt and a payment read alike.
  Widget _buildSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(title, style: theme.textTheme.headlineMedium),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}
