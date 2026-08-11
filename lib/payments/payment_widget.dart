import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/payments/payment_notifier_provider.dart';
import 'package:qabso_mobile/payments/payment_result.dart';

import '../features/manager/merchants/merchant_notifier_provider.dart';
import '../features/manager/merchants/stadium_merchant_model.dart';
import '../utill/app_dailogs.dart';
import '../utill/app_input_text_widget.dart';
import '../utill/error_widget.dart';
import '../utill/loading_widget.dart';

/// Collects a payment of [requiredAmount] in the app's shared bottom sheet
/// and resolves with the settled [PaymentResult], or null if the user backed
/// out.
///
/// The caller decides what happens next — this only collects and validates:
///
/// ```dart
/// final payment = await showPaymentSheet(context: context, requiredAmount: 30);
/// if (payment != null) {
///   // hand payment.allocations to the transaction repository
/// }
/// ```
Future<PaymentResult?> showPaymentSheet({
  required BuildContext context,
  required double requiredAmount,
  String title = "Payment",
  String confirmText = "Pay",
  bool allowDiscount = true,
}) {
  return showAppBottomSheet<PaymentResult>(
    context: context,
    title: title,
    builder: (sheetContext) => SafeArea(
      child: PaymentWidget(
        requiredAmount: requiredAmount,
        confirmText: confirmText,
        allowDiscount: allowDiscount,
        onCancel: () => Navigator.pop(sheetContext),
        onSubmit: (payment) => Navigator.pop(sheetContext, payment),
      ),
    ),
  );
}

/// Splits [requiredAmount] across the stadium's registered merchants and
/// cash, and hands the settled split to [onSubmit].
///
/// Generic on purpose: it knows amounts and the methods they went through,
/// nothing about bookings or expenses, so the same widget serves a customer
/// payment, a stadium expense, or any later transaction type. It performs no
/// database work — [onSubmit] only ever fires with a fully settled payment,
/// and the parent takes it from there.
///
/// [requiredAmount] is carried into [paymentNotifierProvider] by scoping it
/// here, so the form never seeds provider state from a widget life-cycle.
class PaymentWidget extends StatelessWidget {
  const PaymentWidget({
    super.key,
    required this.requiredAmount,
    required this.onSubmit,
    this.onCancel,
    this.confirmText = "Pay",
    this.allowDiscount = true,
    this.isSubmitting = false,
  });

  final double requiredAmount;

  /// Called with the finished payment, and only ever when it is valid and
  /// fully settled (`remaining == 0`).
  final ValueChanged<PaymentResult> onSubmit;

  /// Shows a cancel action when provided; omitted, the button is hidden.
  final VoidCallback? onCancel;

  final String confirmText;

  /// Money going out — expenses and refunds — cannot be discounted, which
  /// `chk_discount_only_on_payment` enforces. Pass false to hide the field.
  final bool allowDiscount;

  /// Lets the parent lock the form while it does the actual submitting.
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        paymentNotifierProvider.overrideWith(
          () => PaymentNotifier(requiredAmount),
        ),
      ],
      child: _PaymentForm(
        onSubmit: onSubmit,
        onCancel: onCancel,
        confirmText: confirmText,
        allowDiscount: allowDiscount,
        isSubmitting: isSubmitting,
      ),
    );
  }
}

class _PaymentForm extends ConsumerStatefulWidget {
  const _PaymentForm({
    required this.onSubmit,
    required this.onCancel,
    required this.confirmText,
    required this.allowDiscount,
    required this.isSubmitting,
  });

  final ValueChanged<PaymentResult> onSubmit;
  final VoidCallback? onCancel;
  final String confirmText;
  final bool allowDiscount;
  final bool isSubmitting;

  @override
  ConsumerState<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends ConsumerState<_PaymentForm> {
  PaymentNotifier get _notifier => ref.read(paymentNotifierProvider.notifier);

  static double _parseAmount(String value) =>
      double.tryParse(value.trim()) ?? 0;

  /// Keeps exact zero from rendering as "-0.00" when the arithmetic lands a
  /// hair below it.
  static String _money(double value) {
    final amount = value.abs() < 0.005 ? 0.0 : value;

    return "\$${amount.toStringAsFixed(2)}";
  }

  void _handleSubmit(PaymentResult payment) {
    if (widget.isSubmitting || !payment.canSubmit) return;

    widget.onSubmit(payment);
  }

  @override
  Widget build(BuildContext context) {
    final payment = ref.watch(paymentNotifierProvider);
    final merchantsAsync = ref.watch(merchantNotifierProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummarySection(payment),
          const SizedBox(height: 12),
          merchantsAsync.when(
            data: (merchants) => _buildMethodsSection(payment, merchants),
            error: (error, stackTrace) => ErrorRetryWidget(
              errorMessage: error.toString(),
              onRetry: () =>
                  ref.read(merchantNotifierProvider.notifier).refresh(),
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: LoadingWidget(),
            ),
          ),
          const SizedBox(height: 16),
          _buildActions(payment),
        ],
      ),
    );
  }

  /// The bordered group shared by both sections, so the summary and the
  /// methods read as two halves of one form.
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

  Widget _buildSummarySection(PaymentResult payment) {
    final theme = Theme.of(context);

    return _buildSection(
      icon: Symbols.receipt_long,
      title: "Payment Summary",
      child: Column(
        children: [
          _buildAmountRow(
            label: "Total Required",
            amount: payment.requiredAmount,
          ),
          if (widget.allowDiscount) ...[
            const SizedBox(height: 8),
            _buildDiscountRow(payment),
          ],
          const SizedBox(height: 8),
          _buildAmountRow(
            label: "Total Paid",
            amount: payment.totalPaid,
            valueColor: theme.colorScheme.primary,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          _buildRemainingRow(payment),
        ],
      ),
    );
  }

  Widget _buildAmountRow({
    required String label,
    required double amount,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Text(
          _money(amount),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDiscountRow(PaymentResult payment) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(child: Text("Discount", style: theme.textTheme.bodyMedium)),
        SizedBox(
          width: 130,
          child: _buildAmountField(
            initial: payment.discount,
            enabled: !widget.isSubmitting,
            onChanged: (v) => _notifier.setDiscount(_parseAmount(v)),
            validator: (v) {
              final discount = _parseAmount(v ?? '');
              if (discount < 0) return "Invalid";
              if (discount > payment.requiredAmount) return "Too high";
              return null;
            },
          ),
        ),
      ],
    );
  }

  /// The line that tells the manager whether they can submit: the amount
  /// left, coloured, with a status chip so the state reads at a glance.
  Widget _buildRemainingRow(PaymentResult payment) {
    final theme = Theme.of(context);

    final (label, color) = switch (payment) {
      _ when payment.isOverpaid => ("Overpaid", theme.colorScheme.error),
      _ when payment.isSettled => ("Paid", theme.colorScheme.primary),
      _ => ("Unpaid", theme.colorScheme.error),
    };

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Text("Remaining", style: theme.textTheme.headlineMedium),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        Text(
          _money(payment.remaining),
          style: theme.textTheme.headlineLarge?.copyWith(color: color),
        ),
      ],
    );
  }

  Widget _buildMethodsSection(
    PaymentResult payment,
    List<StadiumMerchantModel> merchants,
  ) {
    final theme = Theme.of(context);

    return _buildSection(
      icon: Symbols.account_balance_wallet,
      title: "Payment Methods",
      child: Column(
        children: [
          for (final merchant in merchants) ...[
            _buildMethodRow(
              payment: payment,
              merchant: merchant,
              title: merchant.merchantNumber,
              subtitle:
                  "${merchant.provider.providerName} · "
                  "${merchant.provider.providerService}",
            ),
            const SizedBox(height: 8),
          ],
          if (merchants.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                "Garoonku ma laha merchant numbers — lacagta caddaanka ah "
                "ayaa kaliya la qaadi karaa.",
                style: theme.textTheme.bodySmall,
              ),
            ),
          // Cash always stands as a method: it needs no merchant, and it is
          // the only one left when none are registered.
          _buildMethodRow(
            payment: payment,
            merchant: null,
            title: "Cash",
            subtitle: "Lacag caddaan ah",
          ),
        ],
      ),
    );
  }

  Widget _buildMethodRow({
    required PaymentResult payment,
    required StadiumMerchantModel? merchant,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    final amount = payment.amountFor(merchant);

    return Row(
      children: [
        Icon(
          merchant == null
              ? Symbols.account_balance_wallet
              : Symbols.account_balance_wallet_sharp,

          size: 20,
          fill: amount > 0 ? 1 : 0,
          color: amount > 0
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 3,
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
                subtitle,
                style: theme.textTheme.labelMedium,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: _buildAmountField(
            key: ValueKey(merchant?.id ?? 'cash'),
            initial: amount,
            enabled: !widget.isSubmitting,
            onChanged: (v) => _notifier.setAmount(
              merchant: merchant,
              amount: _parseAmount(v),
            ),
            validator: (v) {
              final value = v?.trim() ?? '';
              if (value.isEmpty) return null;
              if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) {
                return "Qiimo sax ah";
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAmountField({
    Key? key,
    required double initial,
    required bool enabled,
    required ValueChanged<String> onChanged,
    required FormFieldValidator<String> validator,
  }) {
    return AppInputTextWidget(
      key: key,
      hintText: "0.00",
      value: initial > 0 ? initial.toString() : '',
      enabled: enabled,
      capitalize: false,
      verticalPadding: 8,
      errorFontSize: 11,
      prefixIcon: Symbols.attach_money,
      filledColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      onChanged: onChanged,
      validator: validator,
    );
  }

  Widget _buildActions(PaymentResult payment) {
    return Row(
      children: [
        if (widget.onCancel != null) ...[
          Expanded(
            flex: 2,
            child: OutlinedButton(
              onPressed: widget.isSubmitting ? null : widget.onCancel,
              child: const Text("Cancel"),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          flex: 3,
          child: FilledButton.icon(
            onPressed: payment.canSubmit && !widget.isSubmitting
                ? () => _handleSubmit(payment)
                : null,
            icon: widget.isSubmitting
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Symbols.check),
            label: Text(widget.confirmText),
          ),
        ),
      ],
    );
  }
}
