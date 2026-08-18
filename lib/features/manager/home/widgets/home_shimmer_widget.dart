import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// The shape of the home screen while it is still being read.
///
/// The blocks stand where the real ones will, so the screen settles into place
/// instead of jumping when the numbers arrive. Built the same way as the
/// shimmer in ManagerShell, so the whole app waits alike.
class HomeShimmerWidget extends StatelessWidget {
  const HomeShimmerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Shimmer.fromColors(
      baseColor: theme.hintColor.withValues(alpha: 0.5),
      highlightColor: theme.cardColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          // Where the stadium name and the date go.
          _buildBlock(theme, height: 20, radius: 6, width: 180),
          const SizedBox(height: 8),
          _buildBlock(theme, height: 12, radius: 6, width: 130),
          const SizedBox(height: 18),

          // Where the next game goes.
          _buildBlock(theme, height: 132, radius: 20),
          const SizedBox(height: 12),

          // The two counts, side by side and the same size.
          SizedBox(
            height: 158,
            child: Row(
              children: [
                Expanded(child: _buildBlock(theme, radius: 20)),
                const SizedBox(width: 12),
                Expanded(child: _buildBlock(theme, radius: 20)),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Where the owed bar goes.
          _buildBlock(theme, height: 74, radius: 20),
          const SizedBox(height: 12),

          // Where the free slots go.
          _buildBlock(theme, height: 132, radius: 20),
          const SizedBox(height: 20),

          // Where the countdown sits.
          Center(child: _buildBlock(theme, height: 44, radius: 30, width: 190)),
        ],
      ),
    );
  }

  Widget _buildBlock(
    ThemeData theme, {
    double? height,
    double? width,
    required double radius,
  }) {
    return Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
