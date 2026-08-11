import 'package:equatable/equatable.dart';

import '../features/manager/merchants/stadium_merchant_model.dart';

/// One portion of a payment and the method it went through — a single
/// `transaction_details` row, minus the parent id the database assigns.
///
/// The merchant is held as the registered [StadiumMerchantModel] rather than
/// as a loose number and provider name, so the id written to
/// `stadium_merchant_id` can never disagree with the number written beside
/// it. A null [merchant] is cash, which is exactly how the column reads it.
class PaymentAllocationModel extends Equatable {
  const PaymentAllocationModel({this.merchant, required this.amountPaid});

  /// The registered merchant that took this portion, or null for cash.
  final StadiumMerchantModel? merchant;

  final double amountPaid;

  int? get stadiumMerchantId => merchant?.id;

  bool get isCash => merchant == null;

  /// What the row is called on screen and on a receipt.
  String get methodName =>
      merchant == null ? 'Cash' : merchant!.provider.providerService;

  /// The number the money went to, or null for cash. Snapshotted into
  /// `transaction_details.merchant_number` so editing or deleting the
  /// merchant later cannot rewrite where this payment went.
  String? get merchantNumber => merchant?.merchantNumber;

  /// The `transaction_details` row, ready to be sent as one element of the
  /// parent transaction's payload.
  Map<String, dynamic> toJson() {
    return {
      'stadium_merchant_id': stadiumMerchantId,
      'merchant_number': merchantNumber,
      'amount_paid': amountPaid,
    };
  }

  PaymentAllocationModel copyWith({
    StadiumMerchantModel? Function()? merchant,
    double? amountPaid,
  }) {
    return PaymentAllocationModel(
      merchant: merchant != null ? merchant() : this.merchant,
      amountPaid: amountPaid ?? this.amountPaid,
    );
  }

  @override
  List<Object?> get props => [stadiumMerchantId, amountPaid];
}
