import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/features/manager/events/models/booking_context_model.dart';
import 'package:qabso_mobile/features/manager/events/time_slots_list_widget.dart';
import 'package:qabso_mobile/features/user/explore/models/explored_stadium_model.dart';
import 'package:qabso_mobile/utill/app_dailogs.dart';

import '../../../../utill/app_constants.dart';
import 'explore_single_stadium_info_widget.dart';

class ExploredStadiumCardWidget extends StatefulWidget {
  final ExploredStadiumModel stadiumModel;

  const ExploredStadiumCardWidget({super.key, required this.stadiumModel});

  @override
  State<ExploredStadiumCardWidget> createState() =>
      _ExploredStadiumCardWidgetState();
}

class _ExploredStadiumCardWidgetState extends State<ExploredStadiumCardWidget> {
  bool expanded = false;
  bool fav = false;
  late BookingContextModel contextModel;

  @override
  void initState() {
    super.initState();
    contextModel = BookingContextModel(
      fieldId: widget.stadiumModel.fieldId,
      stadiumId: widget.stadiumModel.stadiumId!,
      capacity: widget.stadiumModel.capacity,
      cost: widget.stadiumModel.cost,
      allowHalfBooking: widget.stadiumModel.allowHalfBooking,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: expanded ? 1 : 0,
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
                              Row(
                                children: [
                                  Icon(
                                    Symbols.sports,
                                    size: 18,
                                    color: Theme.of(context).hintColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.stadiumModel.extraTime == 0
                                        ? "No extra time"
                                        : '${widget.stadiumModel.extraTime} minutes',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(
                                    Symbols.group,
                                    size: 18,
                                    color: Theme.of(context).hintColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.stadiumModel.capacity.toString(),
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
                    const SizedBox(width: 8),
                    Icon(
                      Symbols.chevron_right,
                      color: Theme.of(context).highlightColor,
                    ),
                    // IconButton(
                    //   onPressed: () {},
                    //   icon: Icon(Symbols.favorite, fill: fav ? 1 : 0),
                    // ),
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
                      child: TimeSlotsListWidget(booking: contextModel),
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
