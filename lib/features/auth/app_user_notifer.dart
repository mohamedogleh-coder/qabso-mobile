import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_user_model.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Auth events that can actually change which profile should be loaded.
/// Excludes things like token refreshes, which don't change who's signed in
/// — refetching the profile for those would be a wasted request.
const _profileRelevantEvents = {
  AuthChangeEvent.signedIn,
  AuthChangeEvent.signedOut,
  AuthChangeEvent.userUpdated,
};

/// Holds the current [AppUserModel] profile for the signed-in user.
///
/// State is `null` when there is no authenticated user, or when the
/// authenticated user has no `app_users` profile yet.
final appUserNotifierProvider =
    AsyncNotifierProvider<AppUserNotifier, AppUserModel?>(AppUserNotifier.new);

class AppUserNotifier extends AsyncNotifier<AppUserModel?> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  // Guards against out-of-order results when requests overlap (e.g. a rapid
  // sign-out immediately followed by a sign-in, or an auth event landing
  // mid-refresh): only the response to the most recently issued request is
  // allowed to update state.
  int _requestId = 0;

  @override
  Future<AppUserModel?> build() async {
    // Re-evaluate the profile when Supabase Auth state actually changes who
    // is signed in. Skips the replayed initial event (already covered by the
    // fetch below) and events that don't affect identity, like token
    // refreshes.
    //
    // An onError handler is required here: per Supabase's docs, network
    // errors on this stream (e.g. a failed token refresh while offline) are
    // rethrown as unhandled zone exceptions — and crash the app — if no
    // handler is supplied.
    final subscription = _repository.onAuthStateChange.listen(
      (authState) {
        if (!_profileRelevantEvents.contains(authState.event)) return;
        fetchUser();
      },
      onError: (Object error, StackTrace stackTrace) {
        state = AsyncError(error, stackTrace);
      },
    );
    ref.onDispose(subscription.cancel);

    return _repository.getCurrentAppUser();
  }

  /// Fetches the current app user through [AuthRepository] and updates state.
  Future<void> fetchUser() async {
    final requestId = ++_requestId;
    state = const AsyncLoading();
    try {
      final user = await _repository.getCurrentAppUser();
      if (requestId != _requestId) return;
      state = AsyncData(user);
    } catch (e, st) {
      if (requestId != _requestId) return;
      state = AsyncError(e, st);
    }
  }

  /// Updates editable profile fields through [AuthRepository] and syncs state.
  Future<void> updateUserInfo({
    String? fullName,
    String? phoneNumber,
    File? avatarFile,
  }) async {
    final requestId = ++_requestId;
    state = const AsyncLoading();
    try {
      final user = await _repository.updateUserInfo(
        fullName: fullName,
        phoneNumber: phoneNumber,
        avatarFile: avatarFile,
      );
      if (requestId != _requestId) return;
      state = AsyncData(user);
    } catch (e, st) {
      if (requestId != _requestId) return;
      state = AsyncError(e, st);
    }
  }

  /// Re-fetches the user and updates state.
  Future<void> refresh() => fetchUser();
}
