import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Updates editable profile fields for the current authenticated user.
  ///
  /// Only `full_name` and `phone_number` can be changed here — `id`, `role`,
  /// `created_at`, and `updated_at` are intentionally not exposed.
  Future<AppUserModel> updateUserInfo({
    String? fullName,
    String? phoneNumber,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Cannot update profile: no authenticated user.');
    }

    final updates = <String, dynamic>{
      'full_name': ?fullName,
      'phone_number': ?phoneNumber,
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
