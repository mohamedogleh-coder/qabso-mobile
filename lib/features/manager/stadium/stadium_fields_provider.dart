import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../fields/field_model.dart';
import 'stadium_repository.dart';

/// One stadium's fields, held per stadium id.
///
/// Kept the same way stadiumProfileProvider and stadiumWorkingDaysProvider
/// are: autoDispose, with the tab holding it alive while the stadium screen is
/// open, so the fields are read once a visit.
final stadiumFieldsProvider = FutureProvider.autoDispose
    .family<List<FieldModel>, String>(
      (ref, stadiumId) =>
          StadiumRepository.getStadiumFields(stadiumId: stadiumId),
      retry: (retryCount, error) {
        if (error is PostgrestException) return null;
        if (retryCount >= 2) return null;
        return Duration(milliseconds: 300 * (retryCount + 1));
      },
    );
