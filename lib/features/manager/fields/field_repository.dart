import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../utill/supabase_storage_service.dart';
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
        .order('id',ascending: true);

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

  /// Uploads [files] to the `playground` bucket under
  /// `stadiums/{stadiumId}/fields/{fieldId}/<random-file-name>`, one path
  /// per file with a fresh random name (extension preserved) so uploads
  /// never collide with each other or with a previous attempt.
  ///
  /// Storage only — this does not write `field_images` rows, which aren't
  /// implemented yet. Returns the public URL of each uploaded file, in the
  /// same order as [files].
  static Future<List<String>> uploadFieldImages({
    required String stadiumId,
    required int fieldId,
    required List<File> files,
  }) async {
    final urls = <String>[];
    for (final file in files) {
      final fileName = SupabaseStorageService.randomFileName(file.path);
      final path = 'stadiums/$stadiumId/fields/$fieldId/$fileName';
      urls.add(await SupabaseStorageService.uploadFile(path: path, file: file));
    }
    return urls;
  }
}
