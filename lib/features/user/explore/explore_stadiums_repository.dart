import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../utill/app_date_util.dart';
import 'models/explored_stadium_model.dart';

class ExploreStadiumsRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Finds the stadiums a customer can play at on [date], each with the
  /// smallest field that still holds [capacity] players.
  ///
  /// [time] is optional. Leaving it out asks "which stadiums work that day",
  /// and the customer picks the hour from the stadium's own booking grid.
  ///
  /// [latitude] and [longitude] are only used together. With both, every
  /// stadium comes back with how far away it is and the nearest are first;
  /// [radiusKm] then drops the ones further away than that.
  ///
  /// Nothing is checked here. A date or a time that has passed is refused by
  /// the function itself, and its message is what the user should see.
  static Future<List<ExploredStadiumModel>> searchStadiums({
    required int capacity,
    required DateTime date,
    TimeOfDay? time,
    double? latitude,
    double? longitude,
    double? radiusKm,
  }) async {
    final rows =
        await _client.rpc(
              'search_stadiums_fn',
              params: {
                'p_capacity': capacity,
                'p_date': AppDateUtil.formatDate(date),
                'p_time': time == null
                    ? null
                    : AppDateUtil.formatTimeOfDay(time),
                'p_latitude': latitude,
                'p_longitude': longitude,
                'p_radius': radiusKm,
              },
            )
            as List;

    return rows
        .map(
          (row) => ExploredStadiumModel.fromJson(row as Map<String, dynamic>),
        )
        .toList();
  }
}
