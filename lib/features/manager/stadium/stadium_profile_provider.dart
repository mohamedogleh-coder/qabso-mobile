import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'models/stadium_profile_model.dart';
import 'stadium_repository.dart';

/// One stadium's profile, held per stadium id.
///
/// A different stadium id is a different entry, so opening another stadium
/// never shows the last one's data.
///
/// It is autoDispose like the other providers here, which means it lives only
/// while something is listening. StadiumInformationScreen holds a listener for
/// as long as it is open, so the profile is read once and survives moving
/// between the tabs, and is let go when the screen closes.
final stadiumProfileProvider = FutureProvider.autoDispose
    .family<StadiumProfileModel, String>(
      (ref, stadiumId) =>
          StadiumRepository.getStadiumProfile(stadiumId: stadiumId),
      retry: (retryCount, error) {
        if (error is PostgrestException) return null;
        if (retryCount >= 2) return null;
        return Duration(milliseconds: 300 * (retryCount + 1));
      },
    );
