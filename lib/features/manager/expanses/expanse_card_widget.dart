import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../utill/app_constants.dart';
import '../../../utill/app_date_util.dart';
import 'expanse_model.dart';

/// How each kind of expense is named and coloured, kept in one place so the
/// list, the filter chips and the cards always agree.
extension ExpanseTypeStyle on ExpanseType {
  String get label => switch (this) {
    ExpanseType.salary => "Salary",
    ExpanseType.expense => "Expense",
    // ExpanseType.other => "Other",
  };

  IconData get iconData => switch (this) {
    ExpanseType.salary => Symbols.badge,
    ExpanseType.expense => Symbols.shopping_cart,
    // ExpanseType.other => Symbols.more_horiz,
  };

  Color get color => switch (this) {
    ExpanseType.salary => AppConstants.tertiary,
    ExpanseType.expense => AppConstants.error,
    // ExpanseType.other => AppConstants.warning,
  };
}

/// One expense in the list: its kind, what it cost, and when it was paid.
///
/// A card with a description carries a chevron that opens it. Tapping the card
/// itself is what opens the actions, so the two never fight over one tap.
class ExpanseCardWidget extends StatefulWidget {
  final ExpanseModel expanse;
  final VoidCallback onTap;

  const ExpanseCardWidget({
    super.key,
    required this.expanse,
    required this.onTap,
  });

  @override
  State<ExpanseCardWidget> createState() => _ExpanseCardWidgetState();
}

class _ExpanseCardWidgetState extends State<ExpanseCardWidget> {
  bool _isOpen = false;

  bool get _hasDescription => (widget.expanse.description ?? '').isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final expanse = widget.expanse;
    final color = expanse.expanseType.color;

    return Material(
      color: Color.alphaBlend(
        color.withValues(alpha: 0.10),
        theme.colorScheme.surface,
      ),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        splashColor: color.withValues(alpha: 0.14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopRow(theme, color),
              if (_hasDescription && _isOpen) ...[
                const Divider(height: 20),
                Text(
                  expanse.description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopRow(ThemeData theme, Color color) {
    final expanse = widget.expanse;

    return Row(
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            expanse.expanseType.iconData,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                expanse.expanseType.label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                AppDateUtil.formatDate(
                  expanse.expenseDate,
                  pattern: 'dd MMM yyyy',
                ),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          "\$${expanse.expenseTotal.toStringAsFixed(2)}",
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        if (_hasDescription)
          IconButton(
            onPressed: () => setState(() => _isOpen = !_isOpen),
            tooltip: _isOpen ? "Hide details" : "Show details",
            icon: Icon(
              _isOpen ? Symbols.expand_less : Symbols.expand_more,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}
