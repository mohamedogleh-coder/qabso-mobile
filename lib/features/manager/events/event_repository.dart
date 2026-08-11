import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../utill/app_date_util.dart';
import 'time_slots_model.dart';

class EventRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<List<TimeSlotModel>> getTimeSlots({
    required int fieldId,
    required DateTime date,
  }) async {
    final rows =
        await _client.rpc(
              'generate_booking_time_seq_fn',
              params: {
                'p_field_id': fieldId,
                'p_date': AppDateUtil.formatDate(date),
              },
            )
            as List;

    return rows
        .map((row) => TimeSlotModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
