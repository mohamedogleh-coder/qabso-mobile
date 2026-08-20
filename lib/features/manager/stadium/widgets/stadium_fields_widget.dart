import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../utill/app_constants.dart';
import '../../../../utill/error_widget.dart';
import '../../../../utill/loading_widget.dart';
import '../../events/models/booking_context_model.dart';
import '../../events/time_slots_list_widget.dart';
import '../../fields/field_model.dart';
import '../stadium_fields_provider.dart';
import '../stadium_model.dart';

/// The Fields tab of the stadium screen: every field the stadium has, and the
/// times each one is free.
///
/// The whole stadium is passed in rather than only its id, because a slot is
/// priced and booked from the stadium's half-booking rule as well as the
/// field's size and cost.
class StadiumFieldsWidget extends ConsumerStatefulWidget {
  final StadiumModel stadium;

  const StadiumFieldsWidget({super.key, required this.stadium});

  @override
  ConsumerState<StadiumFieldsWidget> createState() =>
      _StadiumFieldsWidgetState();
}

class _StadiumFieldsWidgetState extends ConsumerState<StadiumFieldsWidget>
    with AutomaticKeepAliveClientMixin {
  /// Stays alive while the stadium screen is open, so moving between the tabs
  /// never reads the fields again and an opened field stays open.
  @override
  bool get wantKeepAlive => true;

  /// Which fields have their slots showing. Held here rather than in each card
  /// so the cards stay plain widgets and the tab remembers what was opened.
  final Set<int> _openFields = {};

  String get _stadiumId => widget.stadium.stadiumId!;

  void _reload() => ref.invalidate(stadiumFieldsProvider(_stadiumId));

  void _toggleField(int fieldId) {
    setState(() {
      if (!_openFields.remove(fieldId)) _openFields.add(fieldId);
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final fieldsAsync = ref.watch(stadiumFieldsProvider(_stadiumId));

    return fieldsAsync.when(
      skipLoadingOnRefresh: false,
      data: _buildFields,
      error: (error, stackTrace) => ErrorRetryWidget(
        errorMessage: error is PostgrestException
            ? error.message
            : error.toString(),
        onRetry: _reload,
      ),
      loading: () => const LoadingWidget(),
    );
  }

  Widget _buildFields(List<FieldModel> fields) {
    return RefreshIndicator(
      onRefresh: () async {
        _reload();
        await ref.read(stadiumFieldsProvider(_stadiumId).future);
      },
      child: fields.isEmpty
          ? _buildEmpty()
          : SafeArea(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final field in fields) _buildFieldCard(field),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFieldCard(FieldModel field) {
    final theme = Theme.of(context);
    final isOpen = field.allowBooking;
    final color = isOpen ? theme.colorScheme.primary : theme.colorScheme.error;
    final fieldId = field.id;
    final isShowing = fieldId != null && _openFields.contains(fieldId);

    return Card(
      elevation: isShowing ? 1 : 0,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (field.fieldImages.isNotEmpty) _buildImageStrip(field),
            const Divider(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildFieldHeader(field, color),
            ),
            if (isOpen) ...[
              const Divider(height: 24),
              _buildSlots(field),
              if (isShowing) const Divider(height: 24),
              _buildToggle(field),
            ] else
              //Xogaa dheere card ka marka uu close yahay
              SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildImageStrip(FieldModel field) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: SizedBox(
        height: 96,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: field.fieldImages.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) =>
              _buildThumbnail(field.fieldImages[index]),
        ),
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

  Widget _buildFieldHeader(FieldModel field, Color color) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Symbols.grass,
            color: theme.colorScheme.onPrimary,
            fill: 1,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      "Field #${field.id}",
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildPrice(field),
                ],
              ),
              const SizedBox(height: 4),
              _buildFieldFacts(field, color),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPrice(FieldModel field) {
    final theme = Theme.of(context);

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '\$${field.cost}',
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          TextSpan(
            text: ' /player',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFieldFacts(FieldModel field, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildFact(
          icon: field.allowBooking ? Symbols.check_circle : Symbols.block,
          text: field.allowBooking ? "Open" : "Closed",
          color: color,
        ),
        _buildFact(icon: Symbols.group, text: "${field.capacity}"),
      ],
    );
  }

  Widget _buildFact({
    required IconData icon,
    required String text,
    Color? color,
  }) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: color ?? theme.hintColor),
        const SizedBox(width: 8),
        Text(text, style: theme.textTheme.bodySmall?.copyWith(color: color)),
      ],
    );
  }

  Widget _buildSlots(FieldModel field) {
    final fieldId = field.id;
    final isShowing = fieldId != null && _openFields.contains(fieldId);

    return AnimatedSize(
      duration: AppConstants.animationDuration,
      child: !isShowing
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TimeSlotsListWidget(
                booking: BookingContextModel(
                  stadiumId: _stadiumId,
                  stadiumName: widget.stadium.stadiumName,
                  fieldId: fieldId,
                  capacity: field.capacity,
                  cost: field.cost,
                  allowHalfBooking: widget.stadium.allowHalfBooking,
                ),
              ),
            ),
    );
  }

  Widget _buildToggle(FieldModel field) {
    final fieldId = field.id;
    final isShowing = fieldId != null && _openFields.contains(fieldId);

    return InkWell(
      onTap: fieldId == null ? null : () => _toggleField(fieldId),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isShowing ? Symbols.arrow_drop_up : Symbols.arrow_drop_down),
            const SizedBox(width: 12),
            Text(isShowing ? "Hide slots" : "Show slots"),
          ],
        ),
      ),
    );
  }

  //  Widget _buildClosedNote() {
  //   final theme = Theme.of(context);
  //
  //   return Padding(
  //     padding: const EdgeInsets.symmetric(vertical: 10),
  //     child: Row(
  //       mainAxisAlignment: MainAxisAlignment.center,
  //       children: [
  //         Icon(Symbols.block, size: 18, color: theme.colorScheme.error),
  //         const SizedBox(width: 6),
  //         Text(
  //           "Not taking bookings",
  //           style: theme.textTheme.bodyMedium?.copyWith(
  //             color: theme.colorScheme.error,
  //             fontWeight: FontWeight.bold,
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildEmpty() {
    final theme = Theme.of(context);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
          child: Column(
            children: [
              Icon(
                Symbols.grass,
                size: 56,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                "This stadium has no fields yet",
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                "There is nothing to book here until a field is added.",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ],
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
    Color? color,
  }) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 20,
          fill: 1,
          color: color ?? theme.colorScheme.primary,
        ),
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
        // const SizedBox(height: 2),
        // Text(
        //   label,
        //   style: theme.textTheme.bodySmall?.copyWith(
        //     color: theme.colorScheme.onSurfaceVariant,
        //   ),
        //   textAlign: TextAlign.center,
        //   maxLines: 1,
        //   overflow: TextOverflow.ellipsis,
        // ),
      ],
    );
  }
}
