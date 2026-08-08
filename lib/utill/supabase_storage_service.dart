import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Thin, reusable wrapper around Supabase Storage operations against the
/// shared `playground` bucket. Callers own the storage path — this service
/// has no feature-specific knowledge (e.g. profile images).
abstract class SupabaseStorageService {
  static const String bucket = 'playground';

  static StorageFileApi get _files =>
      Supabase.instance.client.storage.from(bucket);

  /// Uploads [file] to [path]. Fails if a file already exists at [path]
  /// unless [upsert] is true. Returns the resulting public URL.
  static Future<String> uploadFile({
    required String path,
    required File file,
    bool upsert = false,
  }) async {
    await _files.upload(path, file, fileOptions: FileOptions(upsert: upsert));
    return getPublicUrl(path);
  }

  /// Replaces the existing file at [path] with [file]. Returns the resulting
  /// public URL, cache-busted so clients don't keep serving the old file
  /// that used to live at the same path.
  static Future<String> updateFile({
    required String path,
    required File file,
  }) async {
    await _files.update(path, file);
    return getPublicUrl(path, bustCache: true);
  }

  /// Deletes the file at [path], if it exists.
  static Future<void> deleteFile(String path) async {
    await _files.remove([path]);
  }

  /// Returns the public URL for [path]. Pass [bustCache] to force clients to
  /// bypass any CDN-cached copy — useful right after replacing a file that
  /// keeps the same path.
  static String getPublicUrl(String path, {bool bustCache = false}) {
    return _files.getPublicUrl(
      path,
      cacheNonce: bustCache
          ? DateTime.now().millisecondsSinceEpoch.toString()
          : null,
    );
  }
}
