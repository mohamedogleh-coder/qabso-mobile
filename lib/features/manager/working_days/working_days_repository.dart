import 'package:supabase_flutter/supabase_flutter.dart';

import 'working_days.dart';

class WorkingDaysRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static const _workingDaysTable = 'stadium_working_days';

  /// Reads [stadiumId]'s working days, ordered Monday (1) to Sunday (7). A
  /// stadium whose days have never been saved has no rows yet, so this
  /// returns an empty list — callers decide what an unconfigured week looks
  /// like.
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

  /// Saves [days] for [stadiumId] in a single `upsert_stadium_working_days`
  /// call — one day, a few, or all seven at once. The function inserts the
  /// days that don't exist yet and updates the ones that do, so callers
  /// never have to know which; a day repeated in [days] isn't an error, the
  /// last entry wins.
  ///
  /// Returns the stadium's *full* week as stored, ordered by day, not just
  /// the days in [days] — state can be replaced wholesale with this, so a
  /// partial save can't leave a caller holding a half-updated week.
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

  /// Saves a single [day] — its open/close time and whether it's open — and
  /// returns it as stored. A thin wrapper over [saveWorkingDays] so there's
  /// only one write path; call that directly when the whole week is wanted
  /// back.
  static Future<WorkingDayModel> saveWorkingDay({
    required String stadiumId,
    required WorkingDayModel day,
  }) async {
    final week = await saveWorkingDays(stadiumId: stadiumId, days: [day]);

    return week.firstWhere((saved) => saved.dayOfWeek == day.dayOfWeek);
  }

  /// Builds the JSON object `upsert_stadium_working_days` expects. `id` is
  /// left out on purpose: the row is identified by
  /// `(stadium_id, day_of_week)`, so a stale client-side id can't point the
  /// write at the wrong row.
  ///
  /// The open/close check mirrors the table's `close_time > open_time`
  /// constraint so an impossible day fails here, legibly, instead of coming
  /// back as a Postgres constraint violation. Zero-padded `HH:mm` compares
  /// correctly as text, so no time parsing is needed.
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

  /// Trims a `time` value to the `HH:mm` the app works in — Postgres hands
  /// back `HH:mm:ss` for that column, and those seconds are always `00`
  /// here since they're never written.
  static String _hhmm(String time) =>
      time.length > 5 ? time.substring(0, 5) : time;
}
