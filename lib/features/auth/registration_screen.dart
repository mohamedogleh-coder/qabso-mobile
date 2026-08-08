import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utill/app_image_picker_widget.dart';
import '../../utill/app_input_text_widget.dart';
import 'app_user_notifer.dart';

class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();

  File? _avatarFile;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  String? _validateFullName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Full name is required';
    if (name.length < 2) return 'Enter your full name';
    return null;
  }

  String? _validatePhoneNumber(String? value) {
    final phone = value?.trim() ?? '';
    if (phone.isEmpty) return 'Phone number is required';
    final phoneRegex = RegExp(r'^[+]?[0-9\s-]{7,20}$');
    if (!phoneRegex.hasMatch(phone)) return 'Enter a valid phone number';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.createUserProfile(
        fullName: _fullNameController.text.trim(),
        phoneNumber: _phoneNumberController.text.trim(),
        avatarFile: _avatarFile,
      );
      //Automatic navigation samee madama la refresh gareyey
      await ref.read(appUserNotifierProvider.notifier).refresh();
    } on PostgrestException catch (e) {
      setState(
        () => _errorMessage = e.code == '23505'
            ? 'That phone number is already in use.'
            : e.message,
      );
    } on StorageException catch (e) {
      setState(() => _errorMessage = 'Could not upload photo: ${e.message}');
    } catch (_) {
      setState(() => _errorMessage = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Complete your profile',
                      textAlign: TextAlign.center,
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tell us a bit about yourself to finish setting up your account.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 32),
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: colorScheme.onErrorContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: colorScheme.onErrorContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Center(
                      child: AppImagePickerWidget(
                        size: 110,
                        enabled: !_isSubmitting,
                        onChanged: (file) => setState(() => _avatarFile = file),
                      ),
                    ),
                    const SizedBox(height: 24),
                    AppInputTextWidget(
                      controller: _fullNameController,
                      label: 'Full name',
                      hintText: 'Your full name',
                      textInputAction: TextInputAction.next,
                      prefixIcon: Icons.person_outline,
                      enabled: !_isSubmitting,
                      validator: _validateFullName,
                    ),
                    AppInputTextWidget(
                      controller: _phoneNumberController,
                      label: 'Phone number',
                      hintText: '+252 61 234 5678',
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      prefixIcon: Icons.phone_outlined,
                      enabled: !_isSubmitting,
                      validator: _validatePhoneNumber,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      child: _isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Finish setting up'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
