import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../utill/supabase_storage_service.dart';
import '../working_days/working_days.dart';
import 'models/stadium_profile_model.dart';
import 'stadium_information_model.dart';
import 'stadium_model.dart';

class StadiumRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static const _managerStadiumsView = 'manager_stadiums_view';
  static const _stadiumInformationFn = 'stadium_information_fn';
  static const _stadiumProfileFn = 'stadium_profile_fn';
  static const _stadiumWorkingDaysFn = 'stadium_working_days_fn';

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

  /// Reads the working days a stadium has saved, in week order.
  ///
  /// Only the days the stadium wrote down come back, so the list can be
  /// shorter than seven. A day that is missing was never saved.
  ///
  /// Postgres hands a `time` over as HH:MM:SS, so both hours are cut back to
  /// HH:mm here and the model always carries the shape the screen shows.
  static Future<List<WorkingDayModel>> getStadiumWorkingDays({
    required String stadiumId,
  }) async {
    final rows =
        await _client.rpc(
              _stadiumWorkingDaysFn,
              params: {'p_stadium_id': stadiumId},
            )
            as List;

    return rows.map((row) {
      final day = WorkingDayModel.fromJson(
        Map<String, dynamic>.from(row as Map),
      );

      return day.copyWith(
        openTime: _hhmm(day.openTime),
        closeTime: _hhmm(day.closeTime),
      );
    }).toList();
  }

  static String _hhmm(String time) =>
      time.length > 5 ? time.substring(0, 5) : time;

  /// Reads a stadium's profile: the stadium itself, how many fields are open
  /// to booking, and every field picture with the field it belongs to.
  ///
  /// Only the stadium is named, so anything holding a stadium id can call it.
  ///
  /// The database keeps storage paths, not links, so each picture gains an
  /// `image_url` built from its `image_path` before the model reads it — the
  /// same conversion FieldRepository.getFields does.
  static Future<StadiumProfileModel> getStadiumProfile({
    required String stadiumId,
  }) async {
    final rows =
        await _client.rpc(
              _stadiumProfileFn,
              params: {'p_stadium_id': stadiumId},
            )
            as List;

    if (rows.isEmpty) {
      throw StateError('Stadium $stadiumId was not found.');
    }

    final json = Map<String, dynamic>.from(rows.first as Map);

    json['field_images'] = (json['field_images'] as List? ?? const []).map((
      image,
    ) {
      final imageJson = Map<String, dynamic>.from(image as Map);

      imageJson['image_url'] = SupabaseStorageService.getPublicUrl(
        imageJson['image_path'] as String,
      );

      return imageJson;
    }).toList();

    return StadiumProfileModel.fromJson(json);
  }

  /// Reads one stadium with all of its fields and their pictures.
  ///
  /// Only the stadium is named, so anything holding a stadium id can call it —
  /// a favourite card, the explore list, or the manager's own screens.
  ///
  /// The database keeps storage paths rather than links, so each path is
  /// turned into a public URL before the model is built, the same conversion
  /// FieldRepository.getFields does. It is done on the json rather than on the
  /// finished model because [StadiumInformationModel] has no copyWith of its
  /// own, and adding one to carry a single list would earn nothing.
  static Future<StadiumInformationModel> getStadiumInformation({
    required String stadiumId,
  }) async {
    final rows =
        await _client.rpc(
              _stadiumInformationFn,
              params: {'p_stadium_id': stadiumId},
            )
            as List;

    if (rows.isEmpty) {
      throw StateError('Stadium $stadiumId was not found.');
    }

    final json = Map<String, dynamic>.from(rows.first as Map);

    json['fields'] = (json['fields'] as List? ?? const []).map((field) {
      final fieldJson = Map<String, dynamic>.from(field as Map);

      fieldJson['field_images'] =
          (fieldJson['field_images'] as List? ?? const [])
              .map(
                (path) => SupabaseStorageService.getPublicUrl(path as String),
              )
              .toList();

      return fieldJson;
    }).toList();

    return StadiumInformationModel.fromJson(json);
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
