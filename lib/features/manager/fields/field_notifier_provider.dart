import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qabso_mobile/features/manager/fields/field_model.dart';
import 'package:qabso_mobile/features/manager/fields/field_repository.dart';

import '../stadium/stadium_notifier_provider.dart';

final fieldNotifierProvider =
    AsyncNotifierProvider<FieldNotifierProvider, List<FieldModel>>(
      FieldNotifierProvider.new,
    );

class FieldNotifierProvider extends AsyncNotifier<List<FieldModel>> {
  @override
  FutureOr<List<FieldModel>> build() async {
    final stadium = await ref.watch(stadiumNotifierProvider.future);

    if (stadium?.stadiumId == null) return const [];

    return FieldRepository.getFields(stadiumId: stadium!.stadiumId!);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();

    final stadiumId = ref.read(stadiumNotifierProvider).value?.stadiumId;
    if (stadiumId == null) {
      state = const AsyncData([]);
      return;
    }

    state = await AsyncValue.guard(
      () => FieldRepository.getFields(stadiumId: stadiumId),
    );
  }

  /// Creates a field for the current manager's stadium, appends it to state
  /// directly on success, and returns it — no re-fetch, since the
  /// repository already returns the field as created.
  ///
  /// Deliberately does not set `state = AsyncLoading()` first: the caller
  /// (the field form) shows its own inline submit spinner, and broadcasting
  /// a loading state here would blank out anything else watching this
  /// provider for the duration of the call.
  ///
  /// On failure this throws rather than writing `AsyncError` to [state]:
  /// unlike the stadium notifier's single value, this provider's state is
  /// the *whole list* of fields, and a failed submission for one new field
  /// shouldn't blank out a list that was loaded and displaying fine. The
  /// caller (the form) is expected to catch this and show its own error.
  Future<FieldModel> createField(FieldModel model) async {
    final stadiumId = ref.read(stadiumNotifierProvider).value?.stadiumId;
    if (stadiumId == null) {
      throw StateError('Cannot create a field: no stadium yet.');
    }

    final created = await FieldRepository.createField(
      stadiumId: stadiumId,
      model: model,
    );
    state = AsyncData([...state.value ?? const [], created]);
    return created;
  }

  /// Updates an existing field, replaces it in state on success, and
  /// returns it — no re-fetch, for the same reason as [createField]. See
  /// [createField] for why failures throw instead of touching [state].
  Future<FieldModel> updateField(FieldModel model) async {
    final stadiumId = ref.read(stadiumNotifierProvider).value?.stadiumId;
    if (stadiumId == null) {
      throw StateError('Cannot update field: no stadium yet.');
    }

    final updated = await FieldRepository.updateField(
      stadiumId: stadiumId,
      model: model,
    );
    state = AsyncData([
      for (final field in state.value ?? const <FieldModel>[])
        if (field.id == updated.id) updated else field,
    ]);
    return updated;
  }

  /// Patches [fieldId]'s entry in state with [imageUrls] — purely local, no
  /// DB round trip. Called by the field form right after it has already
  /// persisted an image change (uploading new photos, or deleting an
  /// existing one), passing the field's full resulting image list, so the
  /// list reflects it immediately instead of waiting for the next
  /// [refresh].
  void setFieldImages(int fieldId, List<String> imageUrls) {
    final fields = state.value;
    if (fields == null) return;

    state = AsyncData([
      for (final field in fields)
        if (field.id == fieldId)
          field.copyWith(fieldImages: imageUrls)
        else
          field,
    ]);
  }
}
