import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/features/manager/working_days/working_days.dart';
import 'package:qabso_mobile/features/manager/working_days/working_days_notifier_provider.dart';

import '../../../utill/app_dailogs.dart';
import '../../../utill/app_date_util.dart';
import '../../../utill/app_utility_service.dart';

class AddWorkingDaysScreen extends ConsumerStatefulWidget {
  const AddWorkingDaysScreen({super.key});

  @override
  ConsumerState<AddWorkingDaysScreen> createState() =>
      _AddWorkingDaysScreenState();
}

class _AddWorkingDaysScreenState extends ConsumerState<AddWorkingDaysScreen> {
  static const String _defaultOpenTime = '08:00';
  static const String _defaultCloseTime = '22:00';

  late List<WorkingDayModel> _days;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();

    final saved = ref.read(workingDaysNotifierProvider).value ?? const [];
    _days = [
      for (var dayOfWeek = 1; dayOfWeek <= 7; dayOfWeek++)
        saved.firstWhere(
          (day) => day.dayOfWeek == dayOfWeek,
          orElse: () => WorkingDayModel(
            dayOfWeek: dayOfWeek,
            openTime: _defaultOpenTime,
            closeTime: _defaultCloseTime,
            isOpen: true,
          ),
        ),
    ];
  }

  bool get _hasOpenDay => _days.any((day) => day.isOpen);

  bool get _isValid =>
      _hasOpenDay && _days.every((day) => _errorFor(day) == null);

  String? _errorFor(WorkingDayModel day) {
    if (!day.isOpen) return null;
    if (day.closeTime.compareTo(day.openTime) <= 0) {
      return "Close time must be after open time";
    }
    return null;
  }

  void _replaceDay(WorkingDayModel updated) {
    setState(() {
      _days = [
        for (final day in _days)
          day.dayOfWeek == updated.dayOfWeek ? updated : day,
      ];
    });
  }

  Future<void> _pickTime(
    WorkingDayModel day, {
    required bool isOpenTime,
  }) async {
    final current = isOpenTime ? day.openTime : day.closeTime;

    final picked = await AppUtilityService.pickTime(
      context: context,
      initialTime: AppDateUtil.parseTimeOfDay(current),
      helpText: isOpenTime
          ? "${day.dayName} — open time"
          : "${day.dayName} — close time",
    );
    if (picked == null) return;

    final value = AppDateUtil.formatTimeOfDay(picked);

    _replaceDay(
      isOpenTime
          ? day.copyWith(openTime: value)
          : day.copyWith(closeTime: value),
    );
  }

  void _applyFirstDayToAll() {
    final source = _days.firstWhere((day) => day.isOpen);

    setState(() {
      _days = [
        for (final day in _days)
          day.isOpen
              ? day.copyWith(
                  openTime: source.openTime,
                  closeTime: source.closeTime,
                )
              : day,
      ];
    });

    showInfoSnackBar(
      context: context,
      message: "${source.openTime} - ${source.closeTime} applied to open days.",
    );
  }

  Future<void> _handleSubmit() async {
    if (isSubmitting) return;

    if (!_hasOpenDay) {
      showErrorSnackBar(
        context: context,
        message: "Open at least one day of the week.",
      );
      return;
    }
    if (!_isValid) {
      showErrorSnackBar(
        context: context,
        message: "Fix the highlighted days before saving.",
      );
      return;
    }

    setState(() => isSubmitting = true);

    try {
      await ref.read(workingDaysNotifierProvider.notifier).saveDays(_days);

      if (!mounted) return;
      setState(() => isSubmitting = false);

      showSuccessSnackBar(context: context, message: "Working days saved.");

      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isSubmitting = false);
      showErrorSnackBar(context: context, message: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Working days"),
        actions: [
          TextButton.icon(
            onPressed: isSubmitting ? null : _handleSubmit,
            label: const Text("Save"),
            icon: isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Symbols.check),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 8),
              for (final day in _days) ...[
                _buildDayCard(day),
                const SizedBox(height: 8),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  "Dooro maalmaha uu garoonku furan yahay iyo saacadaha",
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
              TextButton.icon(
                onPressed: _hasOpenDay && !isSubmitting
                    ? _applyFirstDayToAll
                    : null,
                icon: const Icon(Symbols.content_copy),
                label: const Text("Apply to all"),
              ),
            ],
          ),
          if (!_hasOpenDay)
            Text(
              "Open at least one day of the week.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDayCard(WorkingDayModel day) {
    final theme = Theme.of(context);
    final error = _errorFor(day);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  day.dayName,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: day.isOpen ? null : theme.hintColor,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      day.isOpen ? "Open" : "Closed",
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(width: 12),
                    Switch.adaptive(
                      value: day.isOpen,
                      onChanged: isSubmitting
                          ? null
                          : (v) => _replaceDay(day.copyWith(isOpen: v)),
                    ),
                  ],
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: !day.isOpen
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildTimeField(day, isOpenTime: true),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildTimeField(day, isOpenTime: false),
                          ),
                        ],
                      ),
                    ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  error,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField(WorkingDayModel day, {required bool isOpenTime}) {
    final theme = Theme.of(context);
    final hasError = _errorFor(day) != null;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: isSubmitting ? null : () => _pickTime(day, isOpenTime: isOpenTime),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: isOpenTime ? "Opens" : "Closes",
          prefixIcon: const Icon(Symbols.schedule, size: 18),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          enabledBorder: hasError
              ? OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.colorScheme.error),
                )
              : null,
        ),
        child: Text(
          isOpenTime ? day.openTime : day.closeTime,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
