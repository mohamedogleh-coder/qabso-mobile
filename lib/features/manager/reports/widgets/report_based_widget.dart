import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../utill/app_date_util.dart';

class ReportBasedWidget extends StatelessWidget {
  final DateTimeRange selectedDateRange;

  const ReportBasedWidget({super.key, required this.selectedDateRange});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Row(
        children: [
          const Text("Report based on"),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Icon(
                  Symbols.calendar_month,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  _dateRangeLabel(),
                  style: theme.textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dateRangeLabel() {
    final start = AppDateUtil.formatDate(
      selectedDateRange.start,
      pattern: 'dd MMM yyyy',
    );
    final end = AppDateUtil.formatDate(
      selectedDateRange.end,
      pattern: 'dd MMM yyyy',
    );

    return start == end
        ? (start ==
                  AppDateUtil.formatDate(DateTime.now(), pattern: 'dd MMM yyyy')
              ? "Today"
              : start)
        : "$start  -  $end";
  }
}
