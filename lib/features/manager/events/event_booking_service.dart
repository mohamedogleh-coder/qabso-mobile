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
import 'time_slots_model.dart';

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

  /// Opens the payment sheet that fits the signed-in role and returns what was
  /// collected, or null if they backed out.
  ///
  /// A manager takes money at the desk, so they get the full sheet: split
  /// across merchants and cash, with a discount. A customer pays the whole
  /// amount through one of the stadium's merchants, so their sheet returns a
  /// single allocation, wrapped here as the payment it stands for.
  static Future<PaymentResult?> collectPayment({
    required BuildContext context,
    required WidgetRef ref,
    required BookingContextModel booking,
    required TimeSlotModel slot,
    required double amount,
  }) async {
    final appUser = ref.read(appUserNotifierProvider).value;

    if (appUser == null) {
      await showAppErrorDialog(
        context: context,
        message: "Fadlan mar kale gal si aad booking u sameyso.",
      );
      return null;
    }

    if (appUser.role == AppUserRole.manager) {
      return showPaymentSheet(
        context: context,
        requiredAmount: amount,
        title: slot.label,
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
  static Future<int?> book({
    required BuildContext context,
    required WidgetRef ref,
    required BookingContextModel booking,
    required TimeSlotModel slot,
    required PaymentResult payment,
    required bool isHalfBooking,
    String? eventKey,
    ValueChanged<bool>? onBusy,
  }) async {
    final appUser = ref.read(appUserNotifierProvider).value;

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

    final isManager = appUser.role == AppUserRole.manager;

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
        paidUser: isManager ? null : appUser.id,
        processedBy: isManager ? appUser.id : null,
      );

      // The grid is what tells everyone else the slot is gone.
      ref.invalidate(eventTimeSlotsProvider(booking.fieldId));
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
        message: failure is PostgrestException
            ? failure.message
            : failure.toString(),
      );
      return null;
    }

    return eventId;
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
