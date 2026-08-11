import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/features/manager/events/time_slots_model.dart';
import 'package:qabso_mobile/features/manager/stadium/stadium_notifier_provider.dart';
import 'package:qabso_mobile/payments/user_payment_widget.dart';
import 'package:qabso_mobile/utill/app_dailogs.dart';

final selectedTimeSlotProvider = StateProvider<TimeSlotModel?>((ref) => null);

class TimeSlotCardWidget extends ConsumerStatefulWidget {
  final TimeSlotModel slotModel;

  const TimeSlotCardWidget({super.key, required this.slotModel});

  @override
  ConsumerState<TimeSlotCardWidget> createState() => _TimeSlotCardWidgetState();
}

class _TimeSlotCardWidgetState extends ConsumerState<TimeSlotCardWidget> {
  double amountPaid = 0;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _openPaymentSheet() async {
    final stadium = ref.read(stadiumNotifierProvider).value;
    // final payment = await showPaymentSheet(
    //   context: context,
    //   requiredAmount: 10,
    //   title: widget.slotModel.label,
    // );
    //
    // if (payment == null || !mounted) return;
    //
    // final split = payment.allocations
    //     .map(
    //       (a) =>
    //           "${a.methodName} \$${a.amountPaid.toStringAsFixed(2)}"
    //           "${a.isCash ? '' : ' (${a.merchantNumber})'}",
    //     )
    //     .join(", ");
    //
    // showSuccessSnackBar(
    //   context: context,
    //   message:
    //       "Required \$${payment.requiredAmount.toStringAsFixed(2)}, "
    //       "discount \$${payment.discount.toStringAsFixed(2)} → $split",
    // );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final background = widget.slotModel.isAvailable
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : (widget.slotModel.eventStatus == EventStatus.pending
              ? theme.colorScheme.tertiary.withValues(alpha: 0.3)
              : theme.colorScheme.primary.withValues(alpha: 0.5));

    final foreground = widget.slotModel.isAvailable
        ? theme.colorScheme.onSurface
        : (widget.slotModel.eventStatus == EventStatus.pending
              ? theme.colorScheme.onSurface
              : theme.colorScheme.onSurface);

    final borderColor = widget.slotModel.isAvailable
        ? Theme.of(context).dividerColor
        : (widget.slotModel.eventStatus == EventStatus.pending
              ? theme.colorScheme.tertiary.withValues(alpha: 0.3)
              : theme.colorScheme.primary.withValues(alpha: 0.5));

    return badges.Badge(
      position: badges.BadgePosition.topStart(top: -4, start: -2),
      showBadge: widget.slotModel.isPrivate,
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
          onTap: () {
            showAppBottomSheet(
              context: context,
              builder: (context) {
                final stadium = ref.read(stadiumNotifierProvider).value;
                return UserPaymentWidget(
                  stadiumId: stadium!.stadiumId!,
                  requiredAmount: 10,
                  timeSlotModel: widget.slotModel,
                  onSubmit: (value) {
                    print("Clicked");
                    print("Values $value");
                  },
                );
              },
            );
          },
          child: Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              widget.slotModel.label,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
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
