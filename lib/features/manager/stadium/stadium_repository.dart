import 'package:supabase_flutter/supabase_flutter.dart';

import 'stadium_model.dart';

class StadiumRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static const _managerStadiumsView = 'manager_stadiums_view';

  static Future<StadiumModel?> getCurrentManagerStadium() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _client
        .from(_managerStadiumsView)
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (row == null) return null;

    return StadiumModel.fromJson(row);
  }

  static Future<StadiumModel> upsertStadium({
    required StadiumModel model,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Cannot save stadium: no authenticated user.');
    }

    final stadiumId =
        await _client.rpc(
              'upsert_stadium',
              params: {
                'p_stadium_id': model.stadiumId,
                'p_stadium_name': model.stadiumName,
                'p_extra_time': model.extraTime,
                'p_latitude': model.latitude,
                'p_longitude': model.longitude,
                'p_allow_half_booking': model.allowHalfBooking,
                'p_manager_id': userId,
              },
            )
            as String;

    return model.copyWith(stadiumId: stadiumId);
  }
}
