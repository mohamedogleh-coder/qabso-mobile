import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utill/supabase_storage_service.dart';
import 'app_user_model.dart';

/// Bridges Supabase Auth (source of truth for authentication) with the
/// `public.app_users` table (source of truth for application profile data).
///
/// This repository only reads/writes data — it must never navigate or touch
/// the UI layer.
class AuthRepository {
  AuthRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _table = 'app_users';

  /// The stable Storage path for a user's profile image. Always the same
  /// for a given [userId], so a new upload replaces the previous image
  /// instead of creating an orphaned file.
  String avatarStoragePath(String userId) => 'user_profiles/$userId.jpg';

  /// The current Supabase Auth session, or `null` if unauthenticated.
  Session? get currentSession => _client.auth.currentSession;

  /// Emits whenever Supabase Auth state changes (sign-in, sign-out, token
  /// refresh, etc).
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  /// Signs in with an email/password combination.
  ///
  /// Throws an [AuthException] on invalid credentials.
  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  /// Starts the Google OAuth sign-in flow in an external browser.
  ///
  /// Completion happens asynchronously via the deep-link redirect; listen to
  /// [onAuthStateChange] to observe the resulting session.
  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(OAuthProvider.google);
  }

  /// Starts the Facebook OAuth sign-in flow in an external browser.
  ///
  /// Completion happens asynchronously via the deep-link redirect; listen to
  /// [onAuthStateChange] to observe the resulting session.
  Future<void> signInWithFacebook() async {
    await _client.auth.signInWithOAuth(OAuthProvider.facebook);
  }

  /// Returns the `app_users` profile for the current Supabase Auth user.
  ///
  /// Returns `null` if there is no authenticated user, or if the
  /// authenticated user has no matching `app_users` row yet.
  Future<AppUserModel?> getCurrentAppUser() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final row = await _client
        .from(_table)
        .select()
        .eq('id', userId)
        .maybeSingle();

    if (row == null) return null;
    return AppUserModel.fromJson(row);
  }

  /// Creates the `app_users` profile row for the current authenticated user,
  /// using their Supabase Auth ID as `app_users.id`.
  ///
  /// If [avatarFile] is provided, it is uploaded to this user's stable
  /// avatar path before the row is written.
  Future<AppUserModel> createUserProfile({
    required String fullName,
    required String phoneNumber,
    File? avatarFile,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Cannot create profile: no authenticated user.');
    }

    String? photoUrl;
    if (avatarFile != null) {
      photoUrl = await SupabaseStorageService.uploadFile(
        path: avatarStoragePath(userId),
        file: avatarFile,
        upsert: true,
      );
    }

    final row = await _client
        .from(_table)
        .insert({
          'id': userId,
          'full_name': fullName,
          'phone_number': phoneNumber,
          'photo_url': ?photoUrl,
        })
        .select()
        .single();

    return AppUserModel.fromJson(row);
  }

  /// Updates editable profile fields for the current authenticated user.
  ///
  /// Only `full_name`, `phone_number`, and the avatar can be changed here —
  /// `id`, `role`, `created_at`, and `updated_at` are intentionally not
  /// exposed. If [avatarFile] is provided, it replaces the file at this
  /// user's stable avatar path and `photo_url` is updated to match; the
  /// database is otherwise left untouched for fields that weren't passed.
  Future<AppUserModel> updateUserInfo({
    String? fullName,
    String? phoneNumber,
    File? avatarFile,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Cannot update profile: no authenticated user.');
    }

    String? photoUrl;
    if (avatarFile != null) {
      photoUrl = await SupabaseStorageService.updateFile(
        path: avatarStoragePath(userId),
        file: avatarFile,
      );
    }

    final updates = <String, dynamic>{
      'full_name': ?fullName,
      'phone_number': ?phoneNumber,
      'photo_url': ?photoUrl,
    };

    if (updates.isEmpty) {
      throw ArgumentError('No editable fields provided to update.');
    }

    final row = await _client
        .from(_table)
        .update(updates)
        .eq('id', userId)
        .select()
        .single();

    return AppUserModel.fromJson(row);
  }
}
