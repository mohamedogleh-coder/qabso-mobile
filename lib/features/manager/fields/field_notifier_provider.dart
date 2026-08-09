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

  /// Creates a field for the current manager's stadium and appends it to
  /// state directly — no re-fetch, since the repository already returns
  /// the field as created.
  ///
  /// Deliberately does not set `state = AsyncLoading()` first: the caller
  /// (the field form) shows its own inline submit spinner, and broadcasting
  /// a loading state here would blank out anything else watching this
  /// provider for the duration of the call.
  Future<void> createField(FieldModel model) async {
    final stadiumId = ref.read(stadiumNotifierProvider).value?.stadiumId;
    if (stadiumId == null) {
      state = AsyncError(
        StateError('Cannot create a field: no stadium yet.'),
        StackTrace.current,
      );
      return;
    }

    state = await AsyncValue.guard(() async {
      final created = await FieldRepository.createField(
        stadiumId: stadiumId,
        model: model,
      );
      return [...state.value ?? const [], created];
    });
  }

  /// Updates an existing field and replaces it in state directly — no
  /// re-fetch, for the same reason as [createField].
  Future<void> updateField(FieldModel model) async {
    final stadiumId = ref.read(stadiumNotifierProvider).value?.stadiumId;
    if (stadiumId == null) {
      state = AsyncError(
        StateError('Cannot update field: no stadium yet.'),
        StackTrace.current,
      );
      return;
    }

    state = await AsyncValue.guard(() async {
      final updated = await FieldRepository.updateField(
        stadiumId: stadiumId,
        model: model,
      );
      return [
        for (final field in state.value ?? const <FieldModel>[])
          if (field.id == updated.id) updated else field,
      ];
    });
  }
}
