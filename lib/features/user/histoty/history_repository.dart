import 'package:supabase_flutter/supabase_flutter.dart';

import 'history_model.dart';

class HistoryRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static const _historyView = 'user_bookings_history_view';

  /// Reads the bookings the signed-in user paid on, newest game first.
  ///
  /// Nothing here names the user. The view reads auth.uid() itself, so it
  /// already answers with this user's own bookings alone.
  static Future<List<HistoryModel>> getHistory() async {
    final rows = await _client
        .from(_historyView)
        .select()
        .order('event_start', ascending: false);

    return rows.map(HistoryModel.fromJson).toList();
  }
}
