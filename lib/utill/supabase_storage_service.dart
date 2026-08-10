import 'dart:io';
import 'dart:math';

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

  /// Resolves the storage object path inside [bucket] that [url] points at —
  /// the inverse of [getPublicUrl] (e.g.
  /// `'https://…/storage/v1/object/public/playground/stadiums/a/b.png'` ->
  /// `'stadiums/a/b.png'`). Any cache-busting query string is ignored.
  ///
  /// Returns `null` when [url] isn't a storage URL for this bucket, so
  /// callers can refuse to delete rather than guess at a path.
  static String? storagePathFromPublicUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    // `.../object/{public|sign}/{bucket}/{path...}`
    final segments = uri.pathSegments;
    final objectIndex = segments.indexOf('object');
    if (objectIndex == -1 || objectIndex + 3 >= segments.length) return null;
    if (segments[objectIndex + 2] != bucket) return null;

    final path = segments.sublist(objectIndex + 3).join('/');
    return path.isEmpty ? null : path;
  }

  /// Generates a random, collision-resistant filename that preserves
  /// [sourcePath]'s extension (e.g. `'.../photo.PNG'` ->
  /// `'1723150000000_a1b2c3d4.png'`), for callers that need a fresh unique
  /// name per upload rather than a caller-chosen stable path.
  static String randomFileName(String sourcePath) {
    final dotIndex = sourcePath.lastIndexOf('.');
    final extension = dotIndex == -1 || dotIndex == sourcePath.length - 1
        ? ''
        : sourcePath.substring(dotIndex).toLowerCase();

    final random = Random();
    final suffix = List.generate(
      8,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();

    return '${DateTime.now().microsecondsSinceEpoch}_$suffix$extension';
  }
}
