import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:qabso_mobile/features/manager/working_days/add_working_days_screen.dart';
import 'package:qabso_mobile/features/manager/working_days/edite_single_day_widget.dart';
import 'package:qabso_mobile/features/manager/working_days/working_day_card_widget.dart';
import 'package:qabso_mobile/features/manager/working_days/working_days.dart';
import 'package:qabso_mobile/features/manager/working_days/working_days_notifier_provider.dart';
import 'package:qabso_mobile/utill/app_dailogs.dart';
import 'package:qabso_mobile/utill/error_widget.dart';
import 'package:qabso_mobile/utill/loading_widget.dart';

class WorkingDaysScreen extends ConsumerWidget {
  const WorkingDaysScreen({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workingDaysAsync = ref.watch(workingDaysNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Working Days"),
        actions: [
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

          return RefreshIndicator(
            onRefresh: () async =>
                ref.read(workingDaysNotifierProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
              itemCount: workingDays.length,
              itemBuilder: (_, index) => WorkingDayCardWidget(
                model: workingDays[index],
                onEdit: () => _editDay(context, workingDays[index]),
              ),
            ),
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
