import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/features/manager/working_days/working_days.dart';
import 'package:qabso_mobile/features/manager/working_days/working_days_notifier_provider.dart';

import '../../../utill/app_date_util.dart';
import '../../../utill/app_utility_service.dart';

class EditeSingleDayWidget extends ConsumerStatefulWidget {
  const EditeSingleDayWidget({required this.day});

  final WorkingDayModel day;

  @override
  ConsumerState<EditeSingleDayWidget> createState() =>
      _EditeSingleDayWidgetState();
}

class _EditeSingleDayWidgetState extends ConsumerState<EditeSingleDayWidget> {
  late WorkingDayModel _day = widget.day;
  bool isSubmitting = false;
  String? _errorText;

  String? get _validationError {
    if (!_day.isOpen) return null;
    if (_day.closeTime.compareTo(_day.openTime) <= 0) {
      return "Close time must be after open time";
    }
    return null;
  }

  Future<void> _pickTime({required bool isOpenTime}) async {
    final current = isOpenTime ? _day.openTime : _day.closeTime;

    final picked = await AppUtilityService.pickTime(
      context: context,
      initialTime: AppDateUtil.parseTimeOfDay(current),
      helpText: isOpenTime
          ? "${_day.dayName} — open time"
          : "${_day.dayName} — close time",
    );
    if (picked == null) return;

    final value = AppDateUtil.formatTimeOfDay(picked);

    setState(() {
      _day = isOpenTime
          ? _day.copyWith(openTime: value)
          : _day.copyWith(closeTime: value);
      _errorText = null;
    });
  }

  Future<void> _handleSave() async {
    if (isSubmitting) return;

    final validation = _validationError;
    if (validation != null) {
      setState(() => _errorText = validation);
      return;
    }

    setState(() {
      isSubmitting = true;
      _errorText = null;
    });

    try {
      await ref.read(workingDaysNotifierProvider.notifier).saveDay(_day);

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isSubmitting = false;
        _errorText = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: !isSubmitting,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12.0,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _day.isOpen
                              ? Symbols.event_available
                              : Symbols.event_busy,
                          fill: 1,
                          color: _day.isOpen
                              ? theme.colorScheme.primary
                              : theme.hintColor,
                        ),
                        const SizedBox(width: 12),
                        Text(_day.isOpen ? "Open this day" : "Closed all day"),
                      ],
                    ),
                    Switch.adaptive(
                      value: _day.isOpen,
                      onChanged: isSubmitting
                          ? null
                          : (v) => setState(() {
                              _day = _day.copyWith(isOpen: v);
                              _errorText = null;
                            }),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: !_day.isOpen
                  ? const SizedBox(width: double.infinity)
                  : Row(
                      children: [
                        Expanded(child: _buildTimeField(isOpenTime: true)),
                        const SizedBox(width: 8),
                        Expanded(child: _buildTimeField(isOpenTime: false)),
                      ],
                    ),
            ),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              Text(
                _errorText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text("Cancel"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isSubmitting ? null : _handleSave,
                    icon: isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Symbols.check),
                    label: const Text("Save"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeField({required bool isOpenTime}) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: isSubmitting ? null : () => _pickTime(isOpenTime: isOpenTime),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: isOpenTime ? "Opens" : "Closes",
          prefixIcon: const Icon(Symbols.schedule, size: 18),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ),
        child: Text(
          isOpenTime ? _day.openTime : _day.closeTime,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
