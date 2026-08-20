import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/features/manager/events/models/booking_context_model.dart';
import 'package:qabso_mobile/features/manager/events/time_slots_list_widget.dart';
import 'package:qabso_mobile/features/manager/fields/field_model.dart';
import 'package:qabso_mobile/features/manager/stadium/stadium_notifier_provider.dart';

import '../../../utill/app_constants.dart';
import '../../../utill/error_widget.dart';
import '../../../utill/loading_widget.dart';
import 'add_new_field_screen.dart';

class FieldCardWidget extends ConsumerStatefulWidget {
  final FieldModel model;

  const FieldCardWidget({super.key, required this.model});

  @override
  ConsumerState<FieldCardWidget> createState() => _FieldCardWidgetState();
}

class _FieldCardWidgetState extends ConsumerState<FieldCardWidget> {
  bool expanded = false;

  Widget _buildTimeSlots() {
    final stadiumAsync = ref.watch(stadiumNotifierProvider);

    return stadiumAsync.when(
      data: (stadium) {
        final stadiumId = stadium?.stadiumId;
        final fieldId = widget.model.id;

        if (stadiumId == null || fieldId == null) {
          return Text(
            "Garoonka lama helin.",
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          );
        }

        return TimeSlotsListWidget(
          booking: BookingContextModel(
            stadiumId: stadiumId,
            stadiumName: stadium!.stadiumName,
            fieldId: fieldId,
            capacity: widget.model.capacity,
            cost: widget.model.cost,
            allowHalfBooking: stadium!.allowHalfBooking,
          ),
        );
      },
      error: (error, stackTrace) => ErrorRetryWidget(
        errorMessage: error.toString(),
        onRetry: () => ref.read(stadiumNotifierProvider.notifier).refresh(),
      ),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: LoadingWidget(),
      ),
    );
  }

  Widget _buildClosedChip() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Symbols.block, size: 14, color: colorScheme.error),
          const SizedBox(width: 4),
          Text(
            "Closed",
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.error,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: expanded ? 1 : 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AddNewFieldScreen(fieldModel: widget.model),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: widget.model.allowBooking
                            ? colorScheme.primary
                            : colorScheme.outline,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Symbols.grass,
                        size: 24,
                        color: colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: .spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    "Field #${widget.model.id}",
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  if (!widget.model.allowBooking) ...[
                                    const SizedBox(width: 8),
                                    _buildClosedChip(),
                                  ],
                                ],
                              ),
                              Text(
                                '\$${widget.model.cost}',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: AppConstants.success,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: .spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Symbols.people, size: 16),
                                  Text(
                                    " ${widget.model.capacity} players",
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(Symbols.wallpaper, size: 16),
                                  Text(
                                    widget.model.fieldImages.isEmpty
                                        ? " No Photos"
                                        : " ${widget.model.fieldImages.length} Photos",
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if(widget.model.allowBooking)
            Divider(height: 24),
            AnimatedSize(
              duration: AppConstants.animationDuration,
              child: !expanded
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _buildTimeSlots(),
                    ),
            ),
            if(widget.model.allowBooking)...[
              if (expanded) Divider(height: 24),
              InkWell(
                onTap: () {
                  setState(() {
                    expanded = !expanded;
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: .center,
                    children: [
                      Icon(
                        expanded
                            ? Symbols.arrow_drop_up
                            : Symbols.arrow_drop_down,
                      ),
                      Text(expanded ? "Hide events" : "Show events"),
                    ],
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }
}
