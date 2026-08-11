import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qabso_mobile/features/manager/events/event_repository.dart';
import 'package:qabso_mobile/features/manager/events/time_slots_list_widget.dart';
import 'package:qabso_mobile/features/manager/events/time_slots_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final eventTimeSlotsProvider = FutureProvider.autoDispose
    .family<List<TimeSlotModel>, int>(
      (ref, fieldId) {
        final date = ref.watch(selectedDateProvider);
        return EventRepository.getTimeSlots(fieldId: fieldId, date: date);
      },
      retry: (retryCount, error) {
        if (error is PostgrestException) return null;
        if (retryCount >= 2) return null;
        return Duration(milliseconds: 300 * (retryCount + 1));
      },
    );
