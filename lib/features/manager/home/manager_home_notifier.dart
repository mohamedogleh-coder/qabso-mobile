import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../utill/app_constants.dart';
import '../stadium/stadium_notifier_provider.dart';
import 'home_repository.dart';
import 'manager_home_model.dart';

/// Today at the manager's stadium, read again on its own every few minutes.
///
/// autoDispose on purpose: the timer below lives as long as this provider
/// does, so a provider that is kept alive would go on asking the database all
/// day even after the manager has left the screen.
final managerHomeNotifierProvider =
    AsyncNotifierProvider.autoDispose<ManagerHomeNotifier, ManagerHomeModel?>(
      ManagerHomeNotifier.new,
    );

class ManagerHomeNotifier extends AsyncNotifier<ManagerHomeModel?> {
  @override
  FutureOr<ManagerHomeModel?> build() async {
    // The wait is kept in AppConstants because the countdown on screen has to
    // agree with it. Two copies would drift the moment one was changed.
    final timer = Timer.periodic(
      AppConstants.dashboardRefreshInterval,
      (_) => _readQuietly(),
    );

    // Runs when the provider is thrown away, and again before every rebuild,
    // so there is only ever one timer running.
    ref.onDispose(timer.cancel);

    final stadium = await ref.watch(stadiumNotifierProvider.future);

    if (stadium?.stadiumId == null) return null;

    return HomeRepository.getManagerHome(stadiumId: stadium!.stadiumId!);
  }

  /// The manager asked for this, so the screen is allowed to show it working.
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_read);
  }

  /// The timer asked for this, and the manager did not. The answer replaces
  /// what is on screen without passing through loading, so the numbers change
  /// under their eyes rather than the screen blanking every five minutes.
  ///
  /// A read that fails is kept quiet too: the screen goes on showing the last
  /// good answer instead of turning into an error nobody asked for.
  Future<void> _readQuietly() async {
    final read = await AsyncValue.guard(_read);

    if (read.hasError) return;

    state = read;
  }

  Future<ManagerHomeModel?> _read() async {
    final stadiumId = ref.read(stadiumNotifierProvider).value?.stadiumId;

    if (stadiumId == null) return null;

    return HomeRepository.getManagerHome(stadiumId: stadiumId);
  }

  //--------------------------------------------------------------------------
  // What the manager just did
  //
  // The database has already accepted the change by the time these are
  // called. They move the numbers on screen straight away so the manager sees
  // their own work, rather than waiting up to five minutes for the timer.
  //
  // Nothing here is the truth. The next read replaces the whole model, so any
  // difference between what was worked out here and what the database holds is
  // corrected on its own.
  //--------------------------------------------------------------------------

  /// A booking was taken on today's grid.
  ///
  /// One game more, one slot fewer, and [owed] added to what is outstanding
  /// when the slot was taken as a half. A whole booking owes nothing and
  /// leaves that figure alone.
  ///
  /// The next game is read again: a booking made for earlier than everything
  /// else becomes the next one, and only the database knows that.
  void bookingTaken({double owed = 0}) {
    _change(
      (home) => home.copyWith(
        gamesToday: home.gamesToday + 1,
        freeSlotsToday: _atLeastZero(home.freeSlotsToday - 1),
        remainingAmount: () => _addOwed(home, owed),
      ),
    );

    _readQuietly();
  }

  /// A booking was cancelled. The slot goes back on sale, the game is no
  /// longer on, and whatever it was still owed is no longer owed.
  ///
  /// The next game is read again rather than guessed. Cancelling the next
  /// game does not mean the day is over — there may be a later one, and this
  /// model cannot see it.
  void bookingCancelled({double owed = 0}) {
    _change(
      (home) => home.copyWith(
        gamesToday: _atLeastZero(home.gamesToday - 1),
        freeSlotsToday: home.freeSlotsToday + 1,
        remainingAmount: () => _addOwed(home, -owed),
      ),
    );

    _readQuietly();
  }

  /// The second half of a booking was paid, so it owes nothing more.
  ///
  /// The game itself has not moved — it was always on the grid — so only the
  /// outstanding figure changes. The next game is read again because its
  /// status has gone from half paid to booked.
  void halfSettled({required double amount}) {
    _change(
      (home) => home.copyWith(remainingAmount: () => _addOwed(home, -amount)),
    );

    _readQuietly();
  }

  /// A game that was on has finished. Nothing is read again: the day's games
  /// have not changed, only how many of them are behind us.
  void gamePlayed() {
    _change(
      (home) => home.copyWith(
        // Never more played than were ever on. A day whose games are all
        // behind it stays where it is.
        playedToday: home.playedToday < home.gamesToday
            ? home.playedToday + 1
            : home.gamesToday,
      ),
    );
  }

  /// Changes what is on screen now.
  ///
  /// Does nothing until the first read has landed — there is nothing to change
  /// before that, and the read itself brings the true numbers.
  void _change(ManagerHomeModel Function(ManagerHomeModel home) change) {
    final home = state.value;

    if (home == null) return;

    state = AsyncData(change(home));
  }

  /// Moves what is owed, and leaves it alone on a stadium that sells whole
  /// slots only. Null there means the screen shows no owed part at all, and
  /// putting a number in would make one appear that does not belong.
  static double? _addOwed(ManagerHomeModel home, double amount) {
    final owed = home.remainingAmount;

    if (owed == null) return null;

    final moved = owed + amount;

    return moved < 0 ? 0 : moved;
  }

  /// A counter can never go below nothing, whatever the caller thinks
  /// happened.
  static int _atLeastZero(int value) => value < 0 ? 0 : value;
}
