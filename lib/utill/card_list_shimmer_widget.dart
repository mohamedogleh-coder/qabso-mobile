import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// The shape of a list of cards while it is still being read.
///
/// The blocks stand where the real cards will, so a list settles into place
/// instead of jumping when its rows arrive. Built the same way as the shimmer
/// on the manager's home screen, so the whole app waits alike.
class CardListShimmerWidget extends StatelessWidget {
  /// How many card blocks to draw.
  final int cards;

  /// Draws a short block above the cards, where a section title goes.
  final bool showHeader;

  const CardListShimmerWidget({
    super.key,
    this.cards = 3,
    this.showHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Shimmer.fromColors(
      baseColor: theme.hintColor.withValues(alpha: 0.5),
      highlightColor: theme.cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            _buildBlock(theme, height: 18, width: 160, radius: 6),
            const SizedBox(height: 16),
          ],
          for (var index = 0; index < cards; index++) ...[
            _buildBlock(theme, height: 68, radius: 12),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildBlock(
    ThemeData theme, {
    required double height,
    required double radius,
    double? width,
  }) {
    return Container(
      height: height,
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
