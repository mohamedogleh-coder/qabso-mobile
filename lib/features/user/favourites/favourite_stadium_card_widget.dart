import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../utill/app_dailogs.dart';
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

  /// Takes the stadium off the saved list. The provider drops it from state
  /// on success, which takes this card out of the list with it, so the flag
  /// is only put back when the removal failed and the card is still here.
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

      setState(() => _isRemoving = false);
      showErrorSnackBar(context: context, message: error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final stadium = widget.stadium;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStadiumTile(colorScheme),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stadium.stadiumName,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _buildMapButton(),
                      if (stadium.allowHalfBooking)
                        _buildChip(
                          theme,
                          icon: Symbols.savings,
                          label: "Half booking",
                        ),
                      if (stadium.extraTime > 0)
                        _buildChip(
                          theme,
                          icon: Symbols.timer,
                          label: "+${stadium.extraTime} min break",
                        ),
                    ],
                  ),
                ],
              ),
            ),
            _buildRemoveButton(colorScheme),
          ],
        ),
      ),
    );
  }

  /// Stadiums carry no picture, so the card is led by the app's own mark
  /// instead, the same way a field card is.
  Widget _buildStadiumTile(ColorScheme colorScheme) {
    return Container(
      height: 56,
      width: 56,
      decoration: BoxDecoration(
        color: colorScheme.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(
        Symbols.stadium,
        fill: 1,
        size: 30,
        color: colorScheme.onPrimary,
      ),
    );
  }

  /// Where the stadium is. The map itself is not built yet, so for now the
  /// icon says so. A stadium with no point saved cannot be shown at all, so
  /// its icon is turned off.
  Widget _buildMapButton() {
    final hasLocation =
        widget.stadium.latitude != null && widget.stadium.longitude != null;

    return IconButton.filledTonal(
      onPressed: hasLocation
          ? () => showNotImplementedDialog(context: context)
          : null,
      tooltip: hasLocation ? "Show on map" : "No location saved",
      visualDensity: VisualDensity.compact,
      icon: const Icon(Symbols.location_on, fill: 1, size: 20),
    );
  }

  Widget _buildRemoveButton(ColorScheme colorScheme) {
    if (_isRemoving) {
      return const Padding(
        padding: EdgeInsets.all(12),
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

  Widget _buildChip(
    ThemeData theme, {
    required IconData icon,
    required String label,
  }) {
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
