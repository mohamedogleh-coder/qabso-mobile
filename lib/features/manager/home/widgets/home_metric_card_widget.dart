import 'package:flutter/material.dart';

/// One number on the dashboard.
///
/// The same card at every size the grid asks for. [isWide] lays it out on one
/// line for the short bars across the bottom, where a stacked card would leave
/// most of the room empty.
class HomeMetricCardWidget extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  /// A line under the label saying what the number is made of. Left out on
  /// the smallest tiles, where there is no room for it.
  final String? note;

  final Color color;

  /// Lays the card out along one line instead of stacking it.
  final bool isWide;

  const HomeMetricCardWidget({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.note,
    required this.color,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(isWide ? 14 : 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Color.alphaBlend(
          color.withValues(alpha: 0.08),
          theme.colorScheme.surface,
        ),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: isWide ? _buildWide(theme) : _buildTall(theme),
    );
  }

  /// Icon on top, the number filling the middle, the name at the foot.
  Widget _buildTall(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildIcon(),
        const Spacer(),
        _buildValue(theme, theme.textTheme.displaySmall),
        const SizedBox(height: 2),
        _buildLabel(theme),
        if (note != null) ...[const SizedBox(height: 2), _buildNote(theme)],
      ],
    );
  }

  /// Icon, name and number side by side.
  Widget _buildWide(ThemeData theme) {
    return Row(
      children: [
        _buildIcon(),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLabel(theme),
              if (note != null) ...[
                const SizedBox(height: 2),
                _buildNote(theme),
              ],
            ],
          ),
        ),
        const SizedBox(width: 12),
        _buildValue(theme, theme.textTheme.headlineLarge),
      ],
    );
  }

  Widget _buildIcon() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: 20, fill: 1, color: color),
    );
  }

  /// Shrinks rather than overflows: a number is never cut off, however long
  /// the money gets.
  Widget _buildValue(ThemeData theme, TextStyle? style) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        value,
        maxLines: 1,
        style: style?.copyWith(fontWeight: FontWeight.bold, color: color),
      ),
    );
  }

  Widget _buildLabel(ThemeData theme) {
    return Text(
      label,
      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildNote(ThemeData theme) {
    return Text(
      note!,
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
