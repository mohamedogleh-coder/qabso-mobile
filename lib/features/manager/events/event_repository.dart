import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../payments/payment_allocation_model.dart';
import '../../../utill/app_date_util.dart';
import 'models/booking_search_result_model.dart';
import 'models/event_details_model.dart';
import 'models/half_booked_event_model.dart';
import 'time_slots_model.dart';

class EventRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static const _eventsTable = 'event_bookings';

  static Future<List<TimeSlotModel>> getTimeSlots({
    required int fieldId,
    required DateTime date,
  }) async {
    final rows =
        await _client.rpc(
              'generate_booking_time_seq_fn',
              params: {
                'p_field_id': fieldId,
                'p_date': AppDateUtil.formatDate(date),
              },
            )
            as List;

    return rows
        .map((row) => TimeSlotModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Reads the booking whose other half is still owed.
  ///
  /// Scoped to `pending` as well as to the id, because that status *is* "still
  /// owes something": `chk_event_status_remaining` ties it to `remaining > 0`.
  /// So a booking that never existed, was settled by someone else in the
  /// meantime, or was cancelled all match nothing here and throw, rather than
  /// coming back as a booking with no half left to take. The `.maybeSingle()`
  /// is what makes that visible — a filter matching no row is otherwise
  /// silently null.
  static Future<HalfBookedEventModel> getHalfBookedEvent({
    required int eventId,
  }) async {
    final row = await _client
        .from(_eventsTable)
        .select('id, event_start, event_end, event_key, extra_time, remaining')
        .eq('id', eventId)
        .eq('event_status', 'pending')
        .maybeSingle();

    if (row == null) {
      throw StateError('Event $eventId is not a pending half booking.');
    }

    return HalfBookedEventModel.fromJson(row);
  }

  /// Reads one booking with its stadium and field, what it came to, and every
  /// payment taken for it.
  ///
  /// Who may see it is decided by `event_details_fn`: the customer whose money
  /// is on the booking, or a manager of the stadium it is played at. Anyone
  /// else gets no row back, so a missing row is thrown as "not found" rather
  /// than told apart from "not allowed".
  static Future<EventDetailsModel> getEventDetails({
    required int eventId,
  }) async {
    final rows =
        await _client.rpc(
              'event_details_fn',
              params: {'p_event_id': eventId},
            )
            as List;

    if (rows.isEmpty) {
      throw StateError('Event $eventId was not found.');
    }

    return EventDetailsModel.fromJson(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }

  /// Finds a stadium's bookings by the customer's phone number, newest first.
  ///
  /// [phone] is matched on its digits alone and anywhere in the number, so the
  /// last few digits find a booking however the number was written down.
  /// Fewer than four digits is refused by the database rather than answered.
  ///
  /// Only a manager of [stadiumId] may search it, which the function decides —
  /// anyone else gets a [PostgrestException] carrying its message.
  static Future<List<BookingSearchResultModel>> searchBookingsByPhone({
    required String stadiumId,
    required String phone,
    int limit = 50,
  }) async {
    final rows =
        await _client.rpc(
              'search_bookings_by_phone_fn',
              params: {
                'p_stadium_id': stadiumId,
                'p_phone': phone,
                'p_limit': limit,
              },
            )
            as List;

    return rows
        .map(
          (row) => BookingSearchResultModel.fromJson(
            Map<String, dynamic>.from(row as Map),
          ),
        )
        .toList();
  }

  /// Takes the half a booking still owes and records the payment for it,
  /// returning the booking's id.
  ///
  /// No amount is passed: the whole remaining half is what gets taken, and
  /// `book_another_half_fn` reads that from the booking itself, so nothing
  /// here can disagree with what is actually owed.
  ///
  /// Whether the half is still there to take, whether the code matches, and
  /// whether the split covers what is owed are all decided by that function
  /// while it holds the row locked — two people paying the same half at once
  /// cannot both succeed. The checks here are only the ones that would
  /// otherwise cost a round trip to hear.
  ///
  /// [eventKey] belongs to a private booking. A public half is open to anyone
  /// and takes null.
  static Future<int> bookAnotherHalf({
    required int eventId,
    required List<PaymentAllocationModel> payments,
    double discount = 0,
    String? eventKey,
    String? paidUser,
    String? processedBy,
    String? payerPhone,
  }) async {
    // Mirrors the function's own check, which mirrors chk_transaction_actors.
    if ((paidUser == null) == (processedBy == null)) {
      throw ArgumentError(
        'Exactly one of paidUser or processedBy is required.',
      );
    }

    // Mirrors chk_payer_phone_only_without_user. A signed-in customer's
    // number is read through paidUser, so recording it here as well would
    // only leave a copy to go stale.
    if (paidUser != null && payerPhone != null) {
      throw ArgumentError(
        'payerPhone belongs to a walk-in, so it cannot be sent with paidUser.',
      );
    }

    if (payments.isEmpty) {
      throw ArgumentError.value(
        payments,
        'payments',
        'At least one payment is required.',
      );
    }

    if (payments.any((payment) => payment.amountPaid <= 0)) {
      throw ArgumentError.value(
        payments,
        'payments',
        'Every payment must be greater than zero.',
      );
    }

    if (discount < 0) {
      throw ArgumentError.value(
        discount,
        'discount',
        'A discount cannot be negative.',
      );
    }

    if (eventKey != null && eventKey.length != 4) {
      throw ArgumentError.value(
        eventKey,
        'eventKey',
        'A lock code is exactly 4 characters.',
      );
    }

    final settledId = await _client.rpc(
      'book_another_half_fn',
      params: {
        'p_event_id': eventId,
        'p_event_key': eventKey,
        'p_discounted': discount,
        'p_paid_user': paidUser,
        'p_processed_by': processedBy,
        'p_merchants': payments.map((payment) => payment.toJson()).toList(),
        'p_payer_phone': payerPhone,
      },
    );

    return settledId as int;
  }

  /// Books one slot and records the payment taken for it, returning the new
  /// booking's id.
  ///
  /// Every booking rule — the stadium works that day, the field accepts
  /// bookings, half bookings are allowed, the time is inside working hours and
  /// on the offered grid, the slot is still free — is decided by
  /// `book_event_fn` and the trigger behind it. The checks here are only the
  /// ones the database would answer with an error the customer cannot act on,
  /// so a mistake in the caller surfaces as an [ArgumentError] rather than a
  /// round trip.
  ///
  /// [eventStatus] is what makes this a half booking: `pending` pays half now
  /// and leaves the rest owed, `confirmed` pays it all. [eventKey] is the
  /// 4-digit code that locks the remaining half, or null when the slot is left
  /// open to anyone.
  ///
  /// Exactly one of [paidUser] and [processedBy] is recorded: money either
  /// came from a customer, or was taken by a staff member at the desk.
  ///
  /// A rule the database refuses comes back as a [PostgrestException] carrying
  /// its message, which callers show as-is.
  static Future<int> bookEvent({
    required int fieldId,
    required DateTime eventStart,
    required EventStatus eventStatus,
    required List<PaymentAllocationModel> payments,
    double discount = 0,
    String? eventKey,
    String? paidUser,
    String? processedBy,
    String? payerPhone,
  }) async {
    if (eventStatus != EventStatus.pending &&
        eventStatus != EventStatus.confirmed) {
      throw ArgumentError.value(
        eventStatus,
        'eventStatus',
        'A booking is created pending (half paid) or confirmed (paid in full).',
      );
    }

    // Mirrors the function's own check, which mirrors chk_transaction_actors.
    if ((paidUser == null) == (processedBy == null)) {
      throw ArgumentError(
        'Exactly one of paidUser or processedBy is required.',
      );
    }

    // Mirrors chk_payer_phone_only_without_user. A signed-in customer's
    // number is read through paidUser, so recording it here as well would
    // only leave a copy to go stale.
    if (paidUser != null && payerPhone != null) {
      throw ArgumentError(
        'payerPhone belongs to a walk-in, so it cannot be sent with paidUser.',
      );
    }

    if (payments.isEmpty) {
      throw ArgumentError.value(
        payments,
        'payments',
        'At least one payment is required.',
      );
    }

    if (payments.any((payment) => payment.amountPaid <= 0)) {
      throw ArgumentError.value(
        payments,
        'payments',
        'Every payment must be greater than zero.',
      );
    }

    if (discount < 0) {
      throw ArgumentError.value(
        discount,
        'discount',
        'A discount cannot be negative.',
      );
    }

    if (eventKey != null && eventKey.length != 4) {
      throw ArgumentError.value(
        eventKey,
        'eventKey',
        'A lock code is exactly 4 characters.',
      );
    }

    final eventId = await _client.rpc(
      'book_event_fn',
      params: {
        'p_field_id': fieldId,
        'p_event_start': AppDateUtil.formatDateTime(eventStart),
        'p_event_key': eventKey,
        'p_event_status': eventStatus.value,
        'p_discounted': discount,
        'p_paid_user': paidUser,
        'p_processed_by': processedBy,
        'p_merchants': payments.map((payment) => payment.toJson()).toList(),
        'p_payer_phone': payerPhone,
      },
    );

    return eventId as int;
  }
}
