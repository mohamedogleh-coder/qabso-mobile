import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qabso_mobile/features/manager/merchants/merchant_notifier_provider.dart';
import 'package:qabso_mobile/features/manager/merchants/merchant_provider_model.dart';
import 'package:qabso_mobile/features/manager/merchants/stadium_merchant_model.dart';
import 'package:qabso_mobile/payments/payment_allocation_model.dart';
import 'package:qabso_mobile/payments/payment_result.dart';
import 'package:qabso_mobile/payments/payment_widget.dart';

const _zaad = StadiumMerchantModel(
  id: 1,
  merchantNumber: '0631111111',
  provider: MerchantProviderModel(
    id: 1,
    providerName: 'Telesom',
    providerService: 'Zaad Service',
  ),
);

const _edahab = StadiumMerchantModel(
  id: 2,
  merchantNumber: '0651111111',
  provider: MerchantProviderModel(
    id: 2,
    providerName: 'Somtel',
    providerService: 'eDahab',
  ),
);

/// Stands in for the real notifier so the widget test never reaches Supabase.
class _FakeMerchants extends MerchantNotifierProvider {
  @override
  Future<List<StadiumMerchantModel>> build() async => const [_zaad, _edahab];
}

void main() {
  group('PaymentResult', () {
    test('settles only when the split covers the amount owed exactly', () {
      const payment = PaymentResult(requiredAmount: 30);

      expect(payment.remaining, 30);
      expect(payment.isSettled, isFalse);
      expect(payment.canSubmit, isFalse);

      final split = payment.copyWith(
        allocations: const [
          PaymentAllocationModel(merchant: _zaad, amountPaid: 10),
          PaymentAllocationModel(merchant: null, amountPaid: 20),
        ],
      );

      expect(split.totalPaid, 30);
      expect(split.remaining, 0);
      expect(split.canSubmit, isTrue);
    });

    test('discount reduces what the split has to cover', () {
      const payment = PaymentResult(requiredAmount: 60, discount: 10);

      expect(payment.amountToSettle, 50);

      final split = payment.copyWith(
        allocations: const [
          PaymentAllocationModel(merchant: _zaad, amountPaid: 50),
        ],
      );

      expect(split.canSubmit, isTrue);
    });

    test('a discount above the required amount is invalid', () {
      const payment = PaymentResult(requiredAmount: 10, discount: 11);

      expect(payment.isDiscountValid, isFalse);
      expect(payment.canSubmit, isFalse);
    });

    test('overpaying is caught, not treated as settled', () {
      const payment = PaymentResult(
        requiredAmount: 10,
        allocations: [PaymentAllocationModel(merchant: _zaad, amountPaid: 12)],
      );

      expect(payment.isOverpaid, isTrue);
      expect(payment.canSubmit, isFalse);
    });

    test('settles on cent-sized amounts that do not add up in binary', () {
      // 0.1 + 0.2 != 0.3 as doubles; comparing in cents is what saves this.
      const payment = PaymentResult(
        requiredAmount: 0.3,
        allocations: [
          PaymentAllocationModel(merchant: _zaad, amountPaid: 0.1),
          PaymentAllocationModel(merchant: _edahab, amountPaid: 0.2),
        ],
      );

      expect(payment.remaining == 0, isFalse, reason: 'raw double comparison');
      expect(payment.isSettled, isTrue);
      expect(payment.canSubmit, isTrue);
    });
  });

  group('PaymentWidget', () {
    testWidgets('builds without writing provider state during build', (
      tester,
    ) async {
      // The regression: seeding requiredAmount from initState threw
      // "Tried to modify a provider while the widget tree was building".
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            merchantNotifierProvider.overrideWith(_FakeMerchants.new),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PaymentWidget(requiredAmount: 30, onSubmit: (_) {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Total Required'), findsOneWidget);
      expect(find.text('Remaining'), findsOneWidget);

      // Nothing allocated yet, so "required" and "remaining" both read 30.
      expect(find.text('\$30.00'), findsNWidgets(2));

      // Both merchants and the cash row are offered.
      expect(find.text('Zaad Service'), findsOneWidget);
      expect(find.text('eDahab'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
    });

    testWidgets('confirm is disabled until the amount is fully split', (
      tester,
    ) async {
      PaymentResult? submitted;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            merchantNotifierProvider.overrideWith(_FakeMerchants.new),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PaymentWidget(
                requiredAmount: 30,
                onSubmit: (payment) => submitted = payment,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // byType matches the exact runtime type, and FilledButton.icon builds a
      // private subclass — so match on the supertype instead.
      final confirm = find.byWidgetPredicate((w) => w is FilledButton);
      VoidCallback? onPressed() =>
          (tester.widget(confirm) as FilledButton).onPressed;

      expect(onPressed(), isNull);

      // Split 10 onto Zaad, then 20 onto eDahab.
      await tester.enterText(find.byType(TextFormField).at(1), '10');
      await tester.pumpAndSettle();
      expect(onPressed(), isNull);

      await tester.enterText(find.byType(TextFormField).at(2), '20');
      await tester.pumpAndSettle();
      expect(onPressed(), isNotNull);

      await tester.tap(confirm);
      await tester.pumpAndSettle();

      expect(submitted, isNotNull);
      expect(submitted!.totalPaid, 30);
      expect(submitted!.allocations.length, 2);
      expect(submitted!.allocations.map((a) => a.stadiumMerchantId).toSet(), {
        1,
        2,
      });
    });
  });
}
