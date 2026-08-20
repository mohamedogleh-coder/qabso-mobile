import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/features/manager/events/models/booking_context_model.dart';
import 'package:qabso_mobile/features/manager/events/time_slots_list_widget.dart';
import 'package:qabso_mobile/features/user/explore/models/explored_stadium_model.dart';
import 'package:qabso_mobile/utill/app_dailogs.dart';

import '../../../../utill/app_constants.dart';
import '../../../../utill/current_position_provider.dart';
import 'explore_single_stadium_info_widget.dart';

class ExploredStadiumCardWidget extends ConsumerStatefulWidget {
  final ExploredStadiumModel stadiumModel;

  const ExploredStadiumCardWidget({super.key, required this.stadiumModel});

  @override
  ConsumerState<ExploredStadiumCardWidget> createState() =>
      _ExploredStadiumCardWidgetState();
}

class _ExploredStadiumCardWidgetState
    extends ConsumerState<ExploredStadiumCardWidget> {
  bool expanded = false;
  bool fav = false;
  late BookingContextModel contextModel;

  @override
  void initState() {
    super.initState();
    contextModel = BookingContextModel(
      fieldId: widget.stadiumModel.fieldId,
      stadiumId: widget.stadiumModel.stadiumId!,
      stadiumName: widget.stadiumModel.stadiumName,
      capacity: widget.stadiumModel.capacity,
      cost: widget.stadiumModel.cost,
      allowHalfBooking: widget.stadiumModel.allowHalfBooking,
    );
  }

  String get _distance {
    final searched = widget.stadiumModel.distance;
    if (searched != null) return "$searched km";

    final position = ref.watch(currentPositionProvider).value;
    final latitude = widget.stadiumModel.latitude;
    final longitude = widget.stadiumModel.longitude;

    if (position == null || latitude == null || longitude == null) {
      return "--/--";
    }

    final metres = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      latitude,
      longitude,
    );

    return "${(metres / 1000).toStringAsFixed(1)} km";
  }

   Widget _buildFact({required IconData icon, required String text}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).hintColor),
        const SizedBox(width: 8),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: expanded ? 3 : 0,
      shadowColor: Theme.of(context).shadowColor.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                showAppBottomSheet(
                  context: context,
                  builder: (context) => ExploreSingleStadiumInfoWidget(
                    exploredStadiumModel: widget.stadiumModel,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(4.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      child: Icon(
                        Symbols.stadium,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: .start,
                        children: [
                          Row(
                            mainAxisAlignment: .spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.stadiumModel.stadiumName,
                                  style: Theme.of(context).textTheme.bodyMedium!
                                      .copyWith(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 2,
                                ),
                              ),
                              SizedBox(width: 8),
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '\$${widget.stadiumModel.cost}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge!
                                          .copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                          ),
                                    ),
                                    TextSpan(
                                      text: ' /player',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisAlignment: .spaceBetween,
                             children: [
                              _buildFact(
                                icon: Symbols.sports,
                                text: widget.stadiumModel.extraTime == 0
                                    ? "No extra time"
                                    : '${widget.stadiumModel.extraTime} minutes',
                              ),
                              Row(
                                children: [
                                  _buildFact(
                                    icon: Symbols.group,
                                    text: widget.stadiumModel.capacity.toString(),
                                  ),
                                  const SizedBox(width: 12,),
                                  _buildFact(
                                    icon: Symbols.map,
                                    text: _distance,
                                  ),
                                ],
                              ),

                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  
                  ],
                ),
              ),
            ),
            const Divider(height: 24),
            AnimatedSize(
              duration: AppConstants.animationDuration,
              child: expanded
                  ? Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: TimeSlotsListWidget(
                        booking: contextModel,
                        showDatePicker: false,
                      ),
                    )
                  : SizedBox.shrink(),
            ),
            if (expanded) ...[const Divider(height: 24)],
            InkWell(
              onTap: () {
                setState(() {
                  expanded = !expanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 8.0,
                ),
                child: Row(
                  mainAxisAlignment: .center,
                  children: [
                    Icon(
                      expanded
                          ? Symbols.arrow_drop_up
                          : Symbols.arrow_drop_down,
                    ),
                    const SizedBox(width: 12),
                    Text(expanded ? "Hide events" : "Show events"),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
