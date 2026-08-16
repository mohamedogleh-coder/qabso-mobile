import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/features/user/explore/models/explored_stadium_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../utill/app_dailogs.dart';
import '../../../../utill/app_date_util.dart';
import '../../../../utill/current_position_provider.dart';
import '../../../../utill/error_widget.dart';
import '../../../../utill/loading_widget.dart';
import '../../../manager/events/models/booking_context_model.dart';
import '../../../manager/events/time_slot_card_widget.dart';
import '../../favourites/favourite_notifier_provider.dart';
import '../providers/explore_stadiums_filter_notifier.dart';
import '../providers/explore_time_slots_provider.dart';

/// Everything the customer needs to know about one stadium the search found:
/// the stadium, the field that matched their group, that field's pictures and
/// the times it is free on the searched day.
class ExploreSingleStadiumInfoWidget extends ConsumerStatefulWidget {
  final ExploredStadiumModel exploredStadiumModel;

  const ExploreSingleStadiumInfoWidget({
    super.key,
    required this.exploredStadiumModel,
  });

  @override
  ConsumerState<ExploreSingleStadiumInfoWidget> createState() =>
      _ExploreSingleStadiumInfoWidgetState();
}

class _ExploreSingleStadiumInfoWidgetState
    extends ConsumerState<ExploreSingleStadiumInfoWidget> {
  bool _isSaving = false;

  /// What the slot cards need to price and book this field. It is the same
  /// set of facts a manager hands them, so the same cards serve both.
  late final BookingContextModel _booking;

  ExploredStadiumModel get _stadium => widget.exploredStadiumModel;

  @override
  void initState() {
    super.initState();

    _booking = BookingContextModel(
      stadiumId: _stadium.stadiumId!,
      fieldId: _stadium.fieldId,
      capacity: _stadium.capacity,
      cost: _stadium.cost,
      allowHalfBooking: _stadium.allowHalfBooking,
    );
  }

  /// The saved list is the truth once it has loaded. Before that the search's
  /// own answer is all there is.
  bool get _isFavourite {
    final stadiumId = _stadium.stadiumId;
    if (stadiumId == null) return false;

    final favourites = ref.watch(favouriteNotifierProvider);
    if (favourites.value == null) return _stadium.fav;

    return ref.read(favouriteNotifierProvider.notifier).isFavourite(stadiumId);
  }

  /// Saves the stadium, or takes it off the saved list. The work is left to
  /// the favourites provider, which is what the favourites screen uses too.
  Future<void> _toggleFavourite() async {
    final stadiumId = _stadium.stadiumId;
    if (stadiumId == null || _isSaving) return;

    final favourites = ref.read(favouriteNotifierProvider.notifier);
    final wasFavourite = _isFavourite;

    setState(() => _isSaving = true);

    try {
      if (wasFavourite) {
        await favourites.removeFavourite(stadiumId);
      } else {
        await favourites.addFavourite(_stadium);
      }
    } catch (error) {
      if (!mounted) return;

      showErrorSnackBar(
        context: context,
        message: error is PostgrestException ? error.message : error.toString(),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            _buildStadiumInfo(),
            const Divider(height: 32),
            _buildSlots(),
            const Divider(height: 32),
            _buildMatchedField(),
            const SizedBox(height: 12),
            _buildImages(),
          ],
        ),
      ),
    );
  }

  /// The stadium name and the heart, side by side.
  Widget _buildHeader() {
    final theme = Theme.of(context);
    final isFavourite = _isFavourite;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Symbols.stadium,
            color: theme.colorScheme.onPrimary,
            fill: 1,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _stadium.stadiumName,
                style: theme.textTheme.headlineLarge,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                isFavourite ? "Saved stadium" : "Not saved yet",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _isSaving ? null : _toggleFavourite,
          tooltip: isFavourite ? "Remove from favourites" : "Add to favourites",
          icon: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  Symbols.favorite,
                  fill: isFavourite ? 1 : 0,
                  color: isFavourite
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
        ),
      ],
    );
  }

  /// How far the stadium is. The search measures it itself when the customer
  /// searched from their position; otherwise it is worked out from where the
  /// phone is now. Neither one available leaves it unknown.
  String get _distance {
    final searched = _stadium.distance;
    if (searched != null) return "$searched km";

    final position = ref.watch(currentPositionProvider).value;
    final latitude = _stadium.latitude;
    final longitude = _stadium.longitude;

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

  /// What the stadium itself offers, as one strip. The facts share the width
  /// evenly, so the strip fits any phone without wrapping.
  Widget _buildStadiumInfo() {
    final stadium = _stadium;

    return _buildStatStrip([
      _buildStat(icon: Symbols.near_me, label: "Away", value: _distance),
      _buildStat(
        icon: Symbols.sports,
        label: "Extra time",
        value: stadium.extraTime == 0 ? "None" : "${stadium.extraTime} min",
      ),
      _buildStat(
        icon: Symbols.sliders,
        label: "Half booking",
        value: stadium.allowHalfBooking ? "Allowed" : "No",
      ),
    ]);
  }

  /// The one field the search picked for this group, kept apart from the
  /// stadium's own details so it is clear this is not every field.
  Widget _buildMatchedField() {
    final theme = Theme.of(context);
    final stadium = _stadium;
    final slotPrice = stadium.capacity * stadium.cost;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(
          icon: Symbols.check_circle,
          title: "The field that fits your group",
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: .3),
            ),
          ),
          child: _buildStatStrip([
            _buildStat(
              icon: Symbols.group,
              label: "Players",
              value: "${stadium.capacity}",
            ),
            _buildStat(
              icon: Symbols.payments,
              label: "Per player",
              value: "\$${stadium.cost}",
            ),
            _buildStat(
              icon: Symbols.receipt_long,
              label: "Whole slot",
              value: "\$${slotPrice.toStringAsFixed(2)}",
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildImages() {
    final images = _stadium.imageUrls;

    if (images.isEmpty) return _buildNoImages();

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: images.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) => _buildThumbnail(images[index]),
      ),
    );
  }

  Widget _buildThumbnail(String url) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => _openImage(url),
      borderRadius: BorderRadius.circular(12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url,
          width: 128,
          height: 96,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : Container(
                  width: 128,
                  height: 96,
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
            width: 128,
            height: 96,
            color: theme.colorScheme.surfaceContainerHighest,
            child: Icon(
              Symbols.broken_image,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNoImages() {
    final theme = Theme.of(context);

    return Container(
      height: 96,
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
            "This field has no pictures yet",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _openImage(String url) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(child: Image.network(url)),
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

  /// This field's slots on the day the customer searched for, drawn with the
  /// same slot cards the manager's screens use.
  Widget _buildSlots() {
    final theme = Theme.of(context);
    final searchedDate = ref
        .watch(exploredStadiumFilterNotifierProvider)
        .eventDate;
    final slotsAsync = ref.watch(exploreTimeSlotsProvider(_stadium.fieldId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(icon: Symbols.schedule, title: "Available slots"),
        const SizedBox(height: 4),
        Text(
          AppDateUtil.formatReadableDate(searchedDate),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        slotsAsync.when(
          data: (slots) => slots.isEmpty
              ? _buildNoSlots()
              : Wrap(
                  spacing: 2,
                  runSpacing: 4,
                  children: [
                    for (final slot in slots)
                      TimeSlotCardWidget(booking: _booking, slotModel: slot),
                  ],
                ),
          error: (error, stackTrace) => ErrorRetryWidget(
            errorMessage: error is PostgrestException
                ? error.message
                : error.toString(),
            onRetry: () =>
                ref.invalidate(exploreTimeSlotsProvider(_stadium.fieldId)),
          ),
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: LoadingWidget(),
          ),
        ),
      ],
    );
  }

  Widget _buildNoSlots() {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Symbols.event_busy,
            color: theme.colorScheme.onSurfaceVariant,
            size: 28,
          ),
          const SizedBox(height: 4),
          Text(
            "No slots to show",
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
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
