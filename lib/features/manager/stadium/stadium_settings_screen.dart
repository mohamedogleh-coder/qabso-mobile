import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/features/manager/stadium/stadium_model.dart';
import 'package:qabso_mobile/utill/app_constants.dart';

import '../../../utill/app_dailogs.dart';
import '../../../utill/app_input_text_widget.dart';
import '../../../utill/app_utility_service.dart';
import 'stadium_notifier_provider.dart';

class StadiumSettingsScreen extends ConsumerStatefulWidget {
  final StadiumModel? stadiumModel;

  const StadiumSettingsScreen({super.key, this.stadiumModel});

  @override
  ConsumerState<StadiumSettingsScreen> createState() =>
      _StadiumSettingsScreenState();
}

class _StadiumSettingsScreenState extends ConsumerState<StadiumSettingsScreen> {
  late StadiumModel currentStadium;
  late bool isUpdate;
  bool isPickingLocation = false;
  bool isSubmitting = false;

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.stadiumModel == null) {
      isUpdate = false;
      currentStadium = StadiumModel(
        stadiumName: "",
        extraTime: AppConstants.minAppCapacity,
        longitude: null,
        latitude: null,
        allowHalfBooking: false,
      );
    } else {
      isUpdate = true;
      currentStadium = widget.stadiumModel!;
    }
  }

  bool get isChanged => widget.stadiumModel != currentStadium;

  bool get getLocation =>
      currentStadium.latitude != null && currentStadium.longitude != null;

  Future<void> _handleLocationToggle(bool enable) async {
    if (!enable) {
      setState(() {
        currentStadium = currentStadium.copyWith(
          latitude: () => null,
          longitude: () => null,
        );
      });
      return;
    }

    setState(() => isPickingLocation = true);

    try {
      final position = await AppUtilityService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        currentStadium = currentStadium.copyWith(
          latitude: () => position.latitude,
          longitude: () => position.longitude,
        );
      });
      showSuccessSnackBar(context: context, message: "Location added.");
    } on LocationServiceDisabledException {
      if (!mounted) return;
      await showAppErrorDialog(
        context: context,
        title: "Location disabled",
        message: "Fadlan fur location-ka telefoonka.",
        buttonText: "Go to settings",
        onTap: () async {
          Navigator.of(context).pop();
          await AppUtilityService.openLocationServiceSettings();
        },
      );
    } on LocationPermissionDeniedException {
      if (!mounted) return;
      await showAppErrorDialog(
        context: context,
        title: "Permission denied",
        message:
            "Fadlan u ogolow ${AppConstants.appName} inuu isticmaalo location.",
        buttonText: "Go to settings",
        onTap: () async {
          Navigator.of(context).pop();
          await AppUtilityService.openAppSettings();
        },
      );
    } on LocationPermissionPermanentlyDeniedException {
      if (!mounted) return;
      await showAppErrorDialog(
        context: context,
        title: "Permission permanently denied",
        message:
            "Location permission-ka waa laga xidhay ${AppConstants.appName}. Ka fur settings.",
        buttonText: "Go to settings",
        onTap: () async {
          Navigator.of(context).pop();
          await AppUtilityService.openAppSettings();
        },
      );
    } catch (_) {
      if (!mounted) return;
      showErrorSnackBar(
        context: context,
        message: "Could not get your location. Please try again.",
      );
    } finally {
      if (mounted) setState(() => isPickingLocation = false);
    }
  }

  Future<void> _handleSubmit() async {
    if (isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => isSubmitting = true);

    await ref
        .read(stadiumNotifierProvider.notifier)
        .saveStadium(currentStadium);

    if (!mounted) return;
    setState(() => isSubmitting = false);

    final result = ref.read(stadiumNotifierProvider);
    if (result.hasError) {
      showErrorSnackBar(context: context, message: result.error.toString());
      return;
    }

    showSuccessSnackBar(
      context: context,
      message: isUpdate ? "Stadium updated." : "Stadium registered.",
    );

    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
        actions: [
          TextButton.icon(
            onPressed: isChanged && !isSubmitting ? _handleSubmit : null,
            icon: isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(Symbols.check),
            label: Text(isUpdate ? "Apply changes" : "Register"),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 8),
            child: Column(
              children: [
                AppInputTextWidget(
                  prefixIcon: Symbols.stadium,
                  label: "Stadium name",
                  value: currentStadium.stadiumName,
                  onChanged: (v) {
                    setState(() {
                      currentStadium = currentStadium.copyWith(stadiumName: v);
                    });
                  },
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return "Fadlan geli magaca garoonka";
                    }
                    return null;
                  },
                  maxLength: 100,
                ),
                const SizedBox(height: 12),
                _buildExtraTime(),
                const SizedBox(height: 12),
                _buildAllowHalfBooking(),
                const SizedBox(height: 12),
                _buildLocation(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExtraTime() {
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
                      Symbols.sports,
                      fill: 1,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text("Extra time"),
                  ],
                ),
                Row(
                  mainAxisAlignment: .spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: .spaceBetween,
                      children: [
                        IconButton(
                          onPressed: currentStadium.extraTime <= 0
                              ? null
                              : () {
                                  setState(() {
                                    currentStadium = currentStadium.copyWith(
                                      extraTime: currentStadium.extraTime - 1,
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
                                text: '${currentStadium.extraTime}',
                                style: Theme.of(context).textTheme.bodyMedium!
                                    .copyWith(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: currentStadium.extraTime == 0
                                    ? ""
                                    : " Minutes",
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: currentStadium.extraTime >= 8
                              ? null
                              : () {
                                  setState(() {
                                    currentStadium = currentStadium.copyWith(
                                      extraTime: currentStadium.extraTime + 1,
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
            "Imisa minutes ayaa luugu dari karaa macamiisha markay dhamaystan ciyartooda",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }

  Widget _buildAllowHalfBooking() {
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
                      Symbols.sliders,
                      fill: 1,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text("Allow Half Booking"),
                  ],
                ),
                Switch.adaptive(
                  value: currentStadium.allowHalfBooking,
                  onChanged: (v) async {
                    setState(() {
                      currentStadium = currentStadium.copyWith(
                        allowHalfBooking: v,
                      );
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
            "Ma ogoshahay in qayb events ka mida macamiishu lacagteeda bixin karaan (half booking)",
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildLocation() {
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
                      Symbols.location_on,
                      fill: 1,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Text("Enable Location"),
                  ],
                ),
                isPickingLocation
                    ? const Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 12.0,
                          horizontal: 8,
                        ),
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                      )
                    : Switch.adaptive(
                        value: getLocation,
                        onChanged: _handleLocationToggle,
                      ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8),
          child: Text(
            "Usheeg macamisha location ka garoonkaga. hadii aad garoonka dhex jogin iminka wad iska dhafi kartaa",
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
      ],
    );
  }
}
