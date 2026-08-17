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
      title: "Faahfaahinta bookingka",
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
          _buildHeader(details),
          const SizedBox(height: 16),
          _buildReceipt(details),
          const SizedBox(height: 16),
          _buildBooking(details),
          const SizedBox(height: 16),
          _buildPayment(details),
        ],
      ),
    );
  }

  Widget _buildHeader(EventDetailsModel details) {
    final theme = Theme.of(context);
    final color = details.eventStatus.color;

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
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Symbols.stadium, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  details.stadiumName,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      height: 8,
                      width: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      details.eventStatus.label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _money(details.slotPrice),
            style: theme.textTheme.headlineLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  /// When the game is played, and on which field.
  Widget _buildBooking(EventDetailsModel details) {
    return _buildSection(
      icon: Symbols.event,
      title: "Macluumaadka bookingka",
      child: Column(
        children: [
          _buildFactRow(
            label: "Taariikhda",
            value: AppDateUtil.formatReadableDate(details.eventStart),
          ),
          _buildFactRow(
            label: "Waqtiga",
            value: AppDateUtil.formatSlot(details.eventStart, details.eventEnd),
          ),
          if (details.extraTime > 0)
            _buildFactRow(
              label: "Waqti dheeraad ah",
              value: "${details.extraTime} daqiiqo",
            ),
          _buildFactRow(
            label: "Field-ka",
            value: "#${details.fieldId} · ${details.capacity} ciyaartoy",
          ),
          _buildFactRow(
            label: "Qiimaha ciyaartoyga",
            value: _money(details.cost),
          ),
          if (details.isPrivate)
            _buildFactRow(label: "Code-ka gaarka ah", value: details.eventKey!),
          if (details.cancelledAt != null)
            _buildFactRow(
              label: "Waa la joojiyay",
              value: AppDateUtil.formatDateTime(details.cancelledAt!),
            ),
        ],
      ),
    );
  }

  /// What the booking came to, and where it stands now.
  Widget _buildPayment(EventDetailsModel details) {
    final theme = Theme.of(context);

    return _buildSection(
      icon: Symbols.payments,
      title: "Lacag bixinta",
      child: Column(
        children: [
          _buildFactRow(
            label: "Qiimaha garoonka",
            value: _money(details.slotPrice),
          ),
          _buildFactRow(
            label: "Wadarta lacagta",
            value: _money(details.billedAmount),
          ),
          if (details.discounted > 0)
            _buildFactRow(
              label: "Qiimo dhimis",
              value: "-${_money(details.discounted)}",
            ),
          _buildFactRow(
            label: "Lacagta la bixiyay",
            value: _money(details.paidAmount),
          ),
          if (details.refunded > 0)
            _buildFactRow(
              label: "Lacagta la celiyay",
              value: "-${_money(details.refunded)}",
            ),
          if (details.hasRemaining) ...[
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Lacagta hadhay", style: theme.textTheme.headlineMedium),
                Text(
                  _money(details.remaining),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: AppConstants.warning,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Every payment and refund taken on the booking, oldest first.
  Widget _buildReceipt(EventDetailsModel details) {
    final theme = Theme.of(context);
    final transactions = details.transactions;

    return _buildSection(
      icon: Symbols.receipt_long,
      title: "Rasiidka",
      child: Column(
        children: [
          if (transactions.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Lacag bixin lama helin bookingkan.",
                style: theme.textTheme.bodySmall,
              ),
            ),
          for (var index = 0; index < transactions.length; index++) ...[
            if (index > 0) const Divider(height: 24),
            _buildTransaction(transactions[index]),
          ],
        ],
      ),
    );
  }

  /// One transaction: what it was, who it came from, and the portions it was
  /// split into.
  Widget _buildTransaction(EventTransactionModel transaction) {
    final theme = Theme.of(context);

    final color = transaction.isRefund
        ? AppConstants.error
        : theme.colorScheme.onSurface;

    final amount = transaction.isRefund
        ? "-${_money(transaction.settled)}"
        : _money(transaction.settled);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                transaction.isRefund ? "Lacag celin" : "Lacag bixin",
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
            Text(
              amount,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          AppDateUtil.formatDateTime(transaction.transactionDate),
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: 2),
        Text(
          transaction.paidUserName != null
              ? "Waxaa bixiyay ${transaction.payerName}"
              : "Waxaa qaatay ${transaction.payerName}",
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (transaction.hasDiscount) ...[
          const SizedBox(height: 2),
          Text(
            "Qiimo dhimis ${_money(transaction.discounted)}",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 10),
        for (final payment in transaction.details) ...[
          _buildPaymentRow(payment),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  /// One portion of a transaction — cash, or a merchant number it went to.
  Widget _buildPaymentRow(EventPaymentModel payment) {
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

  /// The bordered group every part uses, the same one the expense receipt
  /// uses, so the two receipts read alike.
  Widget _buildSection({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
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
