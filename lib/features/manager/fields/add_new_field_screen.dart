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
  bool isSubmitting = false;
  List<File> _pickedImageFiles = [];
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
    }
  }

  bool get isChanged => widget.fieldModel != currenField;

  /// Validates the form and saves [currenField] (create or update,
  /// mirroring the stadium settings screen's flow). On a successful
  /// create, any newly picked photos are then uploaded — never before the
  /// field (and its id) exists. Reports the combined outcome and — on
  /// success — leaves the screen if there's somewhere to go back to.
  /// Guards against double taps and unsafe `context` use across the
  /// awaited calls.
  Future<void> _handleSubmit() async {
    if (isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => isSubmitting = true);

    try {
      final saved = isUpdate
          ? await ref
                .read(fieldNotifierProvider.notifier)
                .updateField(currenField)
          : await ref
                .read(fieldNotifierProvider.notifier)
                .createField(currenField);

      final imagesUploadedOk = await _uploadPickedImagesIfNeeded(saved);

      if (!mounted) return;
      setState(() {
        isSubmitting = false;
        currenField = saved;
      });

      if (imagesUploadedOk) {
        showSuccessSnackBar(
          context: context,
          message: isUpdate ? "Field updated." : "Field registered.",
        );
      } else {
        showErrorSnackBar(
          context: context,
          message: "Field saved, but some images failed to upload.",
        );
      }

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

  /// Uploads any newly picked, not-yet-uploaded photos for a field that was
  /// just created. Only ever runs after [saved] (and therefore its field
  /// id) exists, and only for a brand new field — this screen doesn't yet
  /// support attaching new photos when updating an existing one. Returns
  /// `false` (rather than throwing) on failure, so a failed upload can't
  /// undo the field save that already succeeded or leave [isSubmitting]
  /// stuck.
  Future<bool> _uploadPickedImagesIfNeeded(FieldModel saved) async {
    if (isUpdate || _pickedImageFiles.isEmpty) return true;

    final stadiumId = ref.read(stadiumNotifierProvider).value?.stadiumId;
    if (stadiumId == null || saved.id == null) return true;

    try {
      await FieldRepository.uploadFieldImages(
        stadiumId: stadiumId,
        fieldId: saved.id!,
        files: _pickedImageFiles,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Add new field"),
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
          maxImages: 6,
          networkImages: currenField.fieldImages,
          onFilesChanged: (files) => _pickedImageFiles = files,
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
