import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/features/manager/events/event_booking_service.dart';
import 'package:qabso_mobile/features/manager/events/models/booking_context_model.dart';
import 'package:qabso_mobile/features/manager/events/time_slots_model.dart';
import 'package:qabso_mobile/features/manager/events/widgets/book_another_half_widget.dart';
import 'package:qabso_mobile/features/manager/events/widgets/event_booking_options_widget.dart';
import 'package:qabso_mobile/utill/app_dailogs.dart';

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

  Future<void> _handleTap() async {
    if (isBooking) return;

    if (!widget.slotModel.isAvailable) {
      if (widget.slotModel.eventStatus == EventStatus.pending) {
        await _openRemainingHalf();
      } else {
        await _showBookedSlotAction();
      }
      return;
    }

    if (widget.booking.allowHalfBooking) {
      await _openBookingOptions();
      return;
    }

    await _bookWholeSlot();
  }

  /// A booking that still owes half. A locked one asks for its code first, so
  /// it opens [BookAnotherHalfWidget]; an open one is offered to anyone, so it
  /// goes straight to the payment sheet that fits the signed-in role.
  ///
  /// Taking the half is not written yet: what is collected here is not settled
  /// against the booking, which is `book_another_half_fn`'s job to come.
  Future<void> _openRemainingHalf() async {
    final eventId = widget.slotModel.eventId;

    if (eventId == null) {
      await _showBookedSlotAction();
      return;
    }

    if (widget.slotModel.isPrivate) {
      await showAppBottomSheet<bool>(
        context: context,
        builder: (sheetContext) => BookAnotherHalfWidget(eventId: eventId),
      );
      return;
    }

    await EventBookingService.collectPayment(
      context: context,
      ref: ref,
      booking: widget.booking,
      slot: widget.slotModel,
      // What the first team left owing is the other half of the slot.
      amount: EventBookingService.amountDue(
        slotPrice: widget.booking.slotPrice,
        isHalfBooking: true,
      ),
    );
  }

  /// What can be done with a booking already paid in full — cancelling it,
  /// moving it — is not built yet.
  Future<void> _showBookedSlotAction() {
    return showNotImplementedDialog(
      context: context,
      message: "Maamulka booking-ga la xaqiijiyay weli lama dhisin.",
    );
  }

  Future<void> _openBookingOptions() {
    return showAppBottomSheet<int>(
      context: context,
      builder: (sheetContext) => EventBookingOptionsWidget(
        booking: widget.booking,
        selectedTime: widget.slotModel,
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
      showBadge: widget.slotModel.isPrivate,
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
          onTap: isBooking ? null : _handleTap,
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
