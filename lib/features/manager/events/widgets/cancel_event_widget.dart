import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../payments/payment_result.dart';
import '../../../../payments/payment_widget.dart';
import '../../../../utill/app_dailogs.dart';
import '../../../../utill/app_input_text_widget.dart';
import '../../../../utill/error_widget.dart';
import '../../../../utill/loading_widget.dart';
import '../event_booking_service.dart';
import '../event_notifier_provider.dart';
import '../event_repository.dart';

class CancelEventWidget extends ConsumerStatefulWidget {
  final int eventId;

  final int fieldId;

  const CancelEventWidget({
    super.key,
    required this.eventId,
    required this.fieldId,
  });

  static Future<void> show(
    BuildContext context, {
    required int eventId,
    required int fieldId,
  }) {
    return showAppBottomSheet<void>(
      context: context,
      builder: (sheetContext) =>
          CancelEventWidget(eventId: eventId, fieldId: fieldId),
    );
  }

  @override
  ConsumerState<CancelEventWidget> createState() => _CancelEventWidgetState();
}

class _CancelEventWidgetState extends ConsumerState<CancelEventWidget> {
  late Future<double> _paidFuture;

  final TextEditingController _reasonController = TextEditingController();

  bool _hasReason = false;

  bool _isSaving = false;

  static String _money(double value) => "\$${value.toStringAsFixed(2)}";

  @override
  void initState() {
    super.initState();
    _paidFuture = _fetchPaidAmount();
    _reasonController.addListener(_onReasonChanged);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<double> _fetchPaidAmount() =>
      EventRepository.getPaidAmount(eventId: widget.eventId);

  void _reload() {
    setState(() {
      _paidFuture = _fetchPaidAmount();
    });
  }

  void _onReasonChanged() {
    final hasReason = _reasonController.text.trim().isNotEmpty;

    if (hasReason == _hasReason) return;

    setState(() => _hasReason = hasReason);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double>(
      future: _paidFuture,
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

        final paidAmount = snapshot.data;
        if (paidAmount == null) return const SizedBox.shrink();

        return _buildForm(paidAmount);
      },
    );
  }

  Future<void> _refund() async {
    if (_isSaving) return;

    final paidAmount = await _paidFuture;
    final manager = EventBookingService.currentUser(ref);

    if (!mounted) return;

    if (manager == null) {
      await showAppErrorDialog(
        context: context,
        message: "Fadlan mar kale gal si aad u joojiso booking-ga.",
      );
      return;
    }

    final refund = await showPaymentSheet(
      context: context,
      requiredAmount: paidAmount,
      title: "Lacag celin",
      confirmText: "Refund",
      allowDiscount: false,
      needPayerPhone: false,
    );

    if (refund == null || !mounted) return;

    await _cancelBooking(manager.id, refund);
  }

  Future<void> _cancelBooking(String managerId, PaymentResult refund) async {
    setState(() => _isSaving = true);

    try {
      await EventRepository.cancelEvent(
        eventId: widget.eventId,
        processedBy: managerId,
        refunds: refund.allocations,
        description: _reasonController.text,
      );
    } catch (error) {
      if (!mounted) return;

      setState(() => _isSaving = false);

      await showAppErrorDialog(
        context: context,
        title: "Booking-ga lama joojin",
        message: error is PostgrestException ? error.message : error.toString(),
      );
      return;
    }

    if (!mounted) return;

    setState(() => _isSaving = false);

    await showInformationDialog(
      context: context,
      icon: Symbols.check_circle,
      title: "Booking-ga waa la joojiyay",
      message:
          "Lacagtii waa la celiyay, saacadduna mar kale way bannaan tahay.",
      buttonText: "Ok",
    );

    if (!mounted) return;

    ref.invalidate(eventTimeSlotsProvider(widget.fieldId));

    Navigator.pop(context);
  }

  Widget _buildForm(double paidAmount) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildPaidAmount(paidAmount),
          const SizedBox(height: 20),
          AppInputTextWidget(
            controller: _reasonController,
            label: "Sababta joojinta",
            maxLines: 4,
            maxLength: 100,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _hasReason && !_isSaving ? _refund : null,
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: !_hasReason
                  ? null
                  : (_isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Symbols.undo, size: 20)),
              label: Text(
                _hasReason
                    ? (_isSaving
                          ? "Refunding..."
                          : "${_money(paidAmount)} Refund")
                    : "Geli Sababta",
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Symbols.cancel, size: 20, fill: 1, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Cancel Event",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Booking-ku waa joogsanayaa, lacagtiina waa la celinayaa. Fadlan "
          "qor sababta.",
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildPaidAmount(double paidAmount) {
    final theme = Theme.of(context);
    final color = theme.colorScheme.primary;

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
            child: const Icon(Symbols.undo, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Lacagta la celinayo",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _money(paidAmount),
            style: theme.textTheme.headlineLarge?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
