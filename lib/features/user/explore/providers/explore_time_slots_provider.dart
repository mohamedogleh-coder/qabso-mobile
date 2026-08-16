import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../manager/events/event_repository.dart';
import '../../../manager/events/time_slots_model.dart';
import 'explore_stadiums_filter_notifier.dart';

/// One field's slots on the day the customer searched for.
///
/// It reads the same EventRepository.getTimeSlots the manager's screens use.
/// The only difference is the day: it comes from the explore filter, so
/// changing the searched date reloads the slots with it.
final exploreTimeSlotsProvider = FutureProvider.autoDispose
    .family<List<TimeSlotModel>, int>(
      (ref, fieldId) {
        final date = ref.watch(exploredStadiumFilterNotifierProvider).eventDate;

        return EventRepository.getTimeSlots(fieldId: fieldId, date: date);
      },
      retry: (retryCount, error) {
        if (error is PostgrestException) return null;
        if (retryCount >= 2) return null;
        return Duration(milliseconds: 300 * (retryCount + 1));
      },
    );
