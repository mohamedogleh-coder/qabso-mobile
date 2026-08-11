import 'package:equatable/equatable.dart';

import '../features/manager/merchants/stadium_merchant_model.dart';
import 'payment_allocation_model.dart';

/// A payment being put together, and — once settled — the result handed to
/// whoever asked for it. One class for both: what the widget collects is
/// exactly what the parent receives.
///
/// The figures line up with `transactions` — [requiredAmount] is
/// `total_amount`, [discount] is `discounted` — and [allocations] are its
/// `transaction_details`. `total_amount - discounted` is what those details
/// must add up to, so [isSettled] asks exactly the question the database's
/// settlement trigger asks at COMMIT.
class PaymentResult extends Equatable {
  const PaymentResult({
    this.requiredAmount = 0,
    this.discount = 0,
    this.allocations = const [],
  });

  final double requiredAmount;
  final double discount;
  final List<PaymentAllocationModel> allocations;

  /// What the allocations have to cover once the discount is applied.
  double get amountToSettle => requiredAmount - discount;

  double get totalPaid =>
      allocations.fold(0, (sum, allocation) => sum + allocation.amountPaid);

  double get remaining => amountToSettle - totalPaid;

  bool get isSettled => _cents(remaining) == 0;

  bool get isOverpaid => _cents(remaining) < 0;

  bool get isDiscountValid =>
      discount >= 0 && _cents(discount) <= _cents(requiredAmount);

  /// Only a split that covers the amount owed exactly may be submitted —
  /// anything else the database would refuse anyway.
  bool get canSubmit => isDiscountValid && isSettled;

  /// Money is held as doubles, so every comparison that decides validity is
  /// made in whole cents: 0.1 + 0.2 is not 0.3.
  static int _cents(double value) => (value * 100).round();

  /// The amount recorded against [merchant], or 0 if it is taking nothing.
  /// A null merchant is cash.
  double amountFor(StadiumMerchantModel? merchant) {
    for (final allocation in allocations) {
      if (allocation.stadiumMerchantId == merchant?.id) {
        return allocation.amountPaid;
      }
    }

    return 0;
  }

  PaymentResult copyWith({
    double? requiredAmount,
    double? discount,
    List<PaymentAllocationModel>? allocations,
  }) {
    return PaymentResult(
      requiredAmount: requiredAmount ?? this.requiredAmount,
      discount: discount ?? this.discount,
      allocations: allocations ?? this.allocations,
    );
  }

  @override
  List<Object?> get props => [requiredAmount, discount, allocations];
}
