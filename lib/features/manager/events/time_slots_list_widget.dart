import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/features/manager/events/event_notifier_provider.dart';
import 'package:qabso_mobile/features/manager/events/models/booking_context_model.dart';
import 'package:qabso_mobile/features/manager/events/time_slot_card_widget.dart';
import 'package:qabso_mobile/utill/app_utility_service.dart';
import 'package:qabso_mobile/utill/error_widget.dart';
import 'package:qabso_mobile/utill/loading_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../utill/app_date_util.dart';

final selectedDateProvider = StateProvider.autoDispose<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

class TimeSlotsListWidget extends ConsumerStatefulWidget {
  final BookingContextModel booking;
  final bool showDatePicker;

  const TimeSlotsListWidget({
    super.key,
    required this.booking,
    this.showDatePicker = true,
  });

  @override
  ConsumerState<TimeSlotsListWidget> createState() =>
      _TimeSlotsListWidgetState();
}

class _TimeSlotsListWidgetState extends ConsumerState<TimeSlotsListWidget> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedDate = ref.watch(selectedDateProvider);
    final slotsAsync = ref.watch(
      eventTimeSlotsProvider(widget.booking.fieldId),
    );

    return Column(
      children: [
        if (widget.showDatePicker) _buildDateOfTheWeek(selectedDate),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildIndicator(
              title: "Available",
              color: theme.colorScheme.surfaceContainerHighest,
            ),
            _buildIndicator(
              title: "Half Booked",
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.5),
                  theme.colorScheme.primary.withValues(alpha: 0.5),
                  theme.colorScheme.surfaceContainerHighest,
                  theme.colorScheme.surfaceContainerHighest,
                ],
                stops: const [0, 0.54, 0.54, 1],
              ),
            ),
            _buildIndicator(
              title: "Booked",
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
          ],
        ),
        const SizedBox(height: 12),
        slotsAsync.when(
          skipLoadingOnRefresh: false,
          data: (slots) {
            if (slots.isEmpty) {
              return const Text("Field-kan booking-ku waka xidhan yahay");
            }
            return Wrap(
              spacing: 2,
              runSpacing: 4,
              children: slots
                  .map(
                    (slot) => TimeSlotCardWidget(
                      booking: widget.booking,
                      slotModel: slot,
                    ),
                  )
                  .toList(),
            );
          },
          error: (error, stackTrace) {
            if (error is PostgrestException) {
              return Text(error.message, textAlign: TextAlign.center);
            }
            return ErrorRetryWidget(
              errorMessage: error.toString(),
              onRetry: () => ref.invalidate(
                eventTimeSlotsProvider(widget.booking.fieldId),
              ),
            );
          },
          loading: () => LoadingWidget(),
        ),
      ],
    );
  }

  Widget _buildDateOfTheWeek(DateTime date) {
    final today = DateUtils.dateOnly(DateTime.now());
    final maxDate = today.add(const Duration(days: 7));

    final selected = DateUtils.dateOnly(date);

    final canGoBack = selected.isAfter(today);
    final canGoForward = selected.isBefore(maxDate);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: canGoBack
              ? () {
                  final newDate = date.subtract(const Duration(days: 1));
                  ref.read(selectedDateProvider.notifier).state = newDate;
                }
              : null,
          icon: Icon(Symbols.chevron_left),
        ),
        InkWell(
          onTap: () async {
            final pickedDate = await AppUtilityService.pickDate(
              context: context,
              initialDate: date,
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(Duration(days: 7)),
            );
            if (pickedDate != null) {
              ref.read(selectedDateProvider.notifier).state = pickedDate;
            }
          },
          child: Text(
            AppDateUtil.formatReadableDate(date),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          onPressed: canGoForward
              ? () {
                  final newDate = date.add(const Duration(days: 1));
                  ref.read(selectedDateProvider.notifier).state = newDate;
                }
              : null,
          icon: Icon(Symbols.chevron_right),
        ),
      ],
    );
  }

  Widget _buildIndicator({
    Color? color,
    Gradient? gradient,
    required String title,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color,
              gradient: gradient,
              shape: BoxShape.rectangle,
              border: Border.all(
                width: 1,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: 8),
          Text(title),
        ],
      ),
    );
  }
}
