import 'package:qabso_mobile/features/manager/reports/models/event_summery_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../utill/app_date_util.dart';

class ReportsRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static Future<List<EventsSummaryModel>> eventsSummery({
    String? stadiumId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    if (startDate != null && endDate != null && startDate.isAfter(endDate)) {
      throw ArgumentError('The start date cannot be after the end date.');
    }
    final rows =
        await _client.rpc(
              'events_summary_fn',
              params: {
                'p_stadium_id': stadiumId,
                'p_start_date': startDate == null
                    ? null
                    : AppDateUtil.formatDate(startDate),
                'p_end_date': endDate == null
                    ? null
                    : AppDateUtil.formatDate(endDate),
              },
            )
            as List;

    return rows
        .map((row) => EventsSummaryModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }
}
