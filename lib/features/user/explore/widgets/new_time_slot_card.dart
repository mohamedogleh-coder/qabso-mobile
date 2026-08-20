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
import 'package:qabso_mobile/features/manager/events/widgets/cancel_event_widget.dart';
import 'package:qabso_mobile/features/manager/events/widgets/event_details_sheet.dart';
import 'package:qabso_mobile/features/manager/events/widgets/reschedule_event_widget.dart';
import 'package:qabso_mobile/payments/payment_allocation_model.dart';
import 'package:qabso_mobile/payments/payment_result.dart';
import 'package:qabso_mobile/payments/user_payment_widget.dart';
import 'package:qabso_mobile/utill/app_dailogs.dart';
import 'package:url_launcher/url_launcher.dart';

class NewTimeSlotCard extends ConsumerWidget {
  final BookingContextModel booking;
  final TimeSlotModel slotModel;

  const NewTimeSlotCard({
    super.key,
    required this.booking,
    required this.slotModel,
  });

  bool get _isPastAndFree => slotModel.isAvailable && slotModel.isPast;

  /// A booked hour that has already been played.
  bool get _isPlayed =>
      slotModel.isPast && slotModel.eventStatus == EventStatus.confirmed;

  void _onTap(BuildContext context, WidgetRef ref) {
    final role = ref.read(appUserNotifierProvider).value?.role;

    if (role == null) return;
    switch (role) {
      case AppUserRole.manager:
        _onManagerTap(context, ref);
      case AppUserRole.user:
        _onUserTap(context, ref);
      case AppUserRole.referee:
        break;
    }
  }

  /// The time of this slot has gone by. A free one can no longer be booked,
  /// so we only say so. A taken one still opens its event info, because the
  /// manager may read any booking on their own field.
  void _onPastTap(BuildContext context) {
    final eventId = slotModel.eventId;

    if (slotModel.isAvailable || eventId == null) {
      _showPastDialog(context);
      return;
    }

    EventDetailsSheet.show(context, eventId: eventId);
  }

  void _showPastDialog(BuildContext context) {
    showInformationDialog(
      context: context,
      icon: Symbols.history,
      title: "Event-kan waa past",
      message: "Waqtigiisu wuu dhaafay, ciduna ma qaadan.",
    );
  }

  Future<void> _onManagerTap(BuildContext context, WidgetRef ref) async {
    if (slotModel.isPast) {
      _onPastTap(context);
      return;
    }

    if (slotModel.eventStatus == EventStatus.confirmed) {
      await _openConfirmedSlotOptions(context, ref);
      return;
    }

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

  Future<void> _openConfirmedSlotOptions(
    BuildContext context,
    WidgetRef ref,
  ) async {
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
              title: "Event Information",
              description: "Eeg faahfaahinta event-kan iyo xogta booking-ka.",
              // isPrimary: true,
              onTap: () {
                Navigator.pop(sheetContext);
                EventDetailsSheet.show(context, eventId: eventId);
              },
            ),
            if (slotModel.referenceNumber != null) ...[
              const Divider(height: 1, indent: 20, endIndent: 20),
              _buildActionTile(
                theme: theme,
                icon: Symbols.call,
                color: Colors.brown,
                title: "Call Booked User",
                description:
                    "Wac qofka qabsaday event-kan: "
                    "${slotModel.referenceNumber}",
                onTap: () {
                  Navigator.pop(sheetContext);
                  _callBookedUser(context);
                },
              ),
            ],
            const Divider(height: 1, indent: 20, endIndent: 20),
            _buildActionTile(
              theme: theme,
              icon: Symbols.edit_calendar,
              color: theme.colorScheme.tertiary,
              title: "Re-schedule",
              description: "Beddel waqtiga event-kan oo u qorshee waqti kale.",
              onTap: () {
                Navigator.pop(sheetContext);
                _openReschedule(context, ref);
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
                CancelEventWidget.show(
                  context,
                  eventId: eventId,
                  fieldId: booking.fieldId,
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }

  /// Opens the phone dialler with the customer's number already typed in.
  /// The manager still presses call themselves, so nothing is dialled by
  /// accident.
  Future<void> _callBookedUser(BuildContext context) async {
    final phone = slotModel.referenceNumber;
    if (phone == null) return;

    final opened = await launchUrl(Uri(scheme: "tel", path: phone));

    if (opened || !context.mounted) return;

    await showAppErrorDialog(
      context: context,
      title: "Wicitaanku ma furmin",
      message: "Telefoonkan ma furi karo lambarka $phone.",
    );
  }

  /// Opens the sheet where the manager picks a new hour, then says how it
  /// went. Nothing is shown when they close the sheet without moving it.
  Future<void> _openReschedule(BuildContext context, WidgetRef ref) async {
    final newSlot = await RescheduleEventWidget.show(
      context,
      fieldId: booking.fieldId,
      currentSlot: slotModel,
    );

    if (newSlot == null || !context.mounted) return;

    await _showRescheduleDoneDialog(context, ref, newSlot);
  }

  /// Tells the manager the booking moved, and asks where to go next. Staying
  /// reloads the grid so the hour shows in its new place.
  Future<void> _showRescheduleDoneDialog(
    BuildContext context,
    WidgetRef ref,
    TimeSlotModel newSlot,
  ) async {
    final theme = Theme.of(context);

    final stayHere = await showAppConfirmationDialog(
      context: context,
      icon: Symbols.event_available,
      title: "Waqtiga waa la beddelay",
      confirmText: "Stay Bookings",
      cancelText: "Go to Home",
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Event-kan waxaa loo wareejiyay waqti cusub.",
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          _buildTimeChange(theme, newSlot),
        ],
      ),
    );

    if (!context.mounted) return;

    if (stayHere) {
      ref.invalidate(eventTimeSlotsProvider(booking.fieldId));
      return;
    }

    Navigator.popUntil(context, (route) => route.isFirst);
  }

  /// The old hour, an arrow, then the new one, so the change is read at once.
  Widget _buildTimeChange(ThemeData theme, TimeSlotModel newSlot) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            slotModel.label,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              decoration: TextDecoration.lineThrough,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(
            Symbols.arrow_forward,
            size: 18,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Flexible(
          child: Text(
            newSlot.label,
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
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
            color: theme.hintColor.withValues(alpha: 0.9),
          ),
        ),
      ),
      trailing: Icon(
        Symbols.chevron_right,
        size: 20,
        color: theme.hintColor.withValues(alpha: 0.5),
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
          "Xiliga la qabtay waa ${slotModel.label}. Fadlan ciyaarayasha usheeg in ay wakhtiga ilashaan  insha Alah",
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

  /// What a customer sees when they tap an hour.
  ///
  /// Their own booking opens. Somebody else's only says it is taken. An hour
  /// nobody took and that has gone by says so.
  void _onUserTap(BuildContext context, WidgetRef ref) {
    final eventId = slotModel.eventId;

    if (slotModel.isMine && eventId != null) {
      EventDetailsSheet.show(context, eventId: eventId);
      return;
    }

    if (!slotModel.isAvailable) {
      showInformationDialog(
        context: context,
        icon: Symbols.event_busy,
        title: "Event-kan waa la qaatay",
        message:
            "Fadlan faah-faahinta even-kan waxa arki kara ruuxa booking ka sameyey.",
      );
      return;
    }

    if (slotModel.isPast) {
      _showPastDialog(context);
      return;
    }

    _bookSlot(context, ref);
  }

  /// Takes the customer's payment and books the hour.
  ///
  /// The sheet stays open until the booking is written, so the waiting and
  /// any error are shown on the sheet itself. It closes only once the hour is
  /// theirs.
  Future<void> _bookSlot(BuildContext context, WidgetRef ref) async {
    final booked = await showAppBottomSheet<bool>(
      context: context,
      title: slotModel.label,
      builder: (sheetContext) => UserPaymentWidget(
        stadiumId: booking.stadiumId,
        requiredAmount: EventBookingService.amountDue(
          slotPrice: booking.slotPrice,
          isHalfBooking: false,
        ),
        timeSlotModel: slotModel,
        onSubmit: (payment) => _payAndBook(sheetContext, ref, payment),
      ),
    );

    if (booked != true || !context.mounted) return;

    await _showTimeKeptDialog(context);
  }

  /// Writes the booking from inside the payment sheet. A failure leaves the
  /// sheet open with its own dialog on top, so the customer can try again.
  Future<void> _payAndBook(
    BuildContext sheetContext,
    WidgetRef ref,
    PaymentAllocationModel allocation,
  ) async {
    final eventId = await EventBookingService.book(
      context: sheetContext,
      ref: ref,
      booking: booking,
      slot: slotModel,
      payment: PaymentResult(
        requiredAmount: allocation.amountPaid,
        allocations: [allocation],
      ),
      isHalfBooking: false,
      refreshSlots: false,
    );

    if (eventId == null || !sheetContext.mounted) return;

    Navigator.pop(sheetContext, true);
  }

  /// Tells the customer the hour is theirs, then takes them home. The grid
  /// they came from disposes itself on the way out, so there is nothing to
  /// reload.
  Future<void> _showTimeKeptDialog(BuildContext context) async {
    await showInformationDialog(
      context: context,
      icon: Symbols.event_available,
      title: "Waqtigaaga waa la qabsaday",
      message: "Fadlan ha seegin, oo garoonka ku timaw waqtigaas.",
      content: _buildTimeChip(Theme.of(context)),
      buttonText: "Thanks",
      barrierDismissible: false,
    );

    if (!context.mounted) return;

    Navigator.popUntil(context, (route) => route.isFirst);
  }

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

    if (_isPlayed) {
      return _slotDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.18),
        border: theme.colorScheme.primary.withValues(alpha: 0.30),
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

    return _buildBadge(theme, _buildCard(context, ref, theme));
  }

  /// One corner mark. It says whose booking it is first, since that is what
  /// the customer looks for, and what happened to the hour after. A lock is
  /// only left for somebody else's private half booking.
  Widget _buildBadge(ThemeData theme, Widget child) {
    final isMine = slotModel.isMine;
    final isPlayed = _isPlayed;
    final isLocked =
        slotModel.isPrivate && slotModel.eventStatus == EventStatus.pending;

    final label = isMine && isPlayed
        ? "You, played"
        : isMine
        ? "You"
        : isPlayed
        ? "Played"
        : null;

    return badges.Badge(
      position: badges.BadgePosition.topStart(top: -4, start: -2),
      showBadge: label != null || isLocked,
      badgeStyle: badges.BadgeStyle(
        shape: badges.BadgeShape.square,
        badgeColor: isMine
            ? theme.colorScheme.primary
            : theme.colorScheme.tertiary,
        borderRadius: BorderRadius.circular(24),
        elevation: 1,
      ),
      badgeContent: label != null
          ? Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isMine
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onTertiary,
              ),
            )
          : Icon(Symbols.lock, size: 12, color: theme.colorScheme.onTertiary),
      child: child,
    );
  }

  Widget _buildCard(BuildContext context, WidgetRef ref, ThemeData theme) {
    final foreground = _isPastAndFree
        ? theme.disabledColor
        : theme.colorScheme.onSurface;

    return Card(
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
    );
  }
}
