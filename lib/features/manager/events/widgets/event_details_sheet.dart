import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../utill/app_constants.dart';
import '../../../../utill/app_dailogs.dart';
import '../../../../utill/app_date_util.dart';
import '../../../../utill/error_widget.dart';
import '../../../../utill/loading_widget.dart';
import '../event_repository.dart';
import '../event_status_style.dart';
import '../models/event_details_model.dart';

/// The whole record of one booking: where it is played, when, what it came to,
/// and every payment taken for it.
///
/// Opened with nothing but a booking id, so any screen can show it:
///
/// ```dart
/// await EventDetailsSheet.show(context, eventId: 42);
/// ```
///
/// Who is allowed to see it is settled by the database, not here. A customer
/// gets a booking their own money is on, and a manager gets every booking on
/// their stadium.
class EventDetailsSheet extends StatefulWidget {
  final int eventId;

  const EventDetailsSheet({super.key, required this.eventId});

  /// Opens the sheet over [context].
  static Future<void> show(BuildContext context, {required int eventId}) {
    return showAppBottomSheet<void>(
      context: context,
      // title: "Faahfaahinta bookingka",
      builder: (sheetContext) => EventDetailsSheet(eventId: eventId),
    );
  }

  @override
  State<EventDetailsSheet> createState() => _EventDetailsSheetState();
}

class _EventDetailsSheetState extends State<EventDetailsSheet> {
  /// Held in state rather than built in `build`: a future created inline would
  /// re-read on every rebuild.
  late Future<EventDetailsModel> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _fetchDetails();
  }

  Future<EventDetailsModel> _fetchDetails() =>
      EventRepository.getEventDetails(eventId: widget.eventId);

  void _reload() {
    setState(() {
      _detailsFuture = _fetchDetails();
    });
  }

  static String _money(double value) => "\$${value.toStringAsFixed(2)}";

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EventDetailsModel>(
      future: _detailsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: LoadingWidget(),
          );
        }

        if (snapshot.hasError) {
          final error = snapshot.error;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: ErrorRetryWidget(
              errorMessage: error is PostgrestException
                  ? error.message
                  : error.toString(),
              onRetry: _reload,
            ),
          );
        }

        final details = snapshot.data;
        if (details == null) return const SizedBox.shrink();

        return _buildDetails(details);
      },
    );
  }

  Widget _buildDetails(EventDetailsModel details) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(details),
          const SizedBox(height: 16),
          _buildWhenAndWhat(details),
          const Divider(height: 32),
          _buildBooking(details),
          const Divider(height: 32),
          _buildReceipt(details),
        ],
      ),
    );
  }

  /// The stadium and the state of the booking, with the way out on the right.
  Widget _buildHeader(EventDetailsModel details) {
    final theme = Theme.of(context);
    final color = details.eventStatus.color;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Symbols.stadium,
            color: Colors.white,
            fill: 1,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                details.stadiumName,
                style: theme.textTheme.headlineLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                details.eventStatus.label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: () => Navigator.pop(context),
          tooltip: "Xir",
          icon: const Icon(Symbols.close),
        ),
      ],
    );
  }

  /// When the game is and what the slot costs, as one strip. The three facts
  /// asked first, answered before any reading.
  Widget _buildWhenAndWhat(EventDetailsModel details) {
    return _buildStatStrip([
      _buildStat(
        icon: Symbols.calendar_month,
        label: "Taariikhda",
        value: AppDateUtil.formatDate(details.eventStart, pattern: 'dd MMM'),
      ),
      _buildStat(
        icon: Symbols.schedule,
        label: "Waqtiga",
        value: AppDateUtil.formatSlot(details.eventStart, details.eventEnd),
      ),
      _buildStat(
        icon: Symbols.payments,
        label: "Qiimaha",
        value: _money(details.slotPrice),
      ),
    ]);
  }

  // ---------------------------------------------------------------------
  // The booking
  // ---------------------------------------------------------------------

  /// The rest of what the booking is made of, under the strip that already
  /// gave its day, its hour and its price.
  Widget _buildBooking(EventDetailsModel details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          icon: Symbols.event,
          title: "Macluumaadka bookingka",
        ),
        const SizedBox(height: 12),
        _buildFactRow(
          label: "Field-ka",
          value: "#${details.fieldId} · ${details.capacity} ciyaartoy",
        ),
        _buildFactRow(
          label: "Qiimaha ciyaartoyga",
          value: _money(details.cost),
        ),
        if (details.extraTime > 0)
          _buildFactRow(
            label: "Waqti dheeraad ah",
            value: "${details.extraTime} daqiiqo",
          ),
        if (details.isPrivate)
          _buildFactRow(label: "Code-ka gaarka ah", value: details.eventKey!),
        if (details.cancelledAt != null)
          _buildFactRow(
            label: "Waa la joojiyay",
            value: AppDateUtil.formatDateTime(details.cancelledAt!),
            valueColor: AppConstants.error,
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // The receipt
  // ---------------------------------------------------------------------

  /// Every payment and refund taken on the booking, then what they come to.
  ///
  /// The movements read in the order they happened, and the totals sit in
  /// their own block at the end, the way the matched field is set apart on
  /// the stadium sheet.
  Widget _buildReceipt(EventDetailsModel details) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(icon: Symbols.receipt_long, title: "Rasiidka"),
        const SizedBox(height: 12),
        if (details.transactions.isEmpty) _buildNoPayments(),
        for (var index = 0; index < details.transactions.length; index++) ...[
          if (index > 0) const Divider(height: 24),
          _buildTransaction(details.transactions[index]),
        ],
        if (details.discounted > 0 || details.refunded > 0) ...[
          const SizedBox(height: 16),
          if (details.discounted > 0)
            _buildFactRow(
              label: "Qiimo dhimis",
              value: "-${_money(details.discounted)}",
              valueColor: AppConstants.warning,
            ),
          if (details.refunded > 0)
            _buildFactRow(
              label: "Lacagta la celiyay",
              value: "-${_money(details.refunded)}",
              valueColor: AppConstants.error,
            ),
        ],
        const SizedBox(height: 16),
        _buildTotals(details),
      ],
    );
  }

  Widget _buildNoPayments() {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          Symbols.receipt,
          size: 18,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            "Lacag bixin lama helin bookingkan.",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }

  /// One movement of money: what it was, when, who it came from, and the
  /// merchant numbers it was split across.
  Widget _buildTransaction(EventTransactionModel transaction) {
    final theme = Theme.of(context);

    final color = transaction.isRefund
        ? AppConstants.error
        : AppConstants.success;

    final amount = transaction.isRefund
        ? "-${_money(transaction.settled)}"
        : _money(transaction.settled);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 34,
              width: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                transaction.isRefund ? Symbols.undo : Symbols.check,
                size: 18,
                fill: 1,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transaction.isRefund ? "Lacag celin" : "Lacag bixin",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    AppDateUtil.formatDateTime(transaction.transactionDate),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              amount,
              style: theme.textTheme.headlineMedium?.copyWith(color: color),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildPayer(transaction),
        if (transaction.hasDiscount) ...[
          const SizedBox(height: 6),
          _buildNote(
            Symbols.sell,
            "Qiimo dhimis ${_money(transaction.discounted)}",
          ),
        ],
        for (final payment in transaction.details) ...[
          const SizedBox(height: 8),
          _buildPaymentRow(payment),
        ],
      ],
    );
  }

  /// Who the money came from, and the number to reach them on.
  Widget _buildPayer(EventTransactionModel transaction) {
    final theme = Theme.of(context);
    final phone = transaction.paidUserPhone;

    return Padding(
      padding: const EdgeInsets.only(left: 46),
      child: Row(
        children: [
          Icon(
            Symbols.person,
            size: 16,
            fill: 1,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              transaction.paidUserName != null
                  ? "Waxaa bixiyay ${transaction.payerName}"
                  : "Waxaa qaatay ${transaction.payerName}",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (phone != null) ...[
            const SizedBox(width: 8),
            Text(phone, style: theme.textTheme.labelMedium),
          ],
        ],
      ),
    );
  }

  Widget _buildNote(IconData icon, String text) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 46),
      child: Row(
        children: [
          Icon(icon, size: 16, fill: 1, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One portion of a transaction — cash, or a merchant number it went to.
  Widget _buildPaymentRow(EventPaymentModel payment) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(left: 46),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            payment.isCash ? Symbols.payments : Symbols.account_balance_wallet,
            size: 18,
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
                  style: theme.textTheme.bodySmall?.copyWith(
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
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// What the booking came to, set apart in its own block because it is the
  /// answer a manager opens this sheet for.
  Widget _buildTotals(EventDetailsModel details) {
    final theme = Theme.of(context);

    final remainingColor = details.hasRemaining
        ? AppConstants.warning
        : AppConstants.success;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: .3),
        ),
      ),
      child: _buildStatStrip([
        _buildStat(
          icon: Symbols.receipt_long,
          label: "Wadarta",
          value: _money(details.billedAmount),
        ),
        _buildStat(
          icon: Symbols.check_circle,
          label: "La bixiyay",
          value: _money(details.paidAmount),
        ),
        _buildStat(
          icon: Symbols.account_balance_wallet,
          label: "Hadhay",
          value: _money(details.remaining),
          valueColor: remainingColor,
        ),
      ]),
    );
  }

  // ---------------------------------------------------------------------
  // Shared pieces
  // ---------------------------------------------------------------------

  Widget _buildSectionTitle({required IconData icon, required String title}) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 18, color: theme.colorScheme.primary),
      ],
    );
  }

  /// The facts share the width evenly, so the strip fits any phone without
  /// wrapping.
  Widget _buildStatStrip(List<Widget> stats) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var index = 0; index < stats.length; index++) ...[
          if (index > 0)
            Container(width: 1, height: 40, color: theme.dividerColor),
          Expanded(child: stats[index]),
        ],
      ],
    );
  }

  Widget _buildStat({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, fill: 1, color: theme.colorScheme.primary),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildFactRow({
    required String label,
    required String value,
    Color? valueColor,
  }) {
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
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
