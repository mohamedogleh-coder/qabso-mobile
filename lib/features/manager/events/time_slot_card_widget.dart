import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/features/manager/events/event_booking_service.dart';
import 'package:qabso_mobile/features/manager/events/models/booking_context_model.dart';
import 'package:qabso_mobile/features/manager/events/models/half_booked_event_model.dart';
import 'package:qabso_mobile/features/manager/events/time_slots_model.dart';
import 'package:qabso_mobile/features/manager/events/widgets/book_another_half_widget.dart';
import 'package:qabso_mobile/features/manager/events/widgets/event_booking_options_widget.dart';
import 'package:qabso_mobile/utill/app_dailogs.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final selectedTimeSlotProvider = StateProvider<TimeSlotModel?>((ref) => null);

class TimeSlotCardWidget extends ConsumerStatefulWidget {
  final BookingContextModel booking;
  final TimeSlotModel slotModel;

  const TimeSlotCardWidget({
    super.key,
    required this.booking,
    required this.slotModel,
  });

  @override
  ConsumerState<TimeSlotCardWidget> createState() => _TimeSlotCardWidgetState();
}

class _TimeSlotCardWidgetState extends ConsumerState<TimeSlotCardWidget> {
  bool isBooking = false;

  void _setBusy(bool busy) {
    if (!mounted) return;

    setState(() => isBooking = busy);

    if (busy) {
      showAppLoadingDialog(context: context, message: "Booking...");
    } else {
      hideAppLoadingDialog(context);
    }
  }

  TimeSlotModel get _slot => widget.slotModel;

  /// Reads which state the slot is in and hands over to the handler for it.
  /// All the work is in those three methods.
  Future<void> onTapHandler() async {
    if (isBooking) return;

    switch (_slot.eventStatus) {
      case EventStatus.available:
        await _handleAvailableEvent();
        return;

      case EventStatus.pending:
        await _handlePendingEvent();
        return;

      // A cancelled event is never shown in the grid, so it is handled like a
      // confirmed one.
      case EventStatus.confirmed:
      case EventStatus.canceled:
        await _handleConfirmedEvent();
        return;
    }
  }

  /// Nobody booked this slot yet.
  ///
  /// When the stadium allows half booking the team chooses how much to take.
  /// When it does not there is nothing to choose, so we take the payment for
  /// the whole slot straight away.
  Future<void> _handleAvailableEvent() async {
    if (widget.booking.allowHalfBooking) {
      await _openBookingOptions();
      return;
    }

    await _bookWholeSlot();
    return;
  }

  Future<void> _handlePendingEvent() async {
    final eventId = _slot.eventId;

    if (eventId == null) {
      await _handleConfirmedEvent();
      return;
    }

    if (_slot.isPrivate) {
      await showAppBottomSheet<bool>(
        context: context,
        builder: (sheetContext) =>
            BookAnotherHalfWidget(booking: widget.booking, eventId: eventId),
      );
      return;
    }

    await _payRemainingHalf(eventId);
    return;
  }

  Future<void> _handleConfirmedEvent() {
    return showNotImplementedDialog(
      context: context,
      message: "Maamulka booking-ga la xaqiijiyay weli lama dhisin.",
    );
  }

  Future<void> _payRemainingHalf(int eventId) async {
    HalfBookedEventModel event;

    _setBusy(true);
    try {
      event = await ref.read(halfBookedEventProvider(eventId).future);
    } catch (e) {
      if (!mounted) return;

      await showAppErrorDialog(
        context: context,
        title: "Booking-ku ma dhicin",
        message: e is PostgrestException
            ? e.message
            : "Event-kan hadda lama qaadi karo.",
      );
      return;
    } finally {
      _setBusy(false);
    }

    if (!mounted) return;

    await EventBookingService.settleRemainingHalf(
      context: context,
      ref: ref,
      booking: widget.booking,
      event: event,
      onBusy: _setBusy,
    );
    return;
  }

  /// Opens the sheet where the team picks a half booking or the whole slot.
  Future<void> _openBookingOptions() {
    return showAppBottomSheet<int>(
      context: context,
      builder: (sheetContext) => EventBookingOptionsWidget(
        booking: widget.booking,
        selectedTime: _slot,
      ),
    );
  }

  Future<void> _bookWholeSlot() async {
    final payment = await EventBookingService.collectPayment(
      context: context,
      ref: ref,
      booking: widget.booking,
      slot: widget.slotModel,
      amount: EventBookingService.amountDue(
        slotPrice: widget.booking.slotPrice,
        isHalfBooking: false,
      ),
    );

    if (payment == null || !mounted) return;

    final eventId = await EventBookingService.book(
      context: context,
      ref: ref,
      booking: widget.booking,
      slot: widget.slotModel,
      payment: payment,
      isHalfBooking: false,
      onBusy: _setBusy,
    );

    if (eventId == null || !mounted) return;

    await EventBookingService.showBookingSuccess(
      context: context,
      isHalfBooking: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final background = widget.slotModel.isAvailable
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : (widget.slotModel.eventStatus == EventStatus.pending
              ? theme.colorScheme.tertiary.withValues(alpha: 0.3)
              : theme.colorScheme.primary.withValues(alpha: 0.5));

    final foreground = widget.slotModel.isAvailable
        ? theme.colorScheme.onSurface
        : (widget.slotModel.eventStatus == EventStatus.pending
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurface);

    final borderColor = widget.slotModel.isAvailable
        ? Theme.of(context).dividerColor
        : (widget.slotModel.eventStatus == EventStatus.pending
              ? theme.colorScheme.tertiary.withValues(alpha: 0.3)
              : theme.colorScheme.primary.withValues(alpha: 0.5));

    return badges.Badge(
      position: badges.BadgePosition.topStart(top: -4, start: -2),
      showBadge:
          (widget.slotModel.isPrivate &&
          widget.slotModel.eventStatus == EventStatus.pending),
      badgeStyle: badges.BadgeStyle(
        shape: badges.BadgeShape.square,
        badgeColor: theme.colorScheme.tertiary,
        borderRadius: BorderRadius.circular(24),
        elevation: 1,
      ),
      badgeContent: Icon(
        Symbols.lock,
        size: 12,
        color: theme.colorScheme.onPrimary,
      ),
      child: Card(
        elevation: 0,
        child: InkWell(
          onTap: isBooking ? null : onTapHandler,
          child: Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              widget.slotModel.label,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                fontWeight: FontWeight.bold,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
