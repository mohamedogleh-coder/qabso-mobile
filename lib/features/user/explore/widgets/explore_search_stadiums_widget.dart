import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/utill/app_utility_service.dart';

import '../../../../utill/app_date_util.dart';
import '../explored_stadiums_screen.dart';
import '../providers/explore_stadiums_filter_notifier.dart';

class ExploreSearchStadiumsWidget extends ConsumerStatefulWidget {
  const ExploreSearchStadiumsWidget({super.key});

  @override
  ConsumerState<ExploreSearchStadiumsWidget> createState() =>
      _ExploreSearchStadiumsWidgetState();
}

class _ExploreSearchStadiumsWidgetState
    extends ConsumerState<ExploreSearchStadiumsWidget> {
  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(exploredStadiumFilterNotifierProvider);

    final filterNotifier = ref.read(
      exploredStadiumFilterNotifierProvider.notifier,
    );
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCard(
            context: context,
            title: "Cadadka",
            icon: Symbols.group,
            child: Row(
              children: [
                IconButton(
                  style: IconButton.styleFrom(
                    disabledForegroundColor: Theme.of(context).dividerColor,
                    backgroundColor: Theme.of(context).colorScheme.tertiary,
                  ),
                  onPressed: filter.capacity <= 6
                      ? null
                      : () {
                          filterNotifier.updateCapacity(filter.capacity - 1);
                        },
                  icon: const Icon(Symbols.remove),
                ),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${filter.capacity}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextSpan(
                        text: " Players",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  style: IconButton.styleFrom(
                    disabledForegroundColor: Theme.of(context).dividerColor,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: filter.capacity >= 14
                      ? null
                      : () {
                          filterNotifier.updateCapacity(filter.capacity + 1);
                        },
                  icon: const Icon(Symbols.add),
                ),
              ],
            ),
          ),
          _buildCard(
            context: context,
            title: "Tariikhda",
            icon: Symbols.calendar_month,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: InkWell(
                onTap: () async {
                  final eventDate = await AppUtilityService.pickDate(
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(Duration(days: 7)),
                    initialDate: filter.eventDate,
                    context: context,
                  );
                  filterNotifier.updateDate(eventDate!);
                },
                child: Text(
                  AppDateUtil.formatReadableDate(filter.eventDate),
                  style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
              ),
            ),
          ),
          _buildCard(
            context: context,
            title: "Wakhtiga",
            icon: Symbols.access_alarm,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12.0),
              child: Row(
                children: [
                  InkWell(
                    onTap: () async {
                      final eventTime = await AppUtilityService.pickTime(
                        minTime: TimeOfDay.now(),
                        context: context,
                      );
                      filterNotifier.updateTime(eventTime);
                    },
                    child: Text(
                      filter.eventTime != null
                          ? AppDateUtil.formatTimeOfTheDayTime(
                              filter.eventTime!,
                            )
                          : "All the time",
                      style: Theme.of(context).textTheme.headlineMedium!
                          .copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                    ),
                  ),
                  if (filter.eventTime != null) ...[
                    const SizedBox(width: 24),
                    IconButton(
                      onPressed: () {
                        filterNotifier.updateTime(null);
                      },
                      icon: const Icon(Symbols.close),
                      padding: EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 1),
          FilledButton.icon(
            style: ElevatedButton.styleFrom(
              elevation: 0,
              minimumSize: const Size(double.infinity, 45),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(0),
              ),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExploredStadiumsScreen(),
                ),
              );
            },
            label: Text("Raadi"),
            icon: Icon(Symbols.search),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      margin: EdgeInsets.symmetric(vertical: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(title),
              ],
            ),
            child,
          ],
        ),
      ),
    );
  }
}
