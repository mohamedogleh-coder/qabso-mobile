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
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSheetTitle(),
          const SizedBox(height: 16),
          _buildBooking(details),
          const SizedBox(height: 16),
          _buildReceipt(details),
        ],
      ),
    );
  }

  Widget _buildSheetTitle() {
    final theme = Theme.of(context);

    return Row(
      children: [
        IconButton.outlined(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Symbols.close),
        ),
        const SizedBox(width: 12),
        Text("Faahfaahinta bookingka", style: theme.textTheme.headlineMedium),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // The booking
  // ---------------------------------------------------------------------

  /// Where the game is played, when, and what it costs.
  ///
  /// It opens with the stadium, the state of the booking and the price of the
  /// slot, so the three things asked first are answered before any reading.
  /// The facts below fill in the rest.
  Widget _buildBooking(EventDetailsModel details) {
    final theme = Theme.of(context);

    return _buildSection(
      icon: Symbols.stadium,
      accent: theme.colorScheme.primary,
      title: "Macluumaadka bookingka",
      child: Column(
        children: [
          _buildStadiumRow(details),
          const Divider(height: 24),
          _buildFactRow(
            icon: Symbols.calendar_month,
            label: "Taariikhda",
            value: AppDateUtil.formatReadableDate(details.eventStart),
          ),
          _buildFactRow(
            icon: Symbols.schedule,
            label: "Waqtiga",
            value: AppDateUtil.formatSlot(details.eventStart, details.eventEnd),
          ),
          if (details.extraTime > 0)
            _buildFactRow(
              icon: Symbols.more_time,
              label: "Waqti dheeraad ah",
              value: "${details.extraTime} daqiiqo",
            ),
          _buildFactRow(
            icon: Symbols.person,
            label: "Qiimaha ciyaartoyga",
            value: _money(details.cost),
          ),
          if (details.isPrivate)
            _buildFactRow(
              icon: Symbols.lock,
              label: "Code-ka gaarka ah",
              value: details.eventKey!,
            ),
          if (details.cancelledAt != null)
            _buildFactRow(
              icon: Symbols.cancel,
              label: "Waa la joojiyay",
              value: AppDateUtil.formatDateTime(details.cancelledAt!),
              valueColor: AppConstants.error,
            ),
        ],
      ),
    );
  }

  /// The stadium, the state of the booking, the field it is on, and the price
  /// of the whole slot.
  Widget _buildStadiumRow(EventDetailsModel details) {
    final theme = Theme.of(context);
    final color = details.eventStatus.color;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      details.stadiumName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusPill(color, details.eventStatus.label),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                "Field #${details.fieldId} · ${details.capacity} ciyaartoy",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _money(details.slotPrice),
          style: theme.textTheme.headlineLarge?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusPill(Color color, String label) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // The receipt
  // ---------------------------------------------------------------------

  /// Every payment and refund taken on the booking, then what they come to.
  ///
  /// It is laid out like a paper receipt: the movements in the order they
  /// happened, a rule, then the totals. What is still owed is the last line,
  /// because it is the one a manager is looking for.
  Widget _buildReceipt(EventDetailsModel details) {
    final theme = Theme.of(context);
    final transactions = details.transactions;

    return _buildSection(
      icon: Symbols.receipt_long,
      accent: theme.colorScheme.tertiary,
      title: "Rasiidka",
      child: Column(
        children: [
          if (transactions.isEmpty) _buildNoPayments(),
          for (var index = 0; index < transactions.length; index++) ...[
            if (index > 0) const Divider(height: 24),
            _buildTransaction(transactions[index]),
          ],
          const Divider(height: 28, thickness: 1),
          _buildTotals(details),
        ],
      ),
    );
  }

  Widget _buildNoPayments() {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          Symbols.receipt,
          size: 20,
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
            _buildRoundIcon(
              transaction.isRefund ? Symbols.undo : Symbols.check,
              color,
            ),
            const SizedBox(width: 10),
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
                    style: theme.textTheme.labelMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              amount,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
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
      padding: const EdgeInsets.only(left: 42),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            transaction.paidUserName != null
                ? "Waxaa bixiyay ${transaction.payerName}"
                : "Waxaa qaatay ${transaction.payerName}",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (phone != null) ...[
            const SizedBox(height: 2),
            Text(phone, style: theme.textTheme.labelMedium),
          ],
        ],
      ),
    );
  }

  Widget _buildNote(IconData icon, String text) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(left: 42),
      child: Row(
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
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
      margin: const EdgeInsets.only(left: 42),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
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

  /// What the booking came to, and where it stands now.
  Widget _buildTotals(EventDetailsModel details) {
    final theme = Theme.of(context);

    return Column(
      children: [
        _buildFactRow(
          label: "Wadarta lacagta",
          value: _money(details.billedAmount),
        ),
        if (details.discounted > 0)
          _buildFactRow(
            label: "Qiimo dhimis",
            value: "-${_money(details.discounted)}",
            valueColor: AppConstants.warning,
          ),
        _buildFactRow(
          label: "Lacagta la bixiyay",
          value: _money(details.paidAmount),
        ),
        if (details.refunded > 0)
          _buildFactRow(
            label: "Lacagta la celiyay",
            value: "-${_money(details.refunded)}",
            valueColor: AppConstants.error,
          ),
        const Divider(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Lacagta hadhay", style: theme.textTheme.headlineMedium),
            Text(
              _money(details.remaining),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: details.hasRemaining
                    ? AppConstants.warning
                    : AppConstants.success,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Shared pieces
  // ---------------------------------------------------------------------

  Widget _buildRoundIcon(IconData icon, Color color) {
    return Container(
      height: 32,
      width: 32,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 18, fill: 1, color: color),
    );
  }

  /// A label on the left and its value on the right, with an icon in front of
  /// the label when the row is one of the booking's facts.
  Widget _buildFactRow({
    required String label,
    required String value,
    IconData? icon,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
          ],
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

  /// The bordered group both parts sit in. The icon carries the part's own
  /// colour, so the two are told apart at a glance.
  Widget _buildSection({
    required IconData icon,
    required Color accent,
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, fill: 1, color: accent),
              ),
              const SizedBox(width: 10),
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
