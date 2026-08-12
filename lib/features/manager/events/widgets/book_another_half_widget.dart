import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../../utill/app_date_util.dart';
import '../../../../utill/app_input_text_widget.dart';
import '../../../../utill/error_widget.dart';
import '../../../../utill/loading_widget.dart';
import '../event_booking_service.dart';
import '../event_repository.dart';
import '../models/booking_context_model.dart';
import '../models/half_booked_event_model.dart';

/// The booking whose remaining half is being taken, by event id.
///
/// Fails rather than resolving to null when there is no half left to take, so
/// "settled, cancelled, or gone" arrives as one state the widget can name
/// instead of a booking it would have to null-check everywhere it is read.
final halfBookedEventProvider = FutureProvider.autoDispose
    .family<HalfBookedEventModel, int>((ref, eventId) {
      return EventRepository.getHalfBookedEvent(eventId: eventId);
    });

/// Takes the half of a booking that was left owing.
///
/// It loads the booking itself rather than trusting what was on screen, since
/// the other team may have paid it in the meantime.
///
/// No payment method is chosen here. Like [EventBookingOptionsWidget], it
/// works out what is owed and hands that to [EventBookingService], which opens
/// the sheet that fits the signed-in role: the manager's split-and-discount
/// sheet, or the customer's single-merchant one.
class BookAnotherHalfWidget extends ConsumerStatefulWidget {
  /// The field the booking sits on, and the stadium behind it — what the
  /// customer's payment sheet needs to find the merchants to pay.
  final BookingContextModel booking;
  final int eventId;

  const BookAnotherHalfWidget({
    super.key,
    required this.booking,
    required this.eventId,
  });

  @override
  ConsumerState<BookAnotherHalfWidget> createState() =>
      _BookAnotherHalfWidgetState();
}

class _BookAnotherHalfWidgetState extends ConsumerState<BookAnotherHalfWidget> {
  /// The sheet never grows past this share of the screen; past it the content
  /// scrolls instead. Stated here rather than left to whatever the children
  /// happen to measure, so no state can stretch the sheet on its own.
  static const _maxSheetHeightFraction = 0.85;

  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());

  String? eventKeyError;
  bool isBooking = false;

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get eventKey => _controllers.map((e) => e.text).join();

  void _setBusy(bool busy) {
    if (!mounted) return;

    setState(() => isBooking = busy);
  }

  bool _isEventKeyValid(HalfBookedEventModel halfBooking) {
    if (halfBooking.eventKey == null) return true;

    if (eventKey.length < 4) {
      setState(() => eventKeyError = "Fadlan geli event keyga");
      return false;
    }

    if (eventKey != halfBooking.eventKey) {
      setState(() => eventKeyError = "Event-keygan aad gelisay waa khalad");
      return false;
    }

    return true;
  }

  /// Checks the code, then takes the half.
  ///
  /// Taking it is the same work the card does for a public event, so it lives
  /// in [EventBookingService.settleRemainingHalf]. The only extra step here is
  /// the code, which this screen exists for.
  Future<void> _handlePayment(HalfBookedEventModel halfBooking) async {
    if (isBooking) return;

    if (!_isEventKeyValid(halfBooking)) return;

    setState(() => eventKeyError = null);

    final isSettled = await EventBookingService.settleRemainingHalf(
      context: context,
      ref: ref,
      booking: widget.booking,
      event: halfBooking,
      eventKey: eventKey,
      onBusy: _setBusy,
    );

    if (!isSettled || !mounted) return;

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final halfBookedEventFuture = ref.watch(
      halfBookedEventProvider(widget.eventId),
    );

    return halfBookedEventFuture.when(
      data: _buildContent,
      error: (error, stackTrace) => error is StateError
          ? _buildUnavailable()
          : _buildSheet(
              child: ErrorRetryWidget(
                errorMessage: error.toString(),
                onRetry: () =>
                    ref.invalidate(halfBookedEventProvider(widget.eventId)),
              ),
            ),
      loading: () =>
          const SizedBox(height: 160, child: Center(child: LoadingWidget())),
    );
  }

  /// The one shell every state is laid out in, so the sheet keeps a single
  /// height policy: as tall as its content, never past
  /// [_maxSheetHeightFraction] of the screen, and scrollable once it would be.
  ///
  /// No keyboard inset is applied here — `showAppBottomSheet` already pads by
  /// `viewInsets.bottom`, and doing it again moved the content twice as far as
  /// the keyboard.
  Widget _buildSheet({required Widget child}) {
    final maxHeight =
        MediaQuery.sizeOf(context).height * _maxSheetHeightFraction;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
        child: child,
      ),
    );
  }

  Widget _buildContent(HalfBookedEventModel halfBooking) {
    final theme = Theme.of(context);

    return _buildSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Book another half",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildPaymentHeader(halfBooking),
          const SizedBox(height: 24),
          if (halfBooking.eventKey != null) ...[
            _buildEventKeyField(theme),
            const SizedBox(height: 24),
          ],

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isBooking ? null : () => _handlePayment(halfBooking),
              icon: isBooking
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Symbols.payment),
              label: Text("Pay \$${halfBooking.remaining.toStringAsFixed(2)}"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventKeyField(ThemeData theme) {
    final colors = theme.colorScheme;

    return Column(
      children: [
        Text("Put the event key here", style: theme.textTheme.bodyLarge),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(4, (index) {
            return SizedBox(
              width: 55,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: AppInputTextWidget(
                  errorFontSize: 0,
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  enabled: !isBooking,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  verticalPadding: 12,
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  filledColor: colors.surfaceContainerHighest,
                  counterText: "",
                  // No per-field validator on purpose. The field autovalidates
                  // on interaction, so an empty box would add and remove an
                  // error row under itself as the user types — and every one of
                  // those changes the field's height and jumps the sheet. The
                  // whole code is judged once, below, where the message has a
                  // place of its own to sit.
                  onChanged: (value) {
                    if (eventKeyError != null) {
                      setState(() {
                        eventKeyError = null;
                      });
                    }
                    if (value.isNotEmpty && index < 3) {
                      _focusNodes[index + 1].requestFocus();
                    }
                    if (value.isEmpty && index > 0) {
                      _focusNodes[index - 1].requestFocus();
                    }
                  },
                ),
              ),
            );
          }),
        ),
        // Kept in the tree whether or not there is a message, so showing one
        // cannot push everything below it down.
        SizedBox(
          height: 28,
          child: eventKeyError == null
              ? null
              : Center(
                  child: Text(
                    eventKeyError!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.error,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
        ),
        Text(
          "Hadii aad hayn code-kan waydii saxibkaagii qabtay qaybta hore ee event-ka",
          style: theme.textTheme.labelMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  /// Someone else paid the remaining half, or the booking was cancelled.
  Widget _buildUnavailable() {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Symbols.event_busy,
            size: 48,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            "Event-kan hadda lama qaadi karo",
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            "Waxaa laga yaabaa in lacagtiisa la buuxiyay ama la joojiyay.",
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Ok"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHeader(HalfBookedEventModel halfBooking) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.calendar_month,
            title: "Event Date",
            value: AppDateUtil.formatReadableDate(halfBooking.eventStart),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.timer_outlined,
            title: "Start time",
            value: AppDateUtil.formatTime(halfBooking.eventStart),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.timer_outlined,
            title: "End time",
            value: AppDateUtil.formatTime(halfBooking.eventEnd),
          ),
          const SizedBox(height: 12),
          _InfoRow(
            icon: Icons.payments_outlined,
            title: "Remaining",
            value: "\$${halfBooking.remaining.toStringAsFixed(2)}",
            highlight: true,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final bool highlight;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, color: colors.primary, fill: 1),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: highlight ? colors.primary : null,
          ),
        ),
      ],
    );
  }
}
