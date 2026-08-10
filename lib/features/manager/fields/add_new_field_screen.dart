import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/features/manager/fields/field_model.dart';
import 'package:qabso_mobile/features/manager/fields/field_notifier_provider.dart';
import 'package:qabso_mobile/features/manager/fields/field_repository.dart';
import 'package:qabso_mobile/utill/app_constants.dart';

import '../../../utill/app_dailogs.dart';
import '../../../utill/app_input_text_widget.dart';
import '../../../utill/image_picker_widget.dart';
import '../stadium/stadium_notifier_provider.dart';

class AddNewFieldScreen extends ConsumerStatefulWidget {
  final FieldModel? fieldModel;

  const AddNewFieldScreen({super.key, this.fieldModel});

  @override
  ConsumerState<AddNewFieldScreen> createState() => _AddNewFieldScreenState();
}

class _AddNewFieldScreenState extends ConsumerState<AddNewFieldScreen> {
  late FieldModel currenField;
  late bool isUpdate;

  /// The field exactly as it is currently persisted, or `null` while
  /// creating one that doesn't exist yet. Tracked separately from
  /// `widget.fieldModel` because this screen can persist changes without
  /// leaving (deleting an image), after which the saved baseline moves but
  /// the widget's original argument doesn't.
  FieldModel? _savedField;

  bool isSubmitting = false;
  List<File> _pickedImageFiles = [];

  /// Rebuilt after images are uploaded so the picker drops the local
  /// previews of files that are now network images, instead of showing each
  /// of them twice.
  Key _imagePickerKey = UniqueKey();

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.fieldModel == null) {
      isUpdate = false;
      currenField = FieldModel(
        cost: 0.0,
        capacity: AppConstants.minAppCapacity,
        allowBooking: true,
      );
    } else {
      isUpdate = true;
      currenField = widget.fieldModel!;
      _savedField = widget.fieldModel;
    }
  }

  /// Whether there's anything left to submit: either the form's values have
  /// moved away from what's saved, or photos have been picked that aren't
  /// uploaded yet (which is on its own enough to enable "Apply changes" on
  /// an otherwise untouched field).
  bool get isChanged =>
      _savedField != currenField || _pickedImageFiles.isNotEmpty;

  /// Validates the form and saves [currenField] (create or update,
  /// mirroring the stadium settings screen's flow). Once saved, any newly
  /// picked photos are uploaded — never before the field (and its id)
  /// exists. Reports the combined outcome and — on success — leaves the
  /// screen if there's somewhere to go back to. Guards against double taps
  /// and unsafe `context` use across the awaited calls.
  Future<void> _handleSubmit() async {
    if (isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Captured up front: [isUpdate] flips to true once the save lands, so
    // it can no longer tell us which of the two this submission was.
    final wasUpdate = isUpdate;

    setState(() => isSubmitting = true);

    try {
      final saved = wasUpdate
          ? await ref
                .read(fieldNotifierProvider.notifier)
                .updateField(currenField)
          : await ref
                .read(fieldNotifierProvider.notifier)
                .createField(currenField);

      final uploadResult = await _uploadPickedImagesIfNeeded(saved);

      if (!mounted) return;
      setState(() {
        isSubmitting = false;
        currenField = uploadResult.model;
        _savedField = uploadResult.model;
        // The field now exists, so this screen is editing it from here on —
        // without this, retrying after a failed image upload would run
        // `createField` a second time and duplicate the field.
        isUpdate = true;
        if (uploadResult.imagesOk) {
          _pickedImageFiles = [];
          _imagePickerKey = UniqueKey();
        }
      });

      // A failed upload keeps the screen open: the field itself is saved, but
      // the picked files only exist here, so popping would throw away the
      // user's only chance to retry them.
      if (!uploadResult.imagesOk) {
        showErrorSnackBar(
          context: context,
          message: "Field saved, but some images failed to upload.",
        );
        return;
      }

      showSuccessSnackBar(
        context: context,
        message: wasUpdate ? "Field updated." : "Field registered.",
      );

      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => isSubmitting = false);
      showErrorSnackBar(context: context, message: e.toString());
    }
  }

  /// Uploads the newly picked, not-yet-uploaded photos for [saved]. Only
  /// ever runs after [saved] (and therefore its field id) exists, for both a
  /// field that was just created and one that was just updated.
  ///
  /// Only [_pickedImageFiles] is uploaded — images already on the field are
  /// left untouched in storage and in `field_images`, never re-uploaded or
  /// duplicated. The freshly uploaded URLs are *appended* to
  /// `saved.fieldImages`, which on an update still carries the field's
  /// existing images (and on a create is empty), so the same merge covers
  /// both modes.
  ///
  /// On success, returns [saved] with that merged list — public URLs, from
  /// [FieldRepository.uploadFieldImages], which itself only ever persists
  /// storage paths, never URLs — and also patches the field list's in-memory
  /// state so it reflects them without a re-fetch. On failure, returns
  /// [saved] unchanged with `imagesOk: false` — a failed upload can't undo
  /// the field save that already succeeded or leave [isSubmitting] stuck.
  Future<({FieldModel model, bool imagesOk})> _uploadPickedImagesIfNeeded(
    FieldModel saved,
  ) async {
    if (_pickedImageFiles.isEmpty) {
      return (model: saved, imagesOk: true);
    }

    final stadiumId = ref.read(stadiumNotifierProvider).value?.stadiumId;
    if (stadiumId == null || saved.id == null) {
      return (model: saved, imagesOk: false);
    }

    try {
      final newImageUrls = await FieldRepository.uploadFieldImages(
        stadiumId: stadiumId,
        fieldId: saved.id!,
        files: _pickedImageFiles,
      );
      final allImageUrls = [...saved.fieldImages, ...newImageUrls];

      ref
          .read(fieldNotifierProvider.notifier)
          .setFieldImages(saved.id!, allImageUrls);
      return (model: saved.copyWith(fieldImages: allImageUrls), imagesOk: true);
    } catch (_) {
      return (model: saved, imagesOk: false);
    }
  }

  /// Removes an already-uploaded image — its `field_images` row and its
  /// storage file — then drops it from this screen's field and from the
  /// field list's in-memory state, so it disappears everywhere immediately.
  ///
  /// The deletion is persisted on its own, without waiting for "Apply
  /// changes", so [_savedField] moves with it: the removed image must not
  /// come back as a pending edit. Errors are rethrown for
  /// [ImagePickerWidget] to surface inline, and leave the image in place —
  /// the grid only drops a tile once this completes.
  Future<void> _deleteNetworkImage(String url) async {
    final fieldId = currenField.id;
    if (fieldId == null) {
      throw StateError('Cannot delete an image of an unsaved field.');
    }
    if (isSubmitting) {
      throw StateError('Cannot delete an image while the field is saving.');
    }

    await FieldRepository.deleteFieldImage(fieldId: fieldId, imageUrl: url);

    final remaining = currenField.fieldImages
        .where((image) => image != url)
        .toList();

    ref.read(fieldNotifierProvider.notifier).setFieldImages(fieldId, remaining);

    if (!mounted) return;
    setState(() {
      currenField = currenField.copyWith(fieldImages: remaining);
      _savedField = _savedField?.copyWith(fieldImages: remaining);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isUpdate ? "Update Field" : "Add new field"),
        actions: [
          TextButton.icon(
            onPressed: isChanged && !isSubmitting ? _handleSubmit : null,
            label: Text(isUpdate ? "Apply changes" : "Register"),
            icon: isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Symbols.check),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 8),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                AppInputTextWidget(
                  helperText: "Qiimaha halkii qof laga rabo",
                  label: "Geli qiimaha halki qof",
                  prefixIcon: Symbols.attach_money,
                  value: currenField.cost.toString(),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (v) {
                    final cost = double.tryParse(v);
                    if (cost == null) return;
                    setState(() {
                      currenField = currenField.copyWith(cost: cost);
                    });
                  },
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return "Fadlan geli qiimaha garoonka";
                    }
                    final moneyRegex = RegExp(r'^\d+(\.\d{1,2})?$');
                    if (!moneyRegex.hasMatch(v.trim())) {
                      return "Fadlan geli qiime sax ah";
                    }
                    if (double.parse(v) <= 0) {
                      return "Qiimuhu waa inuu ka badan yahy 0";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _buildCapacity(),
                const SizedBox(height: 12),
                _buildAllowBooking(),
                const SizedBox(height: 12),
                _buildImagePicker(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ImagePickerWidget(
          key: _imagePickerKey,
          maxImages: 4,
          onDeleteNetworkImage: _deleteNetworkImage,
          networkImages: currenField.fieldImages,
          onFilesChanged: (files) => setState(() => _pickedImageFiles = files),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8),
          child: Text(
            "Ku dar sawirda garoonka aad diwan gelinayso tan waxay ka caawinaysaa macamisha inay arki karaan garoonka",
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildCapacity() {
    return Column(
      crossAxisAlignment: .start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12),
            child: Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Symbols.group,
                      fill: 1,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text("Capacity"),
                  ],
                ),
                Row(
                  mainAxisAlignment: .spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: .spaceBetween,
                      children: [
                        IconButton(
                          onPressed:
                              currenField.capacity <=
                                  AppConstants.minAppCapacity
                              ? null
                              : () {
                                  setState(() {
                                    currenField = currenField.copyWith(
                                      capacity: currenField.capacity - 1,
                                    );
                                  });
                                },
                          icon: Icon(Symbols.remove),
                        ),
                        const SizedBox(width: 8),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '${currenField.capacity}',
                                style: Theme.of(context).textTheme.bodyMedium!
                                    .copyWith(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: " Players",
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed:
                              currenField.capacity >=
                                  AppConstants.maxAppCapacity
                              ? null
                              : () {
                                  setState(() {
                                    currenField = currenField.copyWith(
                                      capacity: currenField.capacity + 1,
                                    );
                                  });
                                },
                          icon: Icon(Symbols.add),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4.0),
          child: Text(
            "Imisa ciyaartooy ayuu qaadi karaa field ku",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _buildAllowBooking() {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 12),
            child: Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Symbols.handshake,
                      fill: 1,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text("Allow Field Booking"),
                  ],
                ),
                Switch.adaptive(
                  value: currenField.allowBooking,
                  onChanged: (v) async {
                    setState(() {
                      currenField = currenField.copyWith(allowBooking: v);
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8),
          child: Text(
            "Field-kan wuxuu qaabili karaa booking ka macamiisha, ka xidh hadii aad donayso in field-kan ka dhicin booking",
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ],
    );
  }
}
