import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../working_days/working_days.dart';
import 'stadium_repository.dart';

/// One stadium's working days, held per stadium id.
///
/// Kept the same way stadiumProfileProvider is: autoDispose, with
/// StadiumInformationScreen holding a listener while it is open, so the days
/// are read once a visit and survive moving between the tabs.
final stadiumWorkingDaysProvider = FutureProvider.autoDispose
    .family<List<WorkingDayModel>, String>(
      (ref, stadiumId) =>
          StadiumRepository.getStadiumWorkingDays(stadiumId: stadiumId),
      retry: (retryCount, error) {
        if (error is PostgrestException) return null;
        if (retryCount >= 2) return null;
        return Duration(milliseconds: 300 * (retryCount + 1));
      },
    );
