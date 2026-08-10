import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../utill/supabase_storage_service.dart';
import 'field_model.dart';

class FieldRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static const _fieldsTable = 'fields';
  static const _fieldsWithImagesView = 'fields_with_images_view';
  static const _fieldImagesTable = 'field_images';

  /// Reads fields for [stadiumId] from [_fieldsWithImagesView], which
  /// aggregates each field's `field_images.image_path` rows as-is —
  /// storage paths, not URLs; the database only ever stores paths. Each
  /// path is converted to a public URL here via
  /// [SupabaseStorageService.getPublicUrl] before being returned, so
  /// [FieldModel.fieldImages] is always ready for `Image.network`.
  static Future<List<FieldModel>> getFields({required String stadiumId}) async {
    final rows = await _client
        .from(_fieldsWithImagesView)
        .select()
        .eq('stadium_id', stadiumId)
        .order('id', ascending: true);

    return rows.map((row) {
      final field = FieldModel.fromJson(row);
      return field.copyWith(
        fieldImages: field.fieldImages
            .map(SupabaseStorageService.getPublicUrl)
            .toList(),
      );
    }).toList();
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
  /// Each resulting storage path — never the full URL — is saved as a
  /// `field_images` row. Returns each image's public URL (via
  /// [SupabaseStorageService.getPublicUrl], through [SupabaseStorageService
  /// .uploadFile]'s own return value), in the same order as [files], ready
  /// for [FieldModel.fieldImages].
  ///
  /// If a file uploads but its `field_images` row fails to write, the
  /// upload is rolled back (best-effort) so storage doesn't accumulate
  /// files with no matching row, and the original error is rethrown.
  static Future<List<String>> uploadFieldImages({
    required String stadiumId,
    required int fieldId,
    required List<File> files,
  }) async {
    final urls = <String>[];
    for (final file in files) {
      final fileName = SupabaseStorageService.randomFileName(file.path);
      final path = 'stadiums/$stadiumId/fields/$fieldId/$fileName';

      final publicUrl = await SupabaseStorageService.uploadFile(
        path: path,
        file: file,
      );

      try {
        await _client.from(_fieldImagesTable).insert({
          'field_id': fieldId,
          'image_path': path,
        });
      } catch (_) {
        await SupabaseStorageService.deleteFile(path).catchError((_) {});
        rethrow;
      }

      urls.add(publicUrl);
    }
    return urls;
  }

  /// Removes one already-uploaded image of [fieldId], identified by the
  /// public [imageUrl] the UI renders (the DB only ever stores paths, so the
  /// URL is resolved back to its path via
  /// [SupabaseStorageService.storagePathFromPublicUrl] first — the URL is
  /// never handed to storage as if it were a path).
  ///
  /// The `field_images` row goes first and is deleted with `.select()` so a
  /// URL that matches no row for this field throws instead of silently
  /// removing a file: the row is what the UI reads back, so as long as it
  /// survives, nothing was lost. Only once the row is gone is the storage
  /// object removed — using the path the row itself returned — and a failure
  /// there is swallowed: the image is already unlinked and invisible, and
  /// re-throwing would only leave the UI showing an image that no longer
  /// exists. The worst case is an orphaned file nothing references.
  static Future<void> deleteFieldImage({
    required int fieldId,
    required String imageUrl,
  }) async {
    final imagePath = SupabaseStorageService.storagePathFromPublicUrl(imageUrl);
    if (imagePath == null) {
      throw ArgumentError.value(
        imageUrl,
        'imageUrl',
        'Not a public URL for the ${SupabaseStorageService.bucket} bucket.',
      );
    }

    final deletedRows = await _client
        .from(_fieldImagesTable)
        .delete()
        .eq('field_id', fieldId)
        .eq('image_path', imagePath)
        .select('image_path');

    if (deletedRows.isEmpty) {
      throw StateError('No image row found for field $fieldId.');
    }

    for (final row in deletedRows) {
      final storedPath = row['image_path'] as String;
      await SupabaseStorageService.deleteFile(storedPath).catchError((_) {});
    }
  }
}
