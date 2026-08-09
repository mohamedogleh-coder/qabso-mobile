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
}
