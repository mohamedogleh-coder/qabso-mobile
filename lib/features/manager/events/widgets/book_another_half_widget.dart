import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../../utill/app_date_util.dart';
import '../../../../utill/app_input_text_widget.dart';
import '../../../../utill/error_widget.dart';
import '../../../../utill/loading_widget.dart';
import '../event_repository.dart';
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

class BookAnotherHalfWidget extends ConsumerStatefulWidget {
  final int eventId;

  const BookAnotherHalfWidget({super.key, required this.eventId});

  @override
  ConsumerState<BookAnotherHalfWidget> createState() =>
      _BookAnotherHalfWidgetState();
}

class _BookAnotherHalfWidgetState extends ConsumerState<BookAnotherHalfWidget> {
  final List<TextEditingController> _controllers = List.generate(
    4,
    (_) => TextEditingController(),
  );
  final _formKey = GlobalKey<FormState>();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final halfBookedEventFuture = ref.watch(
      halfBookedEventProvider(widget.eventId),
    );

    return halfBookedEventFuture.when(
      data: (halfBooking) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 8,
            right: 8,
            top: 8,
          ),

          child: SingleChildScrollView(
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
                  Text(
                    "Put the event key here",
                    style: theme.textTheme.bodyLarge?.copyWith(),
                  ),
                  const SizedBox(height: 8),
                  Form(
                    key: _formKey,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        return Container(
                          width: 55,
                          height: 60,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          child: AppInputTextWidget(
                            errorFontSize: 0,
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            verticalPadding: 12,
                            textAlign: TextAlign.center,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            filledColor: colors.surfaceContainerHighest,
                            counterText: "",
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
                            validator: (value) {
                              if (halfBooking.eventKey != null) {
                                if (value == null || value.trim().isEmpty) {
                                  return "";
                                }
                              }
                              return null;
                            },
                          ),
                        );
                      }),
                    ),
                  ),
                  if (eventKeyError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      eventKeyError!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.error,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    "Hadii aad hayn code-kan waydii saxibkaagii qabtay qaybta hore ee event-ka",
                    style: theme.textTheme.labelMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                ],

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      if (halfBooking.eventKey != null) {
                        final isValid =
                            _formKey.currentState?.validate() ?? false;
                        if (!isValid) return;

                        if (eventKey != halfBooking.eventKey) {
                          setState(() {
                            eventKeyError = "Invalid key";
                          });
                          return;
                        }
                      }

                      setState(() {
                        eventKeyError = null;
                      });
                    },
                    icon: const Icon(Symbols.payment),
                    label: Text("Pay \$${halfBooking.remaining}"),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
      // A half that is no longer there is not a failed read: retrying it would
      // only fail again, so it is answered rather than offered a retry.
      error: (error, stackTrace) => error is StateError
          ? _buildUnavailable()
          : Padding(
              padding: const EdgeInsets.all(16),
              child: ErrorRetryWidget(
                errorMessage: error.toString(),
                onRetry: () =>
                    ref.invalidate(halfBookedEventProvider(widget.eventId)),
              ),
            ),
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: LoadingWidget(),
      ),
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
        mainAxisSize: .min,
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
