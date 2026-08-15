import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utill/supabase_storage_service.dart';
import 'app_user_model.dart';

class AuthRepository {
  AuthRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _table = 'app_users';

  String avatarStoragePath(String userId) => 'user_profiles/$userId.jpg';

  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<void> signInWithPassword({
    required String email,
    required String password,
  }) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signInWithGoogle() async {
    await _client.auth.signInWithOAuth(OAuthProvider.google);
  }

  Future<void> signInWithFacebook() async {
    await _client.auth.signInWithOAuth(OAuthProvider.facebook);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

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

  Future<AppUserModel> updateUserInfo({
    String? fullName,
    String? phoneNumber,
    File? avatarFile,
    bool removeAvatar = false,
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
      if (removeAvatar && avatarFile == null) 'photo_url': null,
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
