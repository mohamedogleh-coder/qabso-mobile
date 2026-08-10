import 'package:supabase_flutter/supabase_flutter.dart';

import 'working_days.dart';

class WorkingDaysRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static const _workingDaysTable = 'stadium_working_days';

  static Future<List<WorkingDayModel>> getWorkingDays({
    required String stadiumId,
  }) async {
    final rows = await _client
        .from(_workingDaysTable)
        .select()
        .eq('stadium_id', stadiumId)
        .order('day_of_week', ascending: true);

    return rows.map(_fromRow).toList();
  }

  static Future<List<WorkingDayModel>> saveWorkingDays({
    required String stadiumId,
    required List<WorkingDayModel> days,
  }) async {
    if (days.isEmpty) {
      throw ArgumentError.value(days, 'days', 'No working days to save.');
    }

    final rows =
        await _client.rpc(
              'upsert_stadium_working_days',
              params: {
                'p_stadium_id': stadiumId,
                'p_days': days.map(_toPayload).toList(),
              },
            )
            as List;

    return rows.map((row) => _fromRow(row as Map<String, dynamic>)).toList();
  }

  static Map<String, dynamic> _toPayload(WorkingDayModel day) {
    final openTime = _hhmm(day.openTime);
    final closeTime = _hhmm(day.closeTime);

    if (closeTime.compareTo(openTime) <= 0) {
      throw ArgumentError(
        'Day ${day.dayOfWeek}: closeTime ($closeTime) must be after '
        'openTime ($openTime).',
      );
    }

    return {
      'day_of_week': day.dayOfWeek,
      'open_time': openTime,
      'close_time': closeTime,
      'is_open': day.isOpen,
    };
  }

  static WorkingDayModel _fromRow(Map<String, dynamic> row) {
    final day = WorkingDayModel.fromJson(row);

    return day.copyWith(
      openTime: _hhmm(day.openTime),
      closeTime: _hhmm(day.closeTime),
    );
  }

  static String _hhmm(String time) =>
      time.length > 5 ? time.substring(0, 5) : time;
}
