import 'dart:math';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/features/manager/events/time_slots_model.dart';
import 'package:qabso_mobile/features/manager/events/widgets/selected_time_widget.dart';

class EventBookingOptionsWidget extends StatefulWidget {
  final TimeSlotModel selectedTime;
  final String? stadiumId;
  final double requiredAmount;

  const EventBookingOptionsWidget({
    super.key,
    required this.requiredAmount,
    this.stadiumId,
    required this.selectedTime,
  });

  @override
  State<EventBookingOptionsWidget> createState() =>
      _EventBookingOptionsWidgetState();
}

class _EventBookingOptionsWidgetState extends State<EventBookingOptionsWidget> {
  bool isHalfTaken = false;
  bool isLocked = false;
  bool isBooking = false;
  String? generateCode;

  /// What is actually being paid now, derived from the toggle rather than
  /// stored. `widget.requiredAmount` stays the untouched original, so
  /// switching Half Booking on and off returns to exactly the full price
  /// instead of halving what was already halved.
  double get amountPaid =>
      isHalfTaken ? widget.requiredAmount / 2 : widget.requiredAmount;

  String generateFourDigitCode() {
    final random = Random();
    return (1000 + random.nextInt(9000)).toString();
  }

  void _reCalculate() {
    setState(() {
      isHalfTaken = !isHalfTaken;

      // Locking only means anything while half is still owed.
      if (!isHalfTaken) {
        isLocked = false;
        generateCode = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: .min,
        crossAxisAlignment: .start,
        children: [
          SelectedTimeWidget(selectedModel: widget.selectedTime),
          const SizedBox(height: 12),
          Text(
            "Booking Options",
            style: Theme.of(
              context,
            ).textTheme.bodyMedium!.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              onTap: _reCalculate,
              leading: Icon(Symbols.sliders, color: theme.colorScheme.tertiary),
              title: Text(
                "Half Booking",
                style: TextStyle(fontWeight: FontWeight.bold, height: 2),
              ),
              subtitle: Text(
                "Waxaan bixinayaa qaybta kooxdayda, halfka kale waxa biin doona kooxda kale i.a",
                style: Theme.of(context).textTheme.labelMedium,
              ),
              trailing: AbsorbPointer(
                absorbing: true,
                child: Checkbox.adaptive(
                  value: isHalfTaken,
                  onChanged: (v) => _reCalculate,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Card(
            elevation: !isHalfTaken ? 0 : 1,
            child: ListTile(
              onTap: !isHalfTaken
                  ? null
                  : () {
                      setState(() {
                        isLocked = !isLocked;
                        generateCode = isLocked
                            ? generateFourDigitCode()
                            : null;
                      });
                    },
              leading: Icon(Symbols.lock, color: theme.colorScheme.tertiary),
              title: Text(
                "Lock Remaining Half",
                style: TextStyle(fontWeight: FontWeight.bold, height: 2),
              ),
              subtitle: Text(
                "Xidh eventka oo hel 4 digit code aad siin karto kooxda lacagta bixinaysa.",
                style: Theme.of(context).textTheme.labelMedium,
              ),
              trailing: AbsorbPointer(
                child: Switch.adaptive(
                  value: isLocked,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  inactiveThumbColor: Theme.of(context).colorScheme.primary,
                  onChanged: isHalfTaken ? (v) {} : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Symbols.payments),
              label: Text("Pay  \$${amountPaid.toStringAsFixed(2)}"),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
