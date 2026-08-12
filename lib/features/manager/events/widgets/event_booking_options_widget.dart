import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/features/auth/app_user_model.dart';
import 'package:qabso_mobile/features/auth/app_user_notifer.dart';
import 'package:qabso_mobile/features/manager/events/event_notifier_provider.dart';
import 'package:qabso_mobile/features/manager/events/event_repository.dart';
import 'package:qabso_mobile/features/manager/events/time_slots_model.dart';
import 'package:qabso_mobile/features/manager/events/widgets/selected_time_widget.dart';
import 'package:qabso_mobile/features/manager/stadium/stadium_notifier_provider.dart';
import 'package:qabso_mobile/payments/payment_allocation_model.dart';
import 'package:qabso_mobile/payments/payment_result.dart';
import 'package:qabso_mobile/payments/payment_widget.dart';
import 'package:qabso_mobile/payments/user_payment_widget.dart';
import 'package:qabso_mobile/utill/app_dailogs.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EventBookingOptionsWidget extends ConsumerStatefulWidget {
  final int fieldId;
  final TimeSlotModel selectedTime;
  final String? stadiumId;

  final double requiredAmount;

  const EventBookingOptionsWidget({
    super.key,
    required this.fieldId,
    required this.requiredAmount,
    this.stadiumId,
    required this.selectedTime,
  });

  @override
  ConsumerState<EventBookingOptionsWidget> createState() =>
      _EventBookingOptionsWidgetState();
}

class _EventBookingOptionsWidgetState
    extends ConsumerState<EventBookingOptionsWidget> {
  bool isHalfTaken = false;
  bool isLocked = false;
  bool isBooking = false;
  String? generateCode;

  double get amountPaid => isHalfTaken
      ? _money(widget.requiredAmount / 2)
      : _money(widget.requiredAmount);

  static double _money(double value) => (value * 100).roundToDouble() / 100;

  String generateFourDigitCode() {
    final random = Random();
    return (1000 + random.nextInt(9000)).toString();
  }

  void _reCalculate() {
    if (isBooking) return;

    setState(() {
      isHalfTaken = !isHalfTaken;
      if (!isHalfTaken) {
        isLocked = false;
        generateCode = null;
      }
    });
  }

  void _toggleLock() {
    if (isBooking) return;

    setState(() {
      isLocked = !isLocked;
      generateCode = isLocked ? generateFourDigitCode() : null;
    });
  }

  Future<void> _handleBooking() async {
    if (isBooking) return;

    final appUser = ref.read(appUserNotifierProvider).value;
    if (appUser == null) {
      showAppErrorDialog(
        context: context,
        message: "No authenticated ,Fadlan mar kale isku day.",
      );
      return;
    }

    if (!widget.selectedTime.isAvailable) {
      showAppErrorDialog(
        context: context,
        message: "Waqtigan horey ayaa loo qabsaday.",
      );
      return;
    }

    final isManager = appUser.role == AppUserRole.manager;

    final payment = isManager
        ? await _collectManagerPayment()
        : await _collectUserPayment();

    if (payment == null || !mounted) return;

    if (payment.allocations.isEmpty || payment.discount >= amountPaid) {
      showAppErrorDialog(
        context: context,
        message: "Fadlan qiimo-dhimistu waa inay ka yar tahay lacagta la rabo.",
      );
      return;
    }

    setState(() => isBooking = true);

    try {
      await EventRepository.bookEvent(
        fieldId: widget.fieldId,
        eventStart: widget.selectedTime.startTime,
        eventStatus: isHalfTaken ? EventStatus.pending : EventStatus.confirmed,
        payments: payment.allocations,
        discount: payment.discount,
        eventKey: isLocked ? generateCode : null,
        paidUser: isManager ? null : appUser.id,
        processedBy: isManager ? appUser.id : null,
      );

      if (!mounted) return;

      ref.invalidate(eventTimeSlotsProvider(widget.fieldId));

      await _showBookingResult();
    } on PostgrestException catch (e) {
      if (!mounted) return;
      await showAppErrorDialog(
        context: context,
        title: "Booking-ku ma dhicin",
        message: e.message,
      );
    } catch (e) {
      if (!mounted) return;
      await showAppErrorDialog(
        context: context,
        title: "Booking-ku ma dhicin",
        message: e.toString(),
      );
    } finally {
      if (mounted) setState(() => isBooking = false);
    }
  }

  Future<PaymentResult?> _collectManagerPayment() {
    return showPaymentSheet(
      context: context,
      requiredAmount: amountPaid,
      title: widget.selectedTime.label,
    );
  }

  Future<PaymentResult?> _collectUserPayment() async {
    final stadiumId =
        widget.stadiumId ?? ref.read(stadiumNotifierProvider).value?.stadiumId;

    if (stadiumId == null) {
      showErrorSnackBar(
        context: context,
        message: "Garoonka lama aqoonsan karo, fadlan mar kale isku day.",
      );
      return null;
    }

    final allocation = await showAppBottomSheet<PaymentAllocationModel>(
      context: context,
      title: widget.selectedTime.label,
      builder: (sheetContext) => UserPaymentWidget(
        stadiumId: stadiumId,
        requiredAmount: amountPaid,
        timeSlotModel: widget.selectedTime,
        onSubmit: (payment) => Navigator.pop(sheetContext, payment),
      ),
    );

    if (allocation == null) return null;

    return PaymentResult(requiredAmount: amountPaid, allocations: [allocation]);
  }

  Future<void> _showBookingResult() async {
    final code = isLocked ? generateCode : null;

    if (code != null) {
      await showInformationDialog(
        context: context,
        title: "Code-ka xidhidhka",
        message:
            "Booking-ku waa la sameeyay.\n\nCode-ka: $code\n\n"
            "Sii kooxda kale si ay u bixiso halfka haray.",
        icon: Symbols.lock,
        buttonText: "Waan haystaa",
      );
    }

    if (!mounted) return;

    showSuccessSnackBar(
      context: context,
      message: isHalfTaken
          ? "Waxa la diwaan geliyay half booking."
          : "Booking-ka waa la sameeyay.",
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !isBooking,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          children: [
            SelectedTimeWidget(selectedModel: widget.selectedTime),
            const SizedBox(height: 12),
            Text(
              "Booking Options",
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                onTap: _reCalculate,
                enabled: !isBooking,
                leading: Icon(
                  Symbols.sliders,
                  color: theme.colorScheme.tertiary,
                ),
                title: Text(
                  "Half Booking",
                  style: TextStyle(fontWeight: FontWeight.bold, height: 2),
                ),
                subtitle: Text(
                  "Waxaan bixinayaa qaybta kooxdayda, halfka kale waxa biin doona kooxda kale i.a",
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                trailing: AbsorbPointer(
                  absorbing: true,
                  child: Checkbox.adaptive(
                    value: isHalfTaken,
                    onChanged: (v) => _reCalculate,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Card(
              elevation: !isHalfTaken ? 0 : 1,
              child: ListTile(
                onTap: !isHalfTaken || isBooking ? null : _toggleLock,
                leading: Icon(Symbols.lock, color: theme.colorScheme.tertiary),
                title: Text(
                  "Lock Remaining Half",
                  style: TextStyle(fontWeight: FontWeight.bold, height: 2),
                ),
                subtitle: Text(
                  "Xidh eventka oo hel 4 digit code aad siin karto kooxda lacagta bixinaysa.",
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                trailing: AbsorbPointer(
                  child: Switch.adaptive(
                    value: isLocked,
                    activeThumbColor: Theme.of(context).colorScheme.primary,
                    inactiveThumbColor: Theme.of(context).colorScheme.primary,
                    onChanged: isHalfTaken ? (v) {} : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isBooking ? null : _handleBooking,
                icon: isBooking
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Symbols.payments),
                label: Text("Pay  \$${amountPaid.toStringAsFixed(2)}"),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
