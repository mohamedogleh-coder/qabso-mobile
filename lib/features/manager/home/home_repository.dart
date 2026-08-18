import 'package:supabase_flutter/supabase_flutter.dart';

import 'manager_home_model.dart';

class HomeRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static const _managerHomeFn = 'manager_home_fn';

  /// Reads today at one stadium: the games on, the slots still free, what is
  /// owed when half booking is on, the next game, and whether anything is
  /// stopping bookings.
  ///
  /// Only the stadium is named, so anything holding a stadium id can call it.
  static Future<ManagerHomeModel> getManagerHome({
    required String stadiumId,
  }) async {
    final rows =
        await _client.rpc(
              _managerHomeFn,
              params: {'p_stadium_id': stadiumId},
            )
            as List;

    if (rows.isEmpty) {
      throw StateError('Stadium $stadiumId was not found.');
    }

    return ManagerHomeModel.fromJson(
      Map<String, dynamic>.from(rows.first as Map),
    );
  }
}
