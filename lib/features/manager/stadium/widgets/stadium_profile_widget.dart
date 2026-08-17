import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../utill/app_dailogs.dart';
import '../../../../utill/current_position_provider.dart';
import '../../../../utill/error_widget.dart';
import '../../../../utill/loading_widget.dart';
import '../models/stadium_profile_model.dart';
import '../stadium_profile_provider.dart';

/// The Profile tab of the stadium screen: what the stadium is, how many of its
/// fields are open, and the pictures of those fields.
///
/// It reads its own data from the stadium id, so the tab hands it nothing else
/// and any other screen can show it the same way.
class StadiumProfileWidget extends ConsumerStatefulWidget {
  final String stadiumId;

  const StadiumProfileWidget({super.key, required this.stadiumId});

  @override
  ConsumerState<StadiumProfileWidget> createState() =>
      _StadiumProfileWidgetState();
}

class _StadiumProfileWidgetState extends ConsumerState<StadiumProfileWidget> {
  /// Reads the stadium again. The provider is what holds the answer, so the
  /// screen and this widget always see the same one.
  void _reload() => ref.invalidate(stadiumProfileProvider(widget.stadiumId));

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(stadiumProfileProvider(widget.stadiumId));

    return profileAsync.when(
      skipLoadingOnRefresh: false,
      data: _buildProfile,
      error: (error, stackTrace) => ErrorRetryWidget(
        errorMessage: error is PostgrestException
            ? error.message
            : error.toString(),
        onRetry: _reload,
      ),
      loading: () => const LoadingWidget(),
    );
  }

  Widget _buildProfile(StadiumProfileModel profile) {
    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        await ref.read(stadiumProfileProvider(widget.stadiumId).future);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(profile),
            const SizedBox(height: 16),
            _buildStadiumInfo(profile),
            if (profile.hasLocation) ...[
              const Divider(height: 32),
              _buildLocationRow(),
            ],
            const Divider(height: 32),
            _buildPhotos(profile),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(StadiumProfileModel profile) {
    final theme = Theme.of(context);
    final open = profile.workingFields;
    return Text(
      open == 0
          ? "No fields open to booking"
          : "$open ${open == 1 ? 'field' : 'fields'} open to booking",
      style: theme.textTheme.headlineMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  String _distance(StadiumProfileModel profile) {
    final position = ref.watch(currentPositionProvider).value;
    final latitude = profile.latitude;
    final longitude = profile.longitude;

    if (position == null || latitude == null || longitude == null) {
      return "Unknown";
    }

    final metres = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      latitude,
      longitude,
    );

    return "${(metres / 1000).toStringAsFixed(1)} km";
  }

  Widget _buildStadiumInfo(StadiumProfileModel profile) {
    return _buildStatStrip([
      _buildStat(
        icon: Symbols.near_me,
        label: "Away",
        value: _distance(profile),
      ),
      _buildStat(
        icon: Symbols.sports,
        label: "Extra time",
        value: profile.extraTime == 0 ? "None" : "${profile.extraTime} min",
      ),
      _buildStat(
        icon: Symbols.sliders,
        label: "Half booking",
        value: profile.allowHalfBooking ? "Allowed" : "No",
      ),
    ]);
  }

  Widget _buildLocationRow() {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => showNotImplementedDialog(context: context),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Icon(
              Symbols.location_on,
              fill: 1,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "Open on map",
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Icon(
              Symbols.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  /// Every picture the stadium's fields have, in one grid. Each picture says
  /// which field it came from, so the grid reads as the whole place rather
  /// than a pile of photos.
  Widget _buildPhotos(StadiumProfileModel profile) {
    final images = profile.fieldImages;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          icon: Symbols.imagesmode,
          title: images.isEmpty ? "Photos" : "Photos (${images.length})",
        ),
        const SizedBox(height: 12),
        if (images.isEmpty)
          _buildNoImages()
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 4 / 3,
            ),
            itemCount: images.length,
            itemBuilder: (context, index) => _buildTile(images[index]),
          ),
      ],
    );
  }

  /// One picture with the field it belongs to written across the bottom.
  Widget _buildTile(StadiumFieldImageModel image) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => _openImage(image),
      borderRadius: BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              image.imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
              errorBuilder: (context, error, stackTrace) => Container(
                color: theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Symbols.broken_image,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),

            // A flat bar behind the label, so the writing stays readable on a
            // bright picture.
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                color: Colors.black.withValues(alpha: .55),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Text(
                  "Field #${image.fieldId} · ${image.capacity} players",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoImages() {
    final theme = Theme.of(context);

    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Symbols.imagesmode,
            color: theme.colorScheme.onSurfaceVariant,
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            "This stadium has no pictures yet",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  /// Opens one picture on its own, where it can be zoomed.
  void _openImage(StadiumFieldImageModel image) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(child: Image.network(image.imageUrl)),
            IconButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Symbols.close),
              style: IconButton.styleFrom(
                backgroundColor: Theme.of(
                  dialogContext,
                ).colorScheme.surface.withValues(alpha: .8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle({required IconData icon, required String title}) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Text(
          title,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 8),
        Icon(icon, size: 18, color: theme.colorScheme.primary),
      ],
    );
  }

  /// Lays the facts out side by side, each taking the same width, with a
  /// hairline between them.
  Widget _buildStatStrip(List<Widget> stats) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (var index = 0; index < stats.length; index++) ...[
          if (index > 0)
            Container(width: 1, height: 40, color: theme.dividerColor),
          Expanded(child: stats[index]),
        ],
      ],
    );
  }

  /// One fact: the icon on top, the answer under it, and the name of the
  /// thing at the bottom.
  Widget _buildStat({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, fill: 1, color: theme.colorScheme.primary),
        const SizedBox(height: 6),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
