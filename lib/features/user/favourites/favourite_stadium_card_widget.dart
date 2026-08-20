import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../utill/app_dailogs.dart';
import '../../../utill/current_position_provider.dart';
import '../../manager/stadium/stadium_information_screen.dart';
import '../../manager/stadium/stadium_model.dart';
import 'favourite_notifier_provider.dart';

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

  StadiumModel get _stadium => widget.stadium;

  bool get _hasLocation =>
      _stadium.latitude != null && _stadium.longitude != null;

  Future<void> _remove() async {
    final stadiumId = _stadium.stadiumId;
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

  void _openStadium() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => StadiumInformationScreen(stadium: _stadium),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: _openStadium,
        contentPadding: const EdgeInsets.only(left: 12, right: 4),
        leading: _buildLeadingIcon(theme),
        title: _buildTitle(theme),
        subtitle: _buildSubtitle(theme),
        trailing: _buildRemoveButton(theme),
      ),
    );
  }

  Widget _buildLeadingIcon(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Symbols.stadium,
        size: 20,
        fill: 1,
        color: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildTitle(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Text(
            _stadium.stadiumName,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDistancePill(ThemeData theme, String label) {
    return InkWell(
      onTap: _hasLocation
          ? () => showNotImplementedDialog(context: context)
          : null,
      borderRadius: BorderRadius.circular(20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _hasLocation ? Symbols.map : Symbols.location_off,
            size: 14,
            fill: 1,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            _hasLocation ? label : "",
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitle(ThemeData theme) {
    return Row(
      mainAxisAlignment: .spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Symbols.sports,size: 18,),
            const SizedBox(width: 8),
            Text(
              _stadium.extraTime == 0
                  ? "No extra time"
                  : "${_stadium.extraTime} min extra",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        if (_hasLocation) _buildDistancePill(theme, _distance ?? "On map"),
      ],
    );
  }

  Widget _buildRemoveButton(ThemeData theme) {
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
      icon: Icon(Symbols.favorite, fill: 1, color: theme.colorScheme.error),
    );
  }

  String? get _distance {
    final position = ref.watch(currentPositionProvider).value;

    if (position == null || !_hasLocation) return null;

    final metres = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      _stadium.latitude!,
      _stadium.longitude!,
    );

    return "${(metres / 1000).toStringAsFixed(1)} km";
  }
}
