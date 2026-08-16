import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/app_user_notifer.dart';
import '../../manager/stadium/stadium_model.dart';
import 'favourite_repository.dart';

final favouriteNotifierProvider =
    AsyncNotifierProvider<FavouriteNotifierProvider, List<StadiumModel>>(
      FavouriteNotifierProvider.new,
    );

/// The stadiums the signed-in user has saved, newest saved first.
class FavouriteNotifierProvider extends AsyncNotifier<List<StadiumModel>> {
  bool _isSaving = false;

  bool get isSaving => _isSaving;

  /// Follows the signed-in user, so the list loads itself on sign-in and
  /// empties on sign-out. Nobody signed in means nothing saved.
  @override
  FutureOr<List<StadiumModel>> build() async {
    final user = await ref.watch(appUserNotifierProvider.future);

    if (user == null) return const [];

    return FavouriteRepository.getFavouriteStadiums();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    if (ref.read(appUserNotifierProvider).value == null) {
      state = const AsyncData([]);
      return;
    }

    state = await AsyncValue.guard(FavouriteRepository.getFavouriteStadiums);
  }

  /// Whether [stadiumId] is already saved. This is what a stadium card asks
  /// to decide which way round to draw its heart.
  bool isFavourite(String stadiumId) {
    final favourites = state.value ?? const <StadiumModel>[];

    return favourites.any((stadium) => stadium.stadiumId == stadiumId);
  }

  /// Saves [stadium] and puts it at the top of the list, which is where a
  /// re-read would put it too since the list is newest first. The stadium the
  /// caller is already holding goes into state, so there is no second read.
  ///
  /// A stadium that is saved already is left alone. The database would refuse
  /// the second row on the primary key, and this is what keeps that from ever
  /// reaching the user as an error.
  ///
  /// State is not moved to loading, and a failure is thrown back to the
  /// caller instead of being written to state: the screen doing the saving
  /// shows its own progress, and one save that did not go through must not
  /// blank a list that is displaying fine.
  Future<void> addFavourite(StadiumModel stadium) async {
    final stadiumId = stadium.stadiumId;
    if (stadiumId == null) {
      throw ArgumentError.value(
        stadium,
        'stadium',
        'An unsaved stadium cannot be added to favourites.',
      );
    }

    if (isFavourite(stadiumId)) return;

    if (_isSaving) {
      throw StateError('A favourite is already being saved.');
    }

    _isSaving = true;
    try {
      await FavouriteRepository.addFavourite(stadiumId: stadiumId);
      state = AsyncData([stadium, ...?state.value]);
    } finally {
      _isSaving = false;
    }
  }

  /// Removes every saved stadium and empties the list on success. Failures
  /// are thrown to the caller, the same way [addFavourite] does, so a clear
  /// that did not go through leaves the list on screen.
  Future<void> clearFavourites() async {
    if (_isSaving) {
      throw StateError('A favourite is already being saved.');
    }

    _isSaving = true;
    try {
      await FavouriteRepository.clearFavourites();
      state = const AsyncData([]);
    } finally {
      _isSaving = false;
    }
  }

  /// Removes [stadiumId] and drops it from the list on success. Failures are
  /// thrown to the caller for the same reason as [addFavourite].
  Future<void> removeFavourite(String stadiumId) async {
    if (_isSaving) {
      throw StateError('A favourite is already being saved.');
    }

    _isSaving = true;
    try {
      await FavouriteRepository.removeFavourite(stadiumId: stadiumId);
      state = AsyncData([
        for (final stadium in state.value ?? const <StadiumModel>[])
          if (stadium.stadiumId != stadiumId) stadium,
      ]);
    } finally {
      _isSaving = false;
    }
  }
}
