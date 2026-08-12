import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/features/manager/events/models/booking_context_model.dart';
import 'package:qabso_mobile/features/manager/events/event_booking_service.dart';
import 'package:qabso_mobile/features/manager/events/time_slots_model.dart';
import 'package:qabso_mobile/features/manager/events/widgets/selected_time_widget.dart';

/// Chooses how a slot is taken — the whole match or half of it, open or locked
/// — and books that choice.
///
/// Only opened when the stadium allows half bookings; with nothing to choose
/// the card books the slot whole without this step. The two switches decide
/// what the database is told: half becomes `pending` and leaves the rest owed,
/// whole becomes `confirmed`, and locking generates the code that becomes the
/// booking's `event_key`.
///
/// Which payment sheet opens is [EventBookingService]'s business, not this
/// widget's, so a manager and a customer both end up here and neither is
/// mentioned by name.
class EventBookingOptionsWidget extends ConsumerStatefulWidget {
  final BookingContextModel booking;
  final TimeSlotModel selectedTime;

  const EventBookingOptionsWidget({
    super.key,
    required this.booking,
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
  String? eventKey;

  double get amountPaid => EventBookingService.amountDue(
    slotPrice: widget.booking.slotPrice,
    isHalfBooking: isHalfTaken,
  );

  void _reCalculate() {
    if (isBooking) return;

    setState(() {
      isHalfTaken = !isHalfTaken;
      // Only half a booking can be locked: there is no remaining half to hold
      // for anyone once the whole slot is paid.
      if (!isHalfTaken) {
        isLocked = false;
        eventKey = null;
      }
    });
  }

  void _toggleLock() {
    if (isBooking) return;

    setState(() {
      isLocked = !isLocked;
      eventKey = isLocked ? EventBookingService.generateEventKey() : null;
    });
  }

  void _setBusy(bool busy) {
    if (!mounted) return;

    setState(() => isBooking = busy);
  }

  /// Collects the payment for the current choice and books it. Backing out of
  /// the payment sheet leaves the slot untouched.
  Future<void> _handleBooking() async {
    if (isBooking) return;

    final payment = await EventBookingService.collectPayment(
      context: context,
      ref: ref,
      booking: widget.booking,
      slot: widget.selectedTime,
      amount: amountPaid,
    );

    if (payment == null || !mounted) return;

    final eventId = await EventBookingService.book(
      context: context,
      ref: ref,
      booking: widget.booking,
      slot: widget.selectedTime,
      payment: payment,
      isHalfBooking: isHalfTaken,
      eventKey: isLocked ? eventKey : null,
      onBusy: _setBusy,
    );

    if (eventId == null || !mounted) return;

    await EventBookingService.showBookingSuccess(
      context: context,
      isHalfBooking: isHalfTaken,
      eventKey: isLocked ? eventKey : null,
    );

    if (!mounted) return;

    Navigator.of(context).pop(eventId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      // A booking in flight must not be dismissed out from under itself.
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
