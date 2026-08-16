import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../utill/app_date_util.dart';
import '../../../utill/supabase_storage_service.dart';
import 'models/explored_stadium_model.dart';

class ExploreStadiumsRepository {
  static final SupabaseClient _client = Supabase.instance.client;

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
              'explore_stadiums_fn',
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

    // The database keeps storage paths, not links. Each path is turned into a
    // public URL here, the same way FieldRepository.getFields does, so
    // ExploredStadiumModel.imageUrls is always ready for Image.network.
    return rows.map((row) {
      final json = Map<String, dynamic>.from(row as Map);

      json['image_urls'] = (json['image_urls'] as List? ?? const [])
          .map((path) => SupabaseStorageService.getPublicUrl(path as String))
          .toList();

      return ExploredStadiumModel.fromJson(json);
    }).toList();
  }
}
