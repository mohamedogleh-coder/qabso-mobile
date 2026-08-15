import 'package:supabase_flutter/supabase_flutter.dart';

import '../../manager/stadium/stadium_model.dart';

class FavouriteRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static const _favouritesTable = 'favourite_stadiums';
  static const _favouritesView = 'favourite_stadiums_view';

  /// Reads the signed-in user's saved stadiums, newest saved first.
  ///
  /// Read from [_favouritesView] rather than the table, because the stadium's
  /// location is a PostGIS point and the view is what turns it into the
  /// latitude and longitude [StadiumModel] expects.
  ///
  /// Nothing here filters by user. The view carries the table's row level
  /// security, so it already answers with this user's rows alone.
  static Future<List<StadiumModel>> getFavouriteStadiums() async {
    final rows = await _client
        .from(_favouritesView)
        .select()
        .order('favourited_at', ascending: false);

    return rows.map(StadiumModel.fromJson).toList();
  }

  /// Saves [stadiumId] for the signed-in user.
  ///
  /// The user is left out of the row on purpose: the column defaults to
  /// whoever is signed in, and the insert policy accepts no one else.
  static Future<void> addFavourite({required String stadiumId}) async {
    if (_client.auth.currentUser == null) {
      throw StateError('Cannot save a favourite: no authenticated user.');
    }

    await _client.from(_favouritesTable).insert({'stadium_id': stadiumId});
  }

  /// Removes [stadiumId] from the signed-in user's saved stadiums.
  ///
  /// Only the stadium is matched. The row is the caller's own already —
  /// row level security sees to that — so filtering by the user as well would
  /// only repeat what the database enforces.
  static Future<void> removeFavourite({required String stadiumId}) async {
    if (_client.auth.currentUser == null) {
      throw StateError('Cannot remove a favourite: no authenticated user.');
    }

    await _client.from(_favouritesTable).delete().eq('stadium_id', stadiumId);
  }
}
