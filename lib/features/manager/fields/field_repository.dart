import 'package:supabase_flutter/supabase_flutter.dart';

import 'field_model.dart';

class FieldRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static const _fieldsTable = 'fields';
  static const _fieldsWithImagesView = 'fields_with_images_view';

  static Future<List<FieldModel>> getFields({required String stadiumId}) async {
    final rows = await _client
        .from(_fieldsWithImagesView)
        .select()
        .eq('stadium_id', stadiumId)
        .order('created_at');

    return rows.map(FieldModel.fromJson).toList();
  }

  /// Creates a field for [stadiumId] through the `create_field` DB
  /// function, attaching [FieldModel.fieldImages] as its image paths.
  ///
  /// The function only returns the new id, so the rest of the returned
  /// [FieldModel] — including the image paths, which the function accepted
  /// as submitted — is built from [model] rather than an extra read.
  static Future<FieldModel> createField({
    required String stadiumId,
    required FieldModel model,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Cannot create field: no authenticated user.');
    }

    final fieldId =
        await _client.rpc(
              'create_field',
              params: {
                'p_stadium_id': stadiumId,
                'p_capacity': model.capacity,
                'p_cost': model.cost,
                'p_allow_booking': model.allowBooking,
                'p_image_paths': model.fieldImages,
              },
            )
            as int;

    return model.copyWith(id: fieldId);
  }

  /// Updates the editable fields of [model] (which must already have a
  /// [FieldModel.id]), scoped to [stadiumId] so a field can't be updated
  /// outside the stadium it belongs to. Images aren't touched here, so the
  /// known [FieldModel.fieldImages] is carried over onto the result as-is.
  ///
  /// Unlike [createField], this goes through a plain table update rather
  /// than a DB function, so `.select()` can return the saved row in the
  /// same request — no separate re-fetch needed either way.
  static Future<FieldModel> updateField({
    required String stadiumId,
    required FieldModel model,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Cannot update field: no authenticated user.');
    }

    final row = await _client
        .from(_fieldsTable)
        .update({
          'capacity': model.capacity,
          'cost': model.cost,
          'allow_booking': model.allowBooking,
        })
        .eq('id', model.id!)
        .eq('stadium_id', stadiumId)
        .select()
        .single();

    return FieldModel.fromJson(row).copyWith(fieldImages: model.fieldImages);
  }
}
