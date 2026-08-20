import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utill/app_dailogs.dart';
import '../../utill/app_date_util.dart';
import '../../utill/app_image_picker_widget.dart';
import '../../utill/app_input_text_widget.dart';
import '../../utill/error_widget.dart';
import '../../utill/loading_widget.dart';
import 'app_user_model.dart';
import 'app_user_notifer.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  File? _pickedAvatar;
  bool _avatarRemoved = false;

  bool _isSaving = false;

  String? _loadedUserId;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _fillForm(AppUserModel user) {
    if (_loadedUserId == user.id) return;

    _loadedUserId = user.id;
    _fullNameController.text = user.fullName;
    _phoneController.text = user.phoneNumber;
  }

  bool _isChanged(AppUserModel user) {
    return _fullNameController.text.trim() != user.fullName ||
        _phoneController.text.trim() != user.phoneNumber ||
        _pickedAvatar != null ||
        _avatarRemoved;
  }

  Future<void> _save(AppUserModel user) async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final fullName = _fullNameController.text.trim();
    final phoneNumber = _phoneController.text.trim();

    setState(() => _isSaving = true);

    try {
      await ref
          .read(appUserNotifierProvider.notifier)
          .updateUserInfo(
            fullName: fullName == user.fullName ? null : fullName,
            phoneNumber: phoneNumber == user.phoneNumber ? null : phoneNumber,
            avatarFile: _pickedAvatar,
            removeAvatar: _avatarRemoved,
          );

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _pickedAvatar = null;
        _avatarRemoved = false;
      });

      showSuccessSnackBar(
        context: context,
        message: "Macluumaadkaaga waa la cusbooneysiiyay.",
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);

      await showAppErrorDialog(
        context: context,
        title: "Wax lama beddelin",
        message: e is PostgrestException ? e.message : e.toString(),
      );
    }
  }

  /// Asks first, then signs the user out. The dialog does the waiting and
  /// shows anything that goes wrong, so nothing is needed here after it.
  Future<void> _confirmLogout() async {
    await showAppConfirmationDialog(
      context: context,
      title: "Logout",
      message: "Are you sure you want to logout?",
      confirmText: "Logout",
      isDestructive: true,
      icon: Symbols.logout,
      onConfirm: () => ref.read(authRepositoryProvider).signOut(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(appUserNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("My Account"),
        titleSpacing: 20,
        actions: [
          TextButton.icon(
            onPressed: _confirmLogout,
            icon: const Icon(Symbols.logout),
            label: const Text("Logout"),
          ),
        ],
      ),
      body: SafeArea(
        child: userAsync.when(
          loading: () => const LoadingWidget(),
          error: (error, _) => ErrorRetryWidget(
            errorMessage: error.toString(),
            onRetry: () => ref.read(appUserNotifierProvider.notifier).refresh(),
          ),
          data: (user) {
            if (user == null) return _buildNoProfile();

            _fillForm(user);

            return _buildForm(user);
          },
        ),
      ),
    );
  }

  Widget _buildForm(AppUserModel user) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _buildAvatarPicker(user),
                const SizedBox(height: 20),
                _buildFullNameField(),
                const SizedBox(height: 12),
                _buildPhoneField(),
                const SizedBox(height: 16),
                _buildAccountFacts(user),
                const SizedBox(height: 24),
                _buildSaveButton(user),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarPicker(AppUserModel user) {
    final theme = Theme.of(context);

    return Column(
      children: [
        AppImagePickerWidget(
          initialImageUrl: user.profile,
          enabled: !_isSaving,
          size: 112,
          onChanged: (file) => setState(() {
            _pickedAvatar = file;
            _avatarRemoved = file == null && user.profile != null;
          }),
        ),
        const SizedBox(height: 8),
        Text(
          user.fullName,
          style: theme.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildFullNameField() {
    return AppInputTextWidget(
      controller: _fullNameController,
      label: "Magacaaga",
      prefixIcon: Symbols.person,
      enabled: !_isSaving,
      maxLength: 100,
      counterText: "",
      onChanged: (_) => setState(() {}),
      validator: (v) {
        final value = v?.trim() ?? '';
        if (value.isEmpty) return "Fadlan geli magacaaga";
        if (value.length < 3) return "Magacu waa inuu ka badan yahay 3 xaraf";
        return null;
      },
    );
  }

  Widget _buildPhoneField() {
    return AppInputTextWidget(
      controller: _phoneController,
      label: "Taleefankaaga",
      prefixIcon: Symbols.call,
      capitalization: TextCapitalization.none,
      enabled: !_isSaving,
      keyboardType: TextInputType.phone,
      maxLength: 20,
      counterText: "",
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
      onChanged: (_) => setState(() {}),
      validator: (v) {
        final value = v?.trim() ?? '';
        if (value.isEmpty) return "Fadlan geli lambarkaaga";
        if (value.length < 7) return "Lambarku waa gaaban yahay";
        return null;
      },
    );
  }

  Widget _buildAccountFacts(AppUserModel user) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Column(
        children: [
          _buildFactRow(
            icon: Symbols.badge,
            label: "Nooca akoonka",
            value: user.role.name,
          ),
          const SizedBox(height: 12),
          _buildFactRow(
            icon: Symbols.event,
            label: "Waxaad ku biirtay",
            value: AppDateUtil.formatReadableDate(user.createdAt),
          ),
        ],
      ),
    );
  }

  Widget _buildFactRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(AppUserModel user) {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isSaving || !_isChanged(user) ? null : () => _save(user),
        icon: _isSaving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Symbols.save),
        label: const Text("Save changes"),
      ),
    );
  }

  Widget _buildNoProfile() {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.person_off,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              "Akoonkaaga lama helin. Fadlan mar kale gal.",
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
