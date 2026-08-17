import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../utill/app_constants.dart';
import '../../../../utill/error_widget.dart';
import '../../../../utill/loading_widget.dart';
import '../../working_days/working_days.dart';
import '../stadium_working_days_provider.dart';

/// The Working days tab of the stadium screen: when the stadium opens, and
/// what it is doing today.
///
/// Only for looking at. Nothing here changes a day — the manager's own working
/// days screen is where they are edited.
class StadiumWorkingDaysWidget extends ConsumerStatefulWidget {
  final String stadiumId;

  const StadiumWorkingDaysWidget({super.key, required this.stadiumId});

  @override
  ConsumerState<StadiumWorkingDaysWidget> createState() =>
      _StadiumWorkingDaysWidgetState();
}

class _StadiumWorkingDaysWidgetState
    extends ConsumerState<StadiumWorkingDaysWidget>
    with AutomaticKeepAliveClientMixin {
  /// Stays alive while the stadium screen is open.
  ///
  /// TabBarView throws a tab away once the user swipes far enough from it, and
  /// building it again is what made this tab read the days a second time.
  /// Kept alive, the widget holds both its data and where the list was
  /// scrolled to.
  @override
  bool get wantKeepAlive => true;

  /// Reads the days again. The provider is what holds the answer, so the
  /// screen and this widget always see the same one.
  void _reload() =>
      ref.invalidate(stadiumWorkingDaysProvider(widget.stadiumId));

  /// Today as the database counts it. DateTime.weekday is 1..7 Monday-first,
  /// which is exactly what day_of_week holds, so neither side is converted.
  int get _today => DateTime.now().weekday;

  @override
  Widget build(BuildContext context) {
    // The keep-alive mixin asks for this before anything else is built.
    super.build(context);

    final daysAsync = ref.watch(stadiumWorkingDaysProvider(widget.stadiumId));

    return daysAsync.when(
      skipLoadingOnRefresh: false,
      data: _buildDays,
      error: (error, stackTrace) => ErrorRetryWidget(
        errorMessage: error is PostgrestException
            ? error.message
            : error.toString(),
        onRetry: _reload,
      ),
      loading: () => const LoadingWidget(),
    );
  }

  Widget _buildDays(List<WorkingDayModel> saved) {
    final week = _wholeWeek(saved);

    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        await ref.read(stadiumWorkingDaysProvider(widget.stadiumId).future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildToday(week),
            const SizedBox(height: 16),
            _buildCounts(week),
            const Divider(height: 32),
            _buildWeek(week),
          ],
        ),
      ),
    );
  }

  /// The seven days in week order.
  ///
  /// The stadium only saves the days it set up, so a day that is missing has
  /// never been written down. It is shown closed, which is what a day that was
  /// switched off looks like too — to somebody standing at the gate the two
  /// are the same thing.
  List<WorkingDayModel> _wholeWeek(List<WorkingDayModel> saved) {
    return [
      for (var day = 1; day <= 7; day++)
        saved.firstWhere(
          (candidate) => candidate.dayOfWeek == day,
          orElse: () => WorkingDayModel(
            dayOfWeek: day,
            openTime: '',
            closeTime: '',
            isOpen: false,
          ),
        ),
    ];
  }

  /// What the stadium is doing today, which is the one thing most people open
  /// this tab to find out.
  Widget _buildToday(List<WorkingDayModel> week) {
    final theme = Theme.of(context);
    final today = week[_today - 1];
    final color = today.isOpen
        ? theme.colorScheme.primary
        : theme.colorScheme.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Color.alphaBlend(
          color.withValues(alpha: 0.12),
          theme.colorScheme.surface,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              today.isOpen ? Symbols.event_available : Symbols.event_busy,
              color: theme.colorScheme.onPrimary,
              fill: 1,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today · ${today.dayName}",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _hours(today),
                  style: theme.textTheme.headlineLarge?.copyWith(color: color),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// How the week looks as a whole, before reading it day by day.
  Widget _buildCounts(List<WorkingDayModel> week) {
    final open = week.where((day) => day.isOpen).length;

    return _buildStatStrip([
      _buildStat(
        icon: Symbols.event_available,
        label: "Open days",
        value: "$open",
      ),
      _buildStat(
        icon: Symbols.event_busy,
        label: "Closed days",
        value: "${7 - open}",
        color: Theme.of(context).colorScheme.error,
      ),
      _buildStat(
        icon: Symbols.schedule,
        label: "Longest day",
        value: _longestDay(week),
        color: AppConstants.tertiary,
      ),
    ]);
  }

  /// The most hours the stadium plays on any one day, as whole hours. Nothing
  /// open at all leaves it as a dash.
  String _longestDay(List<WorkingDayModel> week) {
    var longest = 0;

    for (final day in week) {
      final minutes = _minutesOpen(day);
      if (minutes > longest) longest = minutes;
    }

    if (longest == 0) return "—";

    return "${(longest / 60).toStringAsFixed(longest % 60 == 0 ? 0 : 1)} hrs";
  }

  /// How long a day runs, in minutes. A closed day, or one whose hours were
  /// never written down, runs for nothing.
  int _minutesOpen(WorkingDayModel day) {
    if (!day.isOpen) return 0;

    final open = _minutesInto(day.openTime);
    final close = _minutesInto(day.closeTime);

    if (open == null || close == null) return 0;

    return close - open;
  }

  /// Reads `HH:mm` into minutes since midnight, or null when it is not a time.
  int? _minutesInto(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;

    return hour * 60 + minute;
  }

  /// Every day of the week, one under the other.
  Widget _buildWeek(List<WorkingDayModel> week) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(icon: Symbols.calendar_month, title: "This week"),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.highlightColor),
          ),
          child: Column(
            children: [
              for (var index = 0; index < week.length; index++) ...[
                if (index > 0) const Divider(height: 1),
                _buildDayRow(week[index]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDayRow(WorkingDayModel day) {
    final theme = Theme.of(context);
    final isToday = day.dayOfWeek == _today;
    final color = day.isOpen
        ? theme.colorScheme.primary
        : theme.colorScheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      color: !day.isOpen
          ? theme.colorScheme.error.withValues(alpha: 0.06)
          : isToday
          ? theme.colorScheme.primary.withValues(alpha: 0.06)
          : Colors.transparent,
      child: Row(
        children: [
          // Filled when the stadium plays that day, hollow when it does not,
          // so the week can be read down the left edge alone.
          Container(
            height: 10,
            width: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: day.isOpen ? color : Colors.transparent,
              border: Border.all(color: color, width: 1.5),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            day.dayName,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isToday ? FontWeight.bold : FontWeight.w500,
              color: day.isOpen ? null : theme.colorScheme.error,
            ),
          ),
          if (isToday) ...[const SizedBox(width: 8), _buildTodayChip(day)],
          const Spacer(),
          Text(
            _hours(day),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: day.isOpen
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  /// The chip takes the day's own colour, so "Today" on a closed day reads red
  /// along with the rest of the row.
  Widget _buildTodayChip(WorkingDayModel day) {
    final theme = Theme.of(context);
    final color = day.isOpen
        ? theme.colorScheme.primary
        : theme.colorScheme.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        "Today",
        style: theme.textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// The hours a day plays, or the word for not playing at all.
  String _hours(WorkingDayModel day) {
    if (!day.isOpen || day.openTime.isEmpty || day.closeTime.isEmpty) {
      return "Closed";
    }

    return "${day.openTime} - ${day.closeTime}";
  }

  Widget _buildSectionTitle({required IconData icon, required String title}) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 18, color: theme.colorScheme.primary),
      ],
    );
  }

  /// Lays the facts out side by side, each taking the same width, with a
  /// hairline between them.
  Widget _buildStatStrip(List<Widget> stats) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var index = 0; index < stats.length; index++) ...[
          if (index > 0)
            Container(width: 1, height: 40, color: theme.dividerColor),
          Expanded(child: stats[index]),
        ],
      ],
    );
  }

  /// One fact: the icon on top, the answer under it, and the name of the
  /// thing at the bottom.
  ///
  /// [color] tells the fact apart from its neighbours. Left out, it is the
  /// stadium's own green.
  Widget _buildStat({
    required IconData icon,
    required String label,
    required String value,
    Color? color,
  }) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 20,
          fill: 1,
          color: color ?? theme.colorScheme.primary,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
