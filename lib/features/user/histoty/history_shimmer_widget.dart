import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// The shape of the booking history while it is still being read.
///
/// The blocks stand where the real ones will, so the section settles into
/// place instead of jumping when the bookings arrive. Built the same way as
/// the shimmer on the manager's home screen, so the whole app waits alike.
class HistoryShimmerWidget extends StatelessWidget {
  /// How many card blocks to draw.
  final int cards;

  const HistoryShimmerWidget({super.key, this.cards = 3});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Shimmer.fromColors(
      baseColor: theme.highlightColor.withValues(alpha: 0.5),
      highlightColor: theme.cardColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Where the section title and its count go.
          _buildBlock(theme, height: 18, width: 160, radius: 6),
          const SizedBox(height: 16),

          for (var index = 0; index < cards; index++) ...[
            _buildBlock(theme, height: 76, radius: 16),
            const SizedBox(height: 10),
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
