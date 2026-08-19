import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/features/auth/app_user_model.dart';
import 'package:qabso_mobile/features/auth/app_user_notifer.dart';
import 'package:qabso_mobile/features/manager/events/event_booking_service.dart';
import 'package:qabso_mobile/features/manager/events/event_notifier_provider.dart';
import 'package:qabso_mobile/features/manager/events/models/booking_context_model.dart';
import 'package:qabso_mobile/features/manager/events/time_slots_model.dart';
import 'package:qabso_mobile/features/manager/events/widgets/event_details_sheet.dart';
import 'package:qabso_mobile/utill/app_dailogs.dart';

class NewTimeSlotCard extends ConsumerWidget {
  final BookingContextModel booking;
  final TimeSlotModel slotModel;

  const NewTimeSlotCard({
    super.key,
    required this.booking,
    required this.slotModel,
  });

  bool get _isPastAndFree =>
      slotModel.isAvailable && slotModel.startTime.isBefore(DateTime.now());

  void _onTap(BuildContext context, WidgetRef ref) {
    final role = ref.read(appUserNotifierProvider).value?.role;

    if (role == null) return;
    switch (role) {
      case AppUserRole.manager:
        _onManagerTap(context, ref);
      case AppUserRole.user:
        _onUserTap(context);
      case AppUserRole.referee:
        break;
    }
  }

  Future<void> _onManagerTap(BuildContext context, WidgetRef ref) async {
    if (slotModel.eventStatus == EventStatus.confirmed) {
      await _openConfirmedSlotOptions(context);
      return;
    }

    if (!slotModel.isAvailable) return;

    final payment = await EventBookingService.collectPayment(
      context: context,
      ref: ref,
      booking: booking,
      slot: slotModel,
      amount: EventBookingService.amountDue(
        slotPrice: booking.slotPrice,
        isHalfBooking: false,
      ),
    );

    if (payment == null || !context.mounted) return;

    final eventId = await EventBookingService.book(
      context: context,
      ref: ref,
      booking: booking,
      slot: slotModel,
      payment: payment,
      isHalfBooking: false,
      onBusy: (busy) => _showBusy(context, busy),
      refreshSlots: false,
    );

    if (eventId == null || !context.mounted) return;

    await _showBookingDoneDialog(context, ref);
  }

  /// A slot that is already sold. The manager picks what to do with it.
  ///
  /// Only the first option works today. The other two say so instead of
  /// doing nothing, so the manager knows the tap was heard.
  Future<void> _openConfirmedSlotOptions(BuildContext context) async {
    final eventId = slotModel.eventId;
    if (eventId == null) return;

    await showAppBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSheetHeader(theme),
            _buildActionTile(
              theme: theme,
              icon: Symbols.receipt_long,
              color: theme.colorScheme.primary,
              title: "Event Info",
              description: "Eeg faahfaahinta event-kan iyo xogta booking-ka.",
              isPrimary: true,
              onTap: () {
                Navigator.pop(sheetContext);
                EventDetailsSheet.show(context, eventId: eventId);
              },
            ),
            const Divider(height: 1, indent: 20, endIndent: 20),
            _buildActionTile(
              theme: theme,
              icon: Symbols.edit_calendar,
              color: theme.colorScheme.tertiary,
              title: "Re-schedule",
              description: "Beddel waqtiga event-kan oo u qorshee waqti kale.",
              onTap: () {
                Navigator.pop(sheetContext);
                showNotImplementedDialog(context: context);
              },
            ),
            const Divider(height: 1, indent: 20, endIndent: 20),
            _buildActionTile(
              theme: theme,
              icon: Symbols.cancel,
              color: theme.colorScheme.error,
              title: "Cancel Event",
              description: "Jooji booking-kan, lacagtana u celi macmiilka",
              onTap: () {
                Navigator.pop(sheetContext);
                showNotImplementedDialog(context: context);
              },
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  Widget _buildSheetHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Event Options",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildTimeChip(theme),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Eventkan horey ayaa loo qabsaday. Dooro action ka aad rabto.",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Symbols.schedule,
            size: 16,
            fill: 1,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            slotModel.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required ThemeData theme,
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: _buildTileIcon(icon, color),
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: isPrimary ? FontWeight.bold : FontWeight.w600,
          color: isPrimary ? color : null,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Text(
          description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      trailing: Icon(
        Symbols.chevron_right,
        size: 20,
        color: theme.colorScheme.outline,
      ),
    );
  }

  Widget _buildTileIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, fill: 1, color: color),
    );
  }

  void _showBusy(BuildContext context, bool busy) {
    if (busy) {
      showAppLoadingDialog(context: context, message: "Booking event...");
      return;
    }
    hideAppLoadingDialog(context);
  }

  Future<void> _showBookingDoneDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final bookAnother = await showAppConfirmationDialog(
      context: context,
      icon: Symbols.check_circle,
      title: "Booked Successfully",
      message:
          "Waqtigaagu waa ${slotModel.label}. Fadlan usheeg in ay wakhtiga ilashaan ciyaarayashu insha Alah"
          "aadan u seegin.",
      confirmText: "Book new event",
      cancelText: "Thanks",
    );

    if (bookAnother) {
      ref.invalidate(eventTimeSlotsProvider(booking.fieldId));
    } else {
      if (context.mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    }
  }

  void _onUserTap(BuildContext context) {}

  BoxDecoration _buildDecoration(ThemeData theme) {
    final booked = theme.colorScheme.primary.withValues(alpha: 0.5);
    final free = theme.colorScheme.surfaceContainerHighest;

    if (_isPastAndFree) {
      return _slotDecoration(
        color: free.withValues(alpha: 0.4),
        border: theme.dividerColor.withValues(alpha: 0.4),
      );
    }

    if (slotModel.isAvailable) {
      return _slotDecoration(color: free, border: theme.dividerColor);
    }

    if (slotModel.eventStatus == EventStatus.pending) {
      return _slotDecoration(
        border: booked,
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [booked, booked, free, free],
          stops: const [0, 0.54, 0.54, 1],
        ),
      );
    }

    return _slotDecoration(color: booked, border: booked);
  }

  BoxDecoration _slotDecoration({
    Color? color,
    Gradient? gradient,
    required Color border,
  }) {
    return BoxDecoration(
      color: color,
      gradient: gradient,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: border),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final foreground = _isPastAndFree
        ? theme.disabledColor
        : theme.colorScheme.onSurface;

    return badges.Badge(
      position: badges.BadgePosition.topStart(top: -4, start: -2),
      showBadge:
          (slotModel.isPrivate && slotModel.eventStatus == EventStatus.pending),
      badgeStyle: badges.BadgeStyle(
        shape: badges.BadgeShape.square,
        badgeColor: theme.colorScheme.tertiary,
        borderRadius: BorderRadius.circular(24),
        elevation: 1,
      ),
      badgeContent: Icon(
        Symbols.lock,
        size: 12,
        color: theme.colorScheme.onPrimary,
      ),
      child: Card(
        elevation: 0,
        child: InkWell(
          onTap: () => _onTap(context, ref),
          child: Container(
            padding: const EdgeInsets.all(12.0),
            decoration: _buildDecoration(theme),
            child: Text(
              slotModel.label,
              style: theme.textTheme.bodySmall!.copyWith(
                fontWeight: FontWeight.bold,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
