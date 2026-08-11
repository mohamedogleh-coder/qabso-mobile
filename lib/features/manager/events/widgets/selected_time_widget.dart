import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../utill/app_date_util.dart';
import '../time_slots_model.dart';

class SelectedTimeWidget extends StatelessWidget {
  final TimeSlotModel selectedModel;

  const SelectedTimeWidget({super.key, required this.selectedModel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: .25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Symbols.schedule,
              size: 25,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Selected Time", style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  selectedModel.label,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppDateUtil.formatReadableDate(selectedModel.startTime),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
