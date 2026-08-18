import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:qabso_mobile/features/manager/working_days/add_working_days_screen.dart';
import 'package:qabso_mobile/features/manager/working_days/edite_single_day_widget.dart';
import 'package:qabso_mobile/features/manager/working_days/working_day_card_widget.dart';
import 'package:qabso_mobile/features/manager/working_days/working_days.dart';
import 'package:qabso_mobile/features/manager/working_days/working_days_notifier_provider.dart';
import 'package:qabso_mobile/utill/app_constants.dart';
import 'package:qabso_mobile/utill/app_dailogs.dart';
import 'package:qabso_mobile/utill/error_widget.dart';
import 'package:qabso_mobile/utill/loading_widget.dart';
import 'package:qabso_mobile/utill/pref_service.dart';

class WorkingDaysScreen extends ConsumerStatefulWidget {
  const WorkingDaysScreen({super.key});

  @override
  ConsumerState<WorkingDaysScreen> createState() => _WorkingDaysScreenState();
}

class _WorkingDaysScreenState extends ConsumerState<WorkingDaysScreen> {
  /// Whether the panel explaining the screen is showing. Seeded from what the
  /// user chose last time, so a panel they closed stays closed.
  late bool _showInfo;

  @override
  void initState() {
    super.initState();
    _showInfo = !PrefService.get(AppConstants.workingDays);
  }

  /// Shows the panel when it is closed, and closes it when it is showing.
  ///
  /// The screen moves first and the phone is written to afterwards, so the
  /// panel never waits on the disk.
  void _toggleInfo() {
    setState(() => _showInfo = !_showInfo);

    _showInfo
        ? PrefService.delete(AppConstants.workingDays)
        : PrefService.put(AppConstants.workingDays);
  }

  void _openEditor(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddWorkingDaysScreen()),
    );
  }

  Future<void> _editDay(BuildContext context, WorkingDayModel day) async {
    final saved = await showAppBottomSheet<bool>(
      context: context,
      title: day.dayName,
      builder: (sheetContext) =>
          SafeArea(child: EditeSingleDayWidget(day: day)),
    );
    if (saved == true && context.mounted) {
      showSuccessSnackBar(context: context, message: "${day.dayName} updated.");
    }
  }

  /// One notice at a time: the warning takes the header's place while the
  /// stadium is shut every day, and hands it back once a day is open again.
  Widget _buildNotice(BuildContext context, List<WorkingDayModel> days) {
    final isAllClosed = days.every((day) => !day.isOpen);

    return AnimatedSwitcher(
      duration: AppConstants.animationDuration,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1,
          child: child,
        ),
      ),
      // The warning is not the user's to close: a stadium shut every day takes
      // no bookings at all, and that has to stay on screen. Only the panel
      // explaining the screen answers to _showInfo.
      child: isAllClosed
          ? _buildAllClosedWarning(context, key: const ValueKey('warning'))
          : _showInfo
          ? _buildHeader(context, key: const ValueKey('header'))
          : const SizedBox.shrink(key: ValueKey('none')),
    );
  }

  /// Says what the working days are for.
  Widget _buildHeader(BuildContext context, {Key? key}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: key,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Color.alphaBlend(
          colorScheme.primary.withValues(alpha: 0.10),
          colorScheme.surface,
        ),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Symbols.schedule,
              fill: 1,
              size: 30,
              color: colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Working Days", style: theme.textTheme.headlineLarge),
                const SizedBox(height: 6),
                Text(
                  "Kuwani waa maalmaha iyo saacadaha garoonku furan yahay. "
                  "Booking waxaa la sameyn karaa saacadahaas oo kaliya.",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _toggleInfo,
            tooltip: "Close",
            icon: Icon(Symbols.close, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  /// Brings the panel back after it has been closed, and closes it again.
  /// The icon is filled while the panel is showing, so the button says which
  /// way it will go.
  Widget _buildInfoButton() {
    return IconButton(
      onPressed: _toggleInfo,
      tooltip: _showInfo ? "Hide info" : "Show info",
      icon: Icon(Symbols.info, fill: _showInfo ? 1 : 0),
    );
  }

  /// A stadium shut every day takes no bookings at all, which is worth saying
  /// out loud — even though closing every day is allowed.
  Widget _buildAllClosedWarning(BuildContext context, {Key? key}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: key,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Color.alphaBlend(
          colorScheme.error.withValues(alpha: 0.10),
          colorScheme.surface,
        ),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Symbols.warning, fill: 1, size: 22, color: colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Garoonku wuu xiran yahay maalmaha oo dhan",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Booking lagama sameyn karo inta ay sidaas tahay. Fur "
                  "ugu yaraan hal maalin marka aad diyaar tahay.",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final workingDaysAsync = ref.watch(workingDaysNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Working Days"),
        actions: [
          _buildInfoButton(),
          if (workingDaysAsync.value?.isNotEmpty ?? false)
            TextButton.icon(
              onPressed: () => _openEditor(context),
              icon: const Icon(Symbols.edit_calendar),
              label: const Text("Edit all"),
            ),
        ],
      ),
      body: workingDaysAsync.when(
        skipLoadingOnRefresh: false,
        data: (workingDays) {
          if (workingDays.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Symbols.time_auto,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Stadium has no working days",
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => _openEditor(context),
                    icon: const Icon(Symbols.add),
                    label: const Text("Add working days"),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: _buildNotice(context, workingDays),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async =>
                      ref.read(workingDaysNotifierProvider.notifier).refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 8,
                    ),
                    itemCount: workingDays.length,
                    itemBuilder: (_, index) => WorkingDayCardWidget(
                      model: workingDays[index],
                      onEdit: () => _editDay(context, workingDays[index]),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
        error: (error, stackTrace) => ErrorRetryWidget(
          errorMessage: error.toString(),
          onRetry: () =>
              ref.read(workingDaysNotifierProvider.notifier).refresh(),
        ),
        loading: () => const LoadingWidget(),
      ),
    );
  }
}
