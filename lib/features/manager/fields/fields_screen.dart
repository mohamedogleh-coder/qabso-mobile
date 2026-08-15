import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:qabso_mobile/features/manager/fields/add_new_field_screen.dart';
import 'package:qabso_mobile/features/manager/fields/field_card_widget.dart';
import 'package:qabso_mobile/features/manager/fields/field_model.dart';
import 'package:qabso_mobile/features/manager/fields/field_notifier_provider.dart';
import 'package:qabso_mobile/utill/app_constants.dart';
import 'package:qabso_mobile/utill/error_widget.dart';
import 'package:qabso_mobile/utill/loading_widget.dart';

class FieldsScreen extends ConsumerStatefulWidget {
  const FieldsScreen({super.key});

  @override
  ConsumerState<FieldsScreen> createState() => _FieldsScreenState();
}

class _FieldsScreenState extends ConsumerState<FieldsScreen> {
  int expandedFieldId = 0;

  void _openEditor() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddNewFieldScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fieldsAsync = ref.watch(fieldNotifierProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text("Fields"),
        actions: [
          if (!fieldsAsync.isLoading && fieldsAsync.hasValue)
            TextButton.icon(
              onPressed: _openEditor,
              icon: Icon(Symbols.add),
              label: Text("Add new field"),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
        child: fieldsAsync.when(
          skipLoadingOnRefresh: false,
          data: (fields) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: _buildNotice(fields),
              ),
              Expanded(
                child: fields.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: () async =>
                            ref.read(fieldNotifierProvider.notifier).refresh(),
                        child: ListView.builder(
                          itemCount: fields.length,
                          itemBuilder: (context, index) =>
                              FieldCardWidget(model: fields[index]),
                        ),
                      ),
              ),
            ],
          ),
          error: (error, stackTrace) => ErrorRetryWidget(
            errorMessage: error.toString(),
            onRetry: () => ref.read(fieldNotifierProvider.notifier).refresh(),
          ),
          loading: () => LoadingWidget(),
        ),
      ),
    );
  }

  /// One notice at a time: the warning takes the header's place while no field
  /// can be booked, and hands it back once one is open again.
  Widget _buildNotice(List<FieldModel> fields) {
    final hasNoBookableField = fields.every((field) => !field.allowBooking);

    return AnimatedSwitcher(
      duration: AppConstants.animationDuration,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SizeTransition(
          sizeFactor: animation,
          axisAlignment: -1,
          child: child,
        ),
      ),
      child: hasNoBookableField
          ? _buildNoBookableFieldWarning(
              fields.isEmpty,
              key: ValueKey('warning-${fields.isEmpty}'),
            )
          : _buildHeader(key: const ValueKey('header')),
    );
  }

  /// Says what a field is and what it carries.
  Widget _buildHeader({Key? key}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: key,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Color.alphaBlend(
          colorScheme.primary.withValues(alpha: 0.10),
          colorScheme.surface,
        ),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Symbols.grass,
              fill: 1,
              size: 30,
              color: colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Fields", style: theme.textTheme.headlineLarge),
                const SizedBox(height: 6),
                Text(
                  "Kuwani waa garoomada macaamiishu bookiyaan. Mid walba "
                  "wuxuu leeyahay tirada ciyaartoyda iyo qiimaha halkii qof.",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A stadium with no field, or with every field closed to booking, has
  /// nothing a customer can take.
  Widget _buildNoBookableFieldWarning(bool hasNoFields, {Key? key}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: key,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Color.alphaBlend(
          colorScheme.error.withValues(alpha: 0.10),
          colorScheme.surface,
        ),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Symbols.warning, fill: 1, size: 22, color: colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Booking lagama sameyn karo garoonkaaga",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.error,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasNoFields
                      ? "Weli garoon lama diiwaan gelin. Ku dar mid si "
                            "macaamiishu u bookiyaan."
                      : "Dhammaan garoomadaadu way ka xidhan yihiin booking-la. "
                            "Ugu yaraan mid fur.",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Symbols.grass, size: 64, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text("Stadium has no fields", style: theme.textTheme.bodyLarge),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _openEditor,
            icon: const Icon(Symbols.add),
            label: const Text("Add new field"),
          ),
        ],
      ),
    );
  }
}
