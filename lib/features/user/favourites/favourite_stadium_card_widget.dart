import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../utill/app_dailogs.dart';
import '../../../utill/current_position_provider.dart';
import '../../manager/stadium/stadium_model.dart';
import 'favourite_notifier_provider.dart';

/// One saved stadium, with the heart that takes it off the list.
class FavouriteStadiumCardWidget extends ConsumerStatefulWidget {
  const FavouriteStadiumCardWidget({super.key, required this.stadium});

  final StadiumModel stadium;

  @override
  ConsumerState<FavouriteStadiumCardWidget> createState() =>
      _FavouriteStadiumCardWidgetState();
}

class _FavouriteStadiumCardWidgetState
    extends ConsumerState<FavouriteStadiumCardWidget> {
  bool _isRemoving = false;

  Future<void> _remove() async {
    final stadiumId = widget.stadium.stadiumId;
    if (stadiumId == null || _isRemoving) return;

    setState(() => _isRemoving = true);

    try {
      await ref
          .read(favouriteNotifierProvider.notifier)
          .removeFavourite(stadiumId);
    } catch (error) {
      if (!mounted) return;

      showErrorSnackBar(context: context, message: error.toString());
    } finally {
      if (mounted) setState(() => _isRemoving = false);
    }
  }

  bool get _hasLocation =>
      widget.stadium.latitude != null && widget.stadium.longitude != null;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const Divider(height: 20),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildFactsRow(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            Symbols.stadium,
            fill: 1,
            size: 26,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            widget.stadium.stadiumName,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        _buildRemoveButton(colorScheme),
      ],
    );
  }

  Widget _buildRemoveButton(ColorScheme colorScheme) {
    if (_isRemoving) {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return IconButton(
      onPressed: _remove,
      tooltip: "Remove from favourites",
      icon: Icon(Symbols.favorite, fill: 1, color: colorScheme.error),
    );
  }

  String? get _distance {
    final stadium = widget.stadium;
    final position = ref.watch(currentPositionProvider).value;

    if (position == null || !_hasLocation) return null;

    final metres = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      stadium.latitude!,
      stadium.longitude!,
    );

    return "${(metres / 1000).toStringAsFixed(1)} km";
  }

  Widget _buildFactsRow() {
    final stadium = widget.stadium;
    final distance = _distance;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildFact(
          icon: Symbols.timer,
          text: stadium.extraTime == 0
              ? "No extra time"
              : "${stadium.extraTime} min extra",
        ),
        _buildDot(),
        _buildFact(
          icon: Symbols.sliders,
          text: stadium.allowHalfBooking ? "Half booking" : "Whole slot only",
        ),
        if (_hasLocation) ...[
          _buildDot(),
          _buildFact(
            icon: Symbols.location_on,
            text: distance ?? "On map",
            onTap: () => showNotImplementedDialog(context: context),
          ),
        ],
      ],
    );
  }

  Widget _buildDot() {
    final theme = Theme.of(context);

    return Text(
      "·",
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.outlineVariant,
      ),
    );
  }

  Widget _buildFact({
    required IconData icon,
    required String text,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, fill: 1, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
