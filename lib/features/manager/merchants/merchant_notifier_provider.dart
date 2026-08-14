import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qabso_mobile/features/manager/merchants/merchant_provider_model.dart';
import 'package:qabso_mobile/features/manager/merchants/merchant_repository.dart';
import 'package:qabso_mobile/features/manager/merchants/stadium_merchant_model.dart';

import '../stadium/stadium_notifier_provider.dart';

/// The payment providers a merchant number can belong to — a read-only
/// lookup seeded by migration and identical for every stadium, so there's no
/// state to manage: reload it with `ref.invalidate`.
final merchantProvidersProvider = FutureProvider<List<MerchantProviderModel>>((
  ref,
) {
  return MerchantRepository.getProviders();
});

final merchantNotifierProvider =
    AsyncNotifierProvider<MerchantNotifierProvider, List<StadiumMerchantModel>>(
      MerchantNotifierProvider.new,
    );

class MerchantNotifierProvider
    extends AsyncNotifier<List<StadiumMerchantModel>> {
  bool _isSaving = false;

  bool get isSaving => _isSaving;

  @override
  FutureOr<List<StadiumMerchantModel>> build() async {
    final stadium = await ref.watch(stadiumNotifierProvider.future);

    if (stadium?.stadiumId == null) return const [];

    return MerchantRepository.getMerchants(stadiumId: stadium!.stadiumId!);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    final stadiumId = ref.read(stadiumNotifierProvider).value?.stadiumId;
    if (stadiumId == null) {
      state = const AsyncData([]);
      return;
    }

    state = await AsyncValue.guard(
      () => MerchantRepository.getMerchants(stadiumId: stadiumId),
    );
  }

  Future<List<StadiumMerchantModel>> addMerchants(
    List<StadiumMerchantModel> merchants,
  ) async {
    if (_isSaving) {
      throw StateError('A merchants save is already in progress.');
    }

    final stadiumId = ref.read(stadiumNotifierProvider).value?.stadiumId;
    if (stadiumId == null) {
      throw StateError('Cannot save merchants: no stadium yet.');
    }

    _isSaving = true;
    try {
      final saved = await MerchantRepository.addMerchants(
        stadiumId: stadiumId,
        merchants: merchants,
      );
      state = AsyncData(saved);
      return saved;
    } finally {
      _isSaving = false;
    }
  }

  Future<List<StadiumMerchantModel>> updateMerchants(
    List<StadiumMerchantModel> merchants,
  ) async {
    if (_isSaving) {
      throw StateError('A merchants save is already in progress.');
    }

    final stadiumId = ref.read(stadiumNotifierProvider).value?.stadiumId;
    if (stadiumId == null) {
      throw StateError('Cannot save merchants: no stadium yet.');
    }

    _isSaving = true;
    try {
      final saved = await MerchantRepository.updateMerchants(
        stadiumId: stadiumId,
        merchants: merchants,
      );
      state = AsyncData(saved);
      return saved;
    } finally {
      _isSaving = false;
    }
  }

  Future<StadiumMerchantModel> updateMerchant(
    StadiumMerchantModel merchant,
  ) async {
    final saved = await updateMerchants([merchant]);

    return _merchantIn(saved, merchant.id);
  }

  /// Turns [merchant] off, or back on, and flips it in state on success.
  /// Unlike the writes above, the repository returns nothing to replace state
  /// with, so the entry is changed locally — no re-fetch.
  ///
  /// The merchant stays in the list either way: a number that has taken money
  /// is kept so past payments still resolve.
  ///
  /// Shares the `_isSaving` guard with the writes above, so this cannot
  /// overlap a save and undo what it just wrote.
  Future<void> setMerchantDisabled(
    StadiumMerchantModel merchant,
    bool disabled,
  ) async {
    if (_isSaving) {
      throw StateError('A merchants save is already in progress.');
    }

    final merchantId = merchant.id;
    if (merchantId == null) {
      throw ArgumentError.value(
        merchant,
        'merchant',
        'An unregistered merchant cannot be turned off.',
      );
    }

    final stadiumId = ref.read(stadiumNotifierProvider).value?.stadiumId;
    if (stadiumId == null) {
      throw StateError('Cannot change a merchant: no stadium yet.');
    }

    _isSaving = true;
    try {
      await MerchantRepository.setMerchantDisabled(
        stadiumId: stadiumId,
        merchantId: merchantId,
        disabled: disabled,
      );
      state = AsyncData([
        for (final saved in state.value ?? const <StadiumMerchantModel>[])
          if (saved.id == merchantId)
            saved.copyWith(disabled: disabled)
          else
            saved,
      ]);
    } finally {
      _isSaving = false;
    }
  }

  static StadiumMerchantModel _merchantIn(
    List<StadiumMerchantModel> merchants,
    int? id,
  ) {
    return merchants.firstWhere(
      (merchant) => merchant.id == id,
      orElse: () =>
          throw StateError('Merchant $id is not registered to this stadium.'),
    );
  }
}
