import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../utill/app_dailogs.dart';
import '../../../../utill/app_date_util.dart';
import '../../../../utill/app_utility_service.dart';
import '../../../../utill/error_widget.dart';
import '../../../../utill/loading_widget.dart';
import '../event_repository.dart';
import '../time_slots_list_widget.dart';
import '../time_slots_model.dart';

/// Moves one booking to another hour on the same field.
///
/// The manager sees the hour they are changing, picks a free one, then
/// confirms. The sheet closes with the slot that was chosen, so the screen
/// that opened it can say how it went.
///
/// ```dart
/// final newSlot = await RescheduleEventWidget.show(
///   context,
///   fieldId: booking.fieldId,
///   currentSlot: slot,
/// );
/// ```
class RescheduleEventWidget extends ConsumerStatefulWidget {
  final int fieldId;
  final TimeSlotModel currentSlot;

  const RescheduleEventWidget({
    super.key,
    required this.fieldId,
    required this.currentSlot,
  });

  /// Opens the sheet and returns the new slot, or null when nothing moved.
  static Future<TimeSlotModel?> show(
    BuildContext context, {
    required int fieldId,
    required TimeSlotModel currentSlot,
  }) {
    return showAppBottomSheet<TimeSlotModel>(
      context: context,
      builder: (sheetContext) =>
          RescheduleEventWidget(fieldId: fieldId, currentSlot: currentSlot),
    );
  }

  @override
  ConsumerState<RescheduleEventWidget> createState() =>
      _RescheduleEventWidgetState();
}

class _RescheduleEventWidgetState extends ConsumerState<RescheduleEventWidget> {
  /// The day whose hours are on screen. It starts on the day the booking grid
  /// is showing and is the sheet's own from then on, so moving it here does
  /// not move the grid behind.
  late DateTime _selectedDate;

  /// Held in state rather than built in `build`: a future created inline would
  /// re-read on every rebuild.
  late Future<List<TimeSlotModel>> _slotsFuture;

  TimeSlotModel? _selectedSlot;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = ref.read(selectedDateProvider);
    _slotsFuture = _loadSlots();
  }

  Future<List<TimeSlotModel>> _loadSlots() {
    return EventRepository.getTimeSlots(
      fieldId: widget.fieldId,
      date: _selectedDate,
    );
  }

  /// A new day means new hours and no choice yet.
  void _changeDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _selectedSlot = null;
      _slotsFuture = _loadSlots();
    });
  }

  void _reloadSlots() {
    setState(() => _slotsFuture = _loadSlots());
  }

  /// A slot can be taken only when it is free and still ahead of us. The hour
  /// the booking already sits on is not offered again.
  bool _canPick(TimeSlotModel slot) {
    if (!slot.isAvailable) return false;
    if (slot.startTime.isBefore(DateTime.now())) return false;

    return slot.startTime != widget.currentSlot.startTime;
  }

  void _pickSlot(TimeSlotModel slot) {
    setState(() => _selectedSlot = slot);
  }

  /// Writes the new hour. The button holds still while this runs, so the same
  /// booking cannot be moved twice.
  Future<void> _confirm() async {
    final slot = _selectedSlot;
    final eventId = widget.currentSlot.eventId;

    if (slot == null || eventId == null || _isSaving) return;

    setState(() => _isSaving = true);

    try {
      await EventRepository.rescheduleEvent(
        eventId: eventId,
        startTime: slot.startTime,
      );
    } catch (error) {
      if (!mounted) return;

      setState(() => _isSaving = false);

      await showAppErrorDialog(
        context: context,
        title: "Waqtiga lama beddelin",
        message: error is PostgrestException ? error.message : error.toString(),
      );
      return;
    }

    if (!mounted) return;

    setState(() => _isSaving = false);
    Navigator.pop(context, slot);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme),
          const SizedBox(height: 16),
          _buildCurrentBooking(theme),
          const SizedBox(height: 20),
          _buildStepTitle(theme),
          _buildDateRow(theme),
          const SizedBox(height: 8),
          _buildSlots(theme),
          const SizedBox(height: 20),
          _buildConfirmButton(theme),
        ],
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildIconChip(theme, Symbols.edit_calendar),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Re-schedule Event",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          "Dooro waqti cusub oo bannaan. Lacagta iyo xogta booking-ka way "
          "sidooda ahaanayaan.",
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// An icon in a soft square of the app's own colour.
  Widget _buildIconChip(ThemeData theme, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, fill: 1, color: theme.colorScheme.primary),
    );
  }

  /// The hour the booking sits on today, so the manager sees what is moving.
  Widget _buildCurrentBooking(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildIconChip(theme, Symbols.schedule),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Waqtiga hadda",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.currentSlot.label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTitle(ThemeData theme) {
    return Text(
      "Dooro waqti cusub",
      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
    );
  }

  /// The day the slots below belong to. A booking can move up to a week ahead,
  /// the same window the booking grid uses.
  Widget _buildDateRow(ThemeData theme) {
    final today = DateUtils.dateOnly(DateTime.now());
    final maxDate = today.add(const Duration(days: 7));
    final selected = DateUtils.dateOnly(_selectedDate);

    final canGoBack = selected.isAfter(today);
    final canGoForward = selected.isBefore(maxDate);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: canGoBack ? () => _moveDay(-1) : null,
          icon: const Icon(Symbols.chevron_left),
        ),
        InkWell(
          onTap: _openDatePicker,
          child: Text(
            AppDateUtil.formatReadableDate(_selectedDate),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        IconButton(
          onPressed: canGoForward ? () => _moveDay(1) : null,
          icon: const Icon(Symbols.chevron_right),
        ),
      ],
    );
  }

  void _moveDay(int days) {
    _changeDate(_selectedDate.add(Duration(days: days)));
  }

  Future<void> _openDatePicker() async {
    final pickedDate = await AppUtilityService.pickDate(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 7)),
    );

    if (pickedDate == null || !mounted) return;

    _changeDate(pickedDate);
  }

  /// The hours of the chosen day. They are read straight from the repository,
  /// so the sheet shows its own day without moving the grid's.
  Widget _buildSlots(ThemeData theme) {
    return FutureBuilder<List<TimeSlotModel>>(
      future: _slotsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget();
        }

        final error = snapshot.error;
        if (error != null) {
          if (error is PostgrestException) {
            return Text(error.message, style: theme.textTheme.bodySmall);
          }

          return ErrorRetryWidget(
            errorMessage: error.toString(),
            onRetry: _reloadSlots,
          );
        }

        final slots = snapshot.data ?? const <TimeSlotModel>[];

        if (slots.isEmpty) {
          return Text(
            "Maalintan waqti bannaan ma jiro.",
            style: theme.textTheme.bodySmall,
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: slots.map((slot) => _buildSlotCard(theme, slot)).toList(),
        );
      },
    );
  }

  /// One hour to pick. A taken hour is shown but cannot be chosen.
  Widget _buildSlotCard(ThemeData theme, TimeSlotModel slot) {
    final canPick = _canPick(slot);
    final isSelected = _selectedSlot?.startTime == slot.startTime;

    final background = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.surfaceContainerHighest;

    final foreground = isSelected
        ? theme.colorScheme.onPrimary
        : canPick
        ? theme.colorScheme.onSurface
        : theme.disabledColor;

    return InkWell(
      onTap: canPick && !_isSaving ? () => _pickSlot(slot) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: canPick || isSelected
              ? background
              : background.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? theme.colorScheme.primary : theme.dividerColor,
          ),
        ),
        child: Text(
          slot.label,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: foreground,
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmButton(ThemeData theme) {
    final slot = _selectedSlot;

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: slot == null || _isSaving ? null : _confirm,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(slot == null ? "Dooro waqti" : "Beddel waqtiga"),
      ),
    );
  }
}
