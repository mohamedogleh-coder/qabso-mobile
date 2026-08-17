import '../time_slots_model.dart';

/// One booking with everything behind it: the slot, where it is played, what
/// it came to, and every payment taken for it.
///
/// Read from `event_details_fn`, which is where the six tables behind it are
/// joined.
class EventDetailsModel {
  final int eventId;
  final DateTime eventStart;
  final DateTime eventEnd;
  final int extraTime;

  /// The private code a half booking is joined with. Null on a whole booking.
  final String? eventKey;

  final double remaining;
  final DateTime? cancelledAt;
  final EventStatus eventStatus;

  final int fieldId;
  final int capacity;

  /// The price of one player, and the whole slot's price built from it.
  final double cost;
  final double slotPrice;

  final String stadiumId;
  final String stadiumName;
  final bool allowHalfBooking;

  /// What the booking was billed before discounts, what actually changed
  /// hands after them, what was taken off, and what was handed back.
  final double billedAmount;
  final double paidAmount;
  final double discounted;
  final double refunded;

  final List<EventTransactionModel> transactions;

  const EventDetailsModel({
    required this.eventId,
    required this.eventStart,
    required this.eventEnd,
    required this.extraTime,
    this.eventKey,
    required this.remaining,
    this.cancelledAt,
    required this.eventStatus,
    required this.fieldId,
    required this.capacity,
    required this.cost,
    required this.slotPrice,
    required this.stadiumId,
    required this.stadiumName,
    required this.allowHalfBooking,
    required this.billedAmount,
    required this.paidAmount,
    required this.discounted,
    required this.refunded,
    this.transactions = const [],
  });

  factory EventDetailsModel.fromJson(Map<String, dynamic> json) {
    final transactions = (json['transactions'] as List?) ?? [];

    return EventDetailsModel(
      eventId: json['event_id'] as int,
      eventStart: DateTime.parse(json['event_start'].toString()),
      eventEnd: DateTime.parse(json['event_end'].toString()),
      extraTime: json['extra_time'] as int,
      eventKey: json['event_key'] as String?,
      remaining: (json['remaining'] as num).toDouble(),
      cancelledAt: json['cancelled_at'] == null
          ? null
          : DateTime.parse(json['cancelled_at'].toString()),
      eventStatus: EventStatus.fromString(json['event_status'] as String),
      fieldId: json['field_id'] as int,
      capacity: json['capacity'] as int,
      cost: (json['cost'] as num).toDouble(),
      slotPrice: (json['slot_price'] as num).toDouble(),
      stadiumId: json['stadium_id'] as String,
      stadiumName: json['stadium_name'] as String,
      allowHalfBooking: json['allow_half_booking'] as bool,
      billedAmount: (json['billed_amount'] as num).toDouble(),
      paidAmount: (json['paid_amount'] as num).toDouble(),
      discounted: (json['discounted'] as num).toDouble(),
      refunded: (json['refunded'] as num).toDouble(),
      transactions: transactions
          .map(
            (transaction) => EventTransactionModel.fromJson(
              Map<String, dynamic>.from(transaction as Map),
            ),
          )
          .toList(),
    );
  }

  /// A half booking carries a code the second team joins with.
  bool get isPrivate => eventKey != null;

  bool get hasRemaining => remaining > 0;
}

/// One payment or refund taken on the booking, with the portions it was split
/// into.
class EventTransactionModel {
  final int transactionId;

  /// Either `payment` or `refund`. An expense never points at an event.
  final String transactionType;

  final DateTime transactionDate;
  final double totalAmount;
  final double discounted;

  /// The customer the money came from, when there was one. A booking taken at
  /// the desk records the staff member instead.
  final String? paidUserName;
  final String? paidUserPhone;
  final String? processedByName;

  final List<EventPaymentModel> details;

  const EventTransactionModel({
    required this.transactionId,
    required this.transactionType,
    required this.transactionDate,
    required this.totalAmount,
    required this.discounted,
    this.paidUserName,
    this.paidUserPhone,
    this.processedByName,
    this.details = const [],
  });

  factory EventTransactionModel.fromJson(Map<String, dynamic> json) {
    final details = (json['details'] as List?) ?? [];

    return EventTransactionModel(
      transactionId: json['transaction_id'] as int,
      transactionType: json['transaction_type'] as String,
      transactionDate: DateTime.parse(json['transaction_date'].toString()),
      totalAmount: (json['total_amount'] as num).toDouble(),
      discounted: (json['discounted'] as num).toDouble(),
      paidUserName: json['paid_user_name'] as String?,
      paidUserPhone: json['paid_user_phone'] as String?,
      processedByName: json['processed_by_name'] as String?,
      details: details
          .map(
            (detail) => EventPaymentModel.fromJson(
              Map<String, dynamic>.from(detail as Map),
            ),
          )
          .toList(),
    );
  }

  bool get isRefund => transactionType == 'refund';

  /// What actually changed hands, once the discount came off.
  double get settled => totalAmount - discounted;

  bool get hasDiscount => discounted > 0;

  /// Whoever the money came from — the paying customer, or the staff member
  /// who took it at the desk.
  String get payerName => paidUserName ?? processedByName ?? "Unknown";
}

/// One portion of a transaction — a `transaction_details` row with the
/// provider behind its number.
class EventPaymentModel {
  /// The number the money went to, or null when it was paid in cash.
  final String? merchantNumber;
  final String? providerName;
  final String? providerService;
  final double amountPaid;

  const EventPaymentModel({
    this.merchantNumber,
    this.providerName,
    this.providerService,
    required this.amountPaid,
  });

  factory EventPaymentModel.fromJson(Map<String, dynamic> json) {
    return EventPaymentModel(
      merchantNumber: json['merchant_number'] as String?,
      providerName: json['provider_name'] as String?,
      providerService: json['provider_service'] as String?,
      amountPaid: (json['amount_paid'] as num).toDouble(),
    );
  }

  bool get isCash => merchantNumber == null;

  /// What the line is called on the receipt.
  String get methodName => isCash ? "Cash" : (providerService ?? "Merchant");
}
