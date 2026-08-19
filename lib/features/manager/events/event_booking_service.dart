import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../payments/payment_allocation_model.dart';
import '../../../payments/payment_result.dart';
import '../../../payments/payment_widget.dart';
import '../../../payments/user_payment_widget.dart';
import '../../../utill/app_dailogs.dart';
import '../../auth/app_user_model.dart';
import '../../auth/app_user_notifer.dart';
import 'event_notifier_provider.dart';
import 'event_repository.dart';
import 'models/booking_context_model.dart';
import 'models/half_booked_event_model.dart';
import 'time_slots_model.dart';
import 'widgets/book_another_half_widget.dart';

/// The booking flow both roles and both entry points share.
///
/// A slot can be taken from the card directly (when the stadium does not allow
/// half bookings, so there is nothing to choose) or through the booking
/// options sheet (when it does). Both then do the same three things — collect
/// the money the way the signed-in role pays, write the booking, tell the
/// customer how it went — so those three live here once.
///
/// Every method takes the [BookingContextModel] it works on rather than
/// reading a provider, which is what keeps the event widgets usable by a
/// customer who has no stadium provider at all.
class EventBookingService {
  const EventBookingService._();

  /// Rounds to whole cents the way `book_event_fn` rounds, so the figure on
  /// screen is the figure the database will ask for even when an odd
  /// `capacity * cost` splits unevenly.
  static double money(double value) => (value * 100).roundToDouble() / 100;

  /// What the payer hands over now: half the slot for a half booking, all of
  /// it otherwise.
  static double amountDue({
    required double slotPrice,
    required bool isHalfBooking,
  }) {
    return isHalfBooking ? money(slotPrice / 2) : money(slotPrice);
  }

  /// The 4-digit code that locks the remaining half to whoever holds it.
  static String generateEventKey() =>
      (1000 + Random().nextInt(9000)).toString();

  /// The signed in user, or null when nobody is signed in.
  ///
  /// The one place the user is read, so every flow asks the same question the
  /// same way.
  static AppUserModel? currentUser(WidgetRef ref) =>
      ref.read(appUserNotifierProvider).value;

  /// A manager takes money at the desk. Everyone else pays for their own
  /// booking. This is the only role check in the whole booking flow: it picks
  /// the payment sheet, and it decides whether the money is recorded as
  /// `processed_by` or as `paid_user`.
  static bool isManager(AppUserModel user) => user.role == AppUserRole.manager;

  /// The text to show when something fails. A rule the database refuses comes
  /// back with its own message, already written for the customer. Anything
  /// else is a network or decoding failure and is shown as it came.
  static String messageOf(Object error) {
    if (error is PostgrestException) return error.message;

    return error.toString();
  }

  /// Opens the payment sheet that fits the signed-in role and returns what was
  /// collected, or null if they backed out.
  ///
  /// A manager gets the full sheet: split across merchants and cash, with a
  /// discount. A user pays the whole amount through one merchant, so their
  /// sheet returns one allocation, wrapped here as the payment it stands for.
  static Future<PaymentResult?> collectPayment({
    required BuildContext context,
    required WidgetRef ref,
    required BookingContextModel booking,
    required TimeSlotModel slot,
    required double amount,
  }) async {
    final appUser = currentUser(ref);

    if (appUser == null) {
      await showAppErrorDialog(
        context: context,
        message: "Fadlan mar kale gal si aad booking u sameyso.",
      );
      return null;
    }

    if (isManager(appUser)) {
      // A manager is taking money at the desk from someone with no account,
      // so their number is asked for: it is the only record of who paid.
      return showPaymentSheet(
        context: context,
        requiredAmount: amount,
        title: slot.label,
        needPayerPhone: true,
      );
    }

    final allocation = await showAppBottomSheet<PaymentAllocationModel>(
      context: context,
      title: slot.label,
      builder: (sheetContext) => UserPaymentWidget(
        stadiumId: booking.stadiumId,
        requiredAmount: amount,
        timeSlotModel: slot,
        onSubmit: (payment) => Navigator.pop(sheetContext, payment),
      ),
    );

    if (allocation == null) return null;

    return PaymentResult(requiredAmount: amount, allocations: [allocation]);
  }

  /// Writes the booking and returns its id, or null when it could not be made.
  ///
  /// Who the money is recorded against follows the role: a manager took it at
  /// the desk (`processed_by`), anyone else paid it themselves (`paid_user`).
  /// Every rule the database refuses comes back as its own customer-ready
  /// message and is shown as such.
  ///
  /// [onBusy] brackets the write, so each caller can render waiting its own
  /// way — an inline spinner on a button, or the app's loading dialog — and is
  /// always cleared before any dialog appears on top of it.
  ///
  /// [refreshSlots] reloads the grid as soon as the booking is written, which
  /// is what every caller wants. Pass false when the caller shows something
  /// over the grid first and wants to reload it in its own time.
  static Future<int?> book({
    required BuildContext context,
    required WidgetRef ref,
    required BookingContextModel booking,
    required TimeSlotModel slot,
    required PaymentResult payment,
    required bool isHalfBooking,
    String? eventKey,
    ValueChanged<bool>? onBusy,
    bool refreshSlots = true,
  }) async {
    final appUser = currentUser(ref);

    if (appUser == null) {
      await showAppErrorDialog(
        context: context,
        message: "Fadlan mar kale gal si aad booking u sameyso.",
      );
      return null;
    }

    if (!slot.isAvailable) {
      await showAppErrorDialog(
        context: context,
        message: "Waqtigan horey ayaa loo qabsaday.",
      );
      return null;
    }

    final amount = amountDue(
      slotPrice: booking.slotPrice,
      isHalfBooking: isHalfBooking,
    );

    // The database refuses a discount that swallows the whole amount, since
    // some money must actually change hands. Said here so the customer does
    // not pay a round trip to hear it.
    if (payment.allocations.isEmpty || payment.discount >= amount) {
      await showAppErrorDialog(
        context: context,
        message: "Fadlan qiimo-dhimistu waa inay ka yar tahay lacagta la rabo.",
      );
      return null;
    }

    final takenByManager = isManager(appUser);

    int? eventId;
    Object? failure;

    onBusy?.call(true);
    try {
      eventId = await EventRepository.bookEvent(
        fieldId: booking.fieldId,
        eventStart: slot.startTime,
        eventStatus: isHalfBooking
            ? EventStatus.pending
            : EventStatus.confirmed,
        payments: payment.allocations,
        discount: payment.discount,
        eventKey: eventKey,
        paidUser: takenByManager ? null : appUser.id,
        processedBy: takenByManager ? appUser.id : null,
        // Only a desk payment carries one. A signed-in customer is already
        // recorded as paidUser, and chk_payer_phone_only_without_user refuses
        // both at once.
        payerPhone: takenByManager ? payment.payerPhone : null,
      );

      // The grid is what tells everyone else the slot is gone.
      if (refreshSlots) {
        ref.invalidate(eventTimeSlotsProvider(booking.fieldId));
      }
    } catch (e) {
      failure = e;
    } finally {
      onBusy?.call(false);
    }

    if (failure != null) {
      if (!context.mounted) return null;

      await showAppErrorDialog(
        context: context,
        title: "Booking-ku ma dhicin",
        message: messageOf(failure),
      );
      return null;
    }

    return eventId;
  }

  /// Takes the half a booking still owes: collects the money the way this role
  /// pays, then settles it. Returns true when the booking is now paid in full.
  ///
  /// Two screens do this — the card, for a public half that needs no code, and
  /// [BookAnotherHalfWidget], for a private one after its code is typed — so
  /// the steps live here once. [eventKey] is only for a private booking.
  ///
  /// The amount paid is the booking's own `remaining`. How much is owed and
  /// who may take it are decided by `book_another_half_fn`, not here.
  static Future<bool> settleRemainingHalf({
    required BuildContext context,
    required WidgetRef ref,
    required BookingContextModel booking,
    required HalfBookedEventModel event,
    String? eventKey,
    ValueChanged<bool>? onBusy,
  }) async {
    final appUser = currentUser(ref);

    if (appUser == null) {
      await showAppErrorDialog(
        context: context,
        message: "Fadlan mar kale gal si aad booking u sameyso.",
      );
      return false;
    }

    final payment = await collectPayment(
      context: context,
      ref: ref,
      booking: booking,
      slot: slotOf(event),
      amount: event.remaining,
    );

    if (payment == null || !context.mounted) return false;

    final takenByManager = isManager(appUser);

    Object? failure;

    onBusy?.call(true);
    try {
      await EventRepository.bookAnotherHalf(
        eventId: event.id,
        payments: payment.allocations,
        discount: payment.discount,
        eventKey: eventKey,
        paidUser: takenByManager ? null : appUser.id,
        processedBy: takenByManager ? appUser.id : null,
        payerPhone: takenByManager ? payment.payerPhone : null,
      );

      // The slot must now show as fully booked, and this booking has no half
      // left to offer anyone.
      ref.invalidate(eventTimeSlotsProvider(booking.fieldId));
      ref.invalidate(halfBookedEventProvider(event.id));
    } catch (e) {
      failure = e;
    } finally {
      onBusy?.call(false);
    }

    if (!context.mounted) return false;

    if (failure != null) {
      await showAppErrorDialog(
        context: context,
        title: "Booking-ku ma dhicin",
        message: messageOf(failure),
      );
      return false;
    }

    showSuccessSnackBar(context: context, message: "Event-ka waa la buuxiyay.");

    return true;
  }

  /// A half booked event in the shape the payment sheets read, so they can
  /// show what is being paid for without a second model to keep in step.
  static TimeSlotModel slotOf(HalfBookedEventModel event) {
    return TimeSlotModel(
      startTime: event.eventStart,
      endTime: event.eventEnd,
      eventId: event.id,
      eventKey: event.eventKey,
      eventStatus: EventStatus.pending,
    );
  }

  static Future<void> showBookingSuccess({
    required BuildContext context,
    required bool isHalfBooking,
    String? eventKey,
  }) async {
    if (eventKey != null) {
      await showInformationDialog(
        context: context,
        title: "Event Key",
        message:
            "Booking-ku waa la sameeyay.\n\nCode-ku waa: $eventKey\n\n"
            "La share garee kooxda kale code kan si ay lacagta event-kan u "
            "bixshaan.",
        icon: Symbols.lock,
        buttonText: "Ok",
      );

      if (!context.mounted) return;
    }

    showSuccessSnackBar(
      context: context,
      message: isHalfBooking
          ? "Half booking event made successfully."
          : "Booking made successfully.",
    );
  }
}
