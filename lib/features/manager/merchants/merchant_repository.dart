import 'package:supabase_flutter/supabase_flutter.dart';

import 'merchant_provider_model.dart';
import 'stadium_merchant_model.dart';

class MerchantRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static const _merchantsTable = 'stadium_merchants';
  static const _providersTable = 'providers';

  static const _merchantColumns =
      'id, merchant_number, disabled, provider:providers(*)';

  /// Reads the payment providers a merchant number can belong to — a fixed
  /// lookup seeded by migration, the same for every stadium, so it isn't
  /// scoped by one.
  static Future<List<MerchantProviderModel>> getProviders() async {
    final rows = await _client
        .from(_providersTable)
        .select()
        .order('id', ascending: true);

    return rows.map(MerchantProviderModel.fromJson).toList();
  }

  static Future<List<StadiumMerchantModel>> getMerchants({
    required String stadiumId,
  }) async {
    final rows = await _client
        .from(_merchantsTable)
        .select(_merchantColumns)
        .eq('stadium_id', stadiumId)
        .order('id', ascending: true);

    return rows.map(StadiumMerchantModel.fromJson).toList();
  }

  static Future<List<StadiumMerchantModel>> addMerchants({
    required String stadiumId,
    required List<StadiumMerchantModel> merchants,
  }) {
    if (merchants.any((merchant) => merchant.id != null)) {
      throw ArgumentError.value(
        merchants,
        'merchants',
        'Already registered merchants cannot be added again.',
      );
    }

    return _saveMerchants(stadiumId: stadiumId, merchants: merchants);
  }

  /// Updates every merchant in [merchants] in a single call and returns the
  /// stadium's full set as stored.
  ///
  /// Each row is matched on its id, so all of them must already carry one —
  /// an unsaved merchant belongs in [addMerchants].
  static Future<List<StadiumMerchantModel>> updateMerchants({
    required String stadiumId,
    required List<StadiumMerchantModel> merchants,
  }) {
    if (merchants.any((merchant) => merchant.id == null)) {
      throw ArgumentError.value(
        merchants,
        'merchants',
        'Unregistered merchants cannot be updated.',
      );
    }

    return _saveMerchants(stadiumId: stadiumId, merchants: merchants);
  }

  static Future<StadiumMerchantModel> updateMerchant({
    required String stadiumId,
    required StadiumMerchantModel merchant,
  }) async {
    final saved = await updateMerchants(
      stadiumId: stadiumId,
      merchants: [merchant],
    );

    return saved.firstWhere(
      (updated) => updated.id == merchant.id,
      orElse: () => throw StateError(
        'Merchant ${merchant.id} is not registered to this stadium.',
      ),
    );
  }

  /// Turns one merchant number off, or back on.
  ///
  /// A number that has taken money is part of the ledger and cannot be
  /// deleted — `transaction_details` points at it with ON DELETE RESTRICT —
  /// so this is how a manager retires one.
  ///
  /// Scoped by `stadium_id` as well as `id`, so an id belonging to another
  /// stadium matches nothing and throws rather than being changed. The
  /// `.select()` is what makes that visible, since an update matching no row
  /// is otherwise silently fine.
  static Future<void> setMerchantDisabled({
    required String stadiumId,
    required int merchantId,
    required bool disabled,
  }) async {
    final updatedRows = await _client
        .from(_merchantsTable)
        .update({'disabled': disabled})
        .eq('id', merchantId)
        .eq('stadium_id', stadiumId)
        .select('id');

    if (updatedRows.isEmpty) {
      throw StateError(
        'Merchant $merchantId is not registered to this stadium.',
      );
    }
  }

  static Future<List<StadiumMerchantModel>> _saveMerchants({
    required String stadiumId,
    required List<StadiumMerchantModel> merchants,
  }) async {
    if (merchants.isEmpty) {
      throw ArgumentError.value(
        merchants,
        'merchants',
        'No merchants to save.',
      );
    }

    final rows =
        await _client.rpc(
              'upsert_stadium_merchants',
              params: {
                'p_stadium_id': stadiumId,
                'p_merchants': merchants.map(_toPayload).toList(),
              },
            )
            as List;

    return rows
        .map(
          (row) => StadiumMerchantModel.fromJson(row as Map<String, dynamic>),
        )
        .toList();
  }

  static Map<String, dynamic> _toPayload(StadiumMerchantModel merchant) {
    final merchantNumber = merchant.merchantNumber.trim();

    if (merchantNumber.isEmpty) {
      throw ArgumentError.value(
        merchant.merchantNumber,
        'merchantNumber',
        'A merchant number is required.',
      );
    }
    if (merchantNumber.length > 20) {
      throw ArgumentError.value(
        merchant.merchantNumber,
        'merchantNumber',
        'A merchant number cannot exceed 20 characters.',
      );
    }

    return {
      'id': merchant.id,
      'provider_id': merchant.provider.id,
      'merchant_number': merchantNumber,
    };
  }
}
