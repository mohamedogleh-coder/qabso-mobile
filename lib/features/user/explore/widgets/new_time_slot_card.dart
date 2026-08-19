import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/features/auth/app_user_model.dart';
import 'package:qabso_mobile/features/auth/app_user_notifer.dart';
import 'package:qabso_mobile/features/manager/events/models/booking_context_model.dart';
import 'package:qabso_mobile/features/manager/events/time_slots_model.dart';

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
        _onManagerTap(context);
      case AppUserRole.user:
        _onUserTap(context);
      case AppUserRole.referee:
        break;
    }
  }

  void _onManagerTap(BuildContext context) {}

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
