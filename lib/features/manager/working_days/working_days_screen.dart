import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:qabso_mobile/features/manager/working_days/add_working_days_screen.dart';
import 'package:qabso_mobile/features/manager/working_days/working_days.dart';
import 'package:qabso_mobile/features/manager/working_days/working_days_notifier_provider.dart';
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
              icon: const Icon(Symbols.edit),
              label: const Text("Edit"),
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
              itemBuilder: (context, index) => WorkingDayCardWidget(
                model: workingDays[index],
                onEdit: () => _openEditor(context),
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

/// One day of the week: its name, whether the stadium opens that day, and
/// the hours it keeps. A closed day drops to muted colors and shows
/// "Closed" in place of hours, so open and closed days are told apart at a
/// glance rather than by reading times.
class WorkingDayCardWidget extends StatelessWidget {
  const WorkingDayCardWidget({super.key, required this.model, this.onEdit});

  final WorkingDayModel model;

  /// Tapping the card (and its trailing edit button) opens the editor. Left
  /// off, the card is read-only.
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final accent = model.isOpen ? colorScheme.primary : theme.hintColor;

    return Card(
      elevation: model.isOpen ? 1 : 0,
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  model.isOpen ? Symbols.event_available : Symbols.event_busy,
                  size: 24,
                  color: colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      model.dayName,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: model.isOpen ? null : theme.hintColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (model.isOpen)
                      Row(
                        children: [
                          const Icon(Symbols.schedule, size: 16),
                          Text(
                            " ${model.openTime} - ${model.closeTime}",
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      )
                    else
                      Text("Closed all day", style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              _buildStatusChip(context),
              if (onEdit != null)
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Symbols.chevron_right),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    final theme = Theme.of(context);
    final color = model.isOpen ? theme.colorScheme.primary : theme.hintColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        model.isOpen ? "Open" : "Closed",
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
