import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qabso_mobile/payments/payment_allocation_model.dart';
import 'package:qabso_mobile/payments/payment_result.dart';

import '../features/manager/merchants/stadium_merchant_model.dart';

/// The payment being put together right now.
///
/// Scoped, not global: the amount being collected is only known where the
/// payment starts, so this is overridden there with a notifier built around
/// it. [PaymentWidget] does that for you — reading it outside one is a
/// mistake, hence the throw rather than a silent zero.
///
/// Auto-dispose, so closing the payment throws its split away.
final paymentNotifierProvider =
    NotifierProvider.autoDispose<PaymentNotifier, PaymentResult>(
      () => throw UnimplementedError(
        'paymentNotifierProvider must be overridden with the amount being '
        'collected. Use PaymentWidget, which scopes it.',
      ),
    );

class PaymentNotifier extends Notifier<PaymentResult> {
  PaymentNotifier(this.requiredAmount);

  final double requiredAmount;

  @override
  PaymentResult build() => PaymentResult(requiredAmount: requiredAmount);

  void setDiscount(double discount) {
    state = state.copyWith(discount: discount);
  }

  /// Records what [merchant] is taking — or, with a null merchant, what is
  /// being paid in cash.
  ///
  /// Zero removes the allocation instead of storing it:
  /// `transaction_details.amount_paid` must be greater than zero, so a row
  /// worth nothing is one the database would refuse. That keeps
  /// [PaymentResult.allocations] always ready to submit as it stands.
  void setAmount({StadiumMerchantModel? merchant, required double amount}) {
    state = state.copyWith(
      allocations: [
        for (final allocation in state.allocations)
          if (allocation.stadiumMerchantId != merchant?.id) allocation,
        if (amount > 0)
          PaymentAllocationModel(merchant: merchant, amountPaid: amount),
      ],
    );
  }
}
