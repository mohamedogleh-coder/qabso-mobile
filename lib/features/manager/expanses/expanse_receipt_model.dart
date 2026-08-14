import 'expanse_model.dart';

/// One expense as a receipt: what it was, when it was settled, who paid it
/// out, and where the money left from.
///
/// Read from `expense_receipt_view`, which is where the four tables behind it
/// are joined.
class ExpanseReceiptModel {
  final int id;
  final ExpanseType expanseType;
  final String? description;
  final DateTime expenseDate;
  final double expenseTotal;

  /// When the money actually moved, and when the record was last changed.
  /// Both are null for an expense whose transaction is missing.
  final DateTime? transactionDate;
  final DateTime? updatedAt;

  final String? processedByName;
  final String? processedByPhone;

  final List<ExpansePaymentModel> payments;

  const ExpanseReceiptModel({
    required this.id,
    required this.expanseType,
    this.description,
    required this.expenseDate,
    required this.expenseTotal,
    this.transactionDate,
    this.updatedAt,
    this.processedByName,
    this.processedByPhone,
    this.payments = const [],
  });

  factory ExpanseReceiptModel.fromJson(Map<String, dynamic> json) {
    final payments = (json['payments'] as List?) ?? [];

    return ExpanseReceiptModel(
      id: json['id'] as int,
      expanseType: ExpanseType.fromString(json['expense_type'] as String),
      description: json['description'] as String?,
      expenseDate: DateTime.parse(json['expense_date'].toString()),
      expenseTotal: (json['expense_total'] as num).toDouble(),
      transactionDate: json['transaction_date'] == null
          ? null
          : DateTime.parse(json['transaction_date'].toString()),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'].toString()),
      processedByName: json['processed_by_name'] as String?,
      processedByPhone: json['processed_by_phone'] as String?,
      payments: payments
          .map(
            (payment) =>
                ExpansePaymentModel.fromJson(payment as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

/// One portion of what an expense was paid with — a `transaction_details` row
/// with the provider behind its number.
class ExpansePaymentModel {
  /// The number the money went to, or null when it was paid in cash.
  final String? merchantNumber;
  final String? providerName;
  final String? providerService;
  final double amountPaid;

  const ExpansePaymentModel({
    this.merchantNumber,
    this.providerName,
    this.providerService,
    required this.amountPaid,
  });

  factory ExpansePaymentModel.fromJson(Map<String, dynamic> json) {
    return ExpansePaymentModel(
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
