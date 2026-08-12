import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../payments/payment_allocation_model.dart';
import '../../../utill/app_date_util.dart';
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
      },
    );

    return eventId as int;
  }
}
