import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_user_model.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Holds the current [AppUserModel] profile for the signed-in user.
///
/// State is `null` when there is no authenticated user, or when the
/// authenticated user has no `app_users` profile yet.
final appUserNotifierProvider =
    AsyncNotifierProvider<AppUserNotifier, AppUserModel?>(AppUserNotifier.new);

class AppUserNotifier extends AsyncNotifier<AppUserModel?> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  Future<AppUserModel?> build() async {
    // Re-evaluate the profile whenever Supabase Auth state actually changes
    // (sign-in, sign-out, token refresh, etc), skipping the replayed initial
    // event since we already fetch below.
    final subscription = _repository.onAuthStateChange.listen((authState) {
      if (authState.event == AuthChangeEvent.initialSession) return;
      fetchUser();
    });
    ref.onDispose(subscription.cancel);

    return _repository.getCurrentAppUser();
  }

  /// Fetches the current app user through [AuthRepository] and updates state.
  Future<void> fetchUser() async {
    state = const AsyncLoading();
    try {
      final user = await _repository.getCurrentAppUser();
      state = AsyncData(user);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Updates editable profile fields through [AuthRepository] and syncs state.
  Future<void> updateUserInfo({
    String? fullName,
    String? phoneNumber,
    File? avatarFile,
  }) async {
    state = const AsyncLoading();
    try {
      final user = await _repository.updateUserInfo(
        fullName: fullName,
        phoneNumber: phoneNumber,
        avatarFile: avatarFile,
      );
      state = AsyncData(user);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  /// Re-fetches the user and updates state.
  Future<void> refresh() => fetchUser();
}
