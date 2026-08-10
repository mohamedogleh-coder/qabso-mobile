import 'package:flutter_test/flutter_test.dart';
import 'package:qabso_mobile/utill/supabase_storage_service.dart';

/// [SupabaseStorageService.storagePathFromPublicUrl] is what stands between
/// a URL the UI happens to hold and a `remove()` call against storage, so
/// it's covered directly. It reads only [SupabaseStorageService.bucket] (a
/// const), never `Supabase.instance`, so it needs no initialized client.
void main() {
  const host = 'https://abcdefgh.supabase.co/storage/v1';

  group('storagePathFromPublicUrl', () {
    test('resolves a public URL back to its object path', () {
      expect(
        SupabaseStorageService.storagePathFromPublicUrl(
          '$host/object/public/playground/stadiums/s1/fields/3/photo.png',
        ),
        'stadiums/s1/fields/3/photo.png',
      );
    });

    test('ignores a cache-busting query string', () {
      expect(
        SupabaseStorageService.storagePathFromPublicUrl(
          '$host/object/public/playground/stadiums/s1/photo.png?t=1723150000000',
        ),
        'stadiums/s1/photo.png',
      );
    });

    test('resolves a signed URL for the same bucket', () {
      expect(
        SupabaseStorageService.storagePathFromPublicUrl(
          '$host/object/sign/playground/stadiums/s1/photo.png',
        ),
        'stadiums/s1/photo.png',
      );
    });

    test('decodes percent-encoded segments', () {
      expect(
        SupabaseStorageService.storagePathFromPublicUrl(
          '$host/object/public/playground/stadiums/s1/my%20photo.png',
        ),
        'stadiums/s1/my photo.png',
      );
    });

    test('does not mistake a folder named like the bucket for the bucket', () {
      expect(
        SupabaseStorageService.storagePathFromPublicUrl(
          '$host/object/public/avatars/playground/photo.png',
        ),
        isNull,
      );
    });

    test('returns null for another bucket, a bare path, or an empty path', () {
      expect(
        SupabaseStorageService.storagePathFromPublicUrl(
          '$host/object/public/avatars/stadiums/s1/photo.png',
        ),
        isNull,
      );
      expect(
        SupabaseStorageService.storagePathFromPublicUrl(
          'stadiums/s1/photo.png',
        ),
        isNull,
      );
      expect(
        SupabaseStorageService.storagePathFromPublicUrl(
          '$host/object/public/playground',
        ),
        isNull,
      );
    });
  });
}
