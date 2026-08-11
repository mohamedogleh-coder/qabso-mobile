import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/features/manager/merchants/merchant_notifier_provider.dart';
import 'package:qabso_mobile/features/manager/merchants/merchant_provider_model.dart';
import 'package:qabso_mobile/features/manager/merchants/stadium_merchant_model.dart';

import '../../../utill/app_input_text_widget.dart';

/// Contents of the single-merchant editor shown inside `showAppBottomSheet` —
/// the sheet chrome (shape, drag handle, keyboard padding, title) comes from
/// that shared utility, so this is only the form.
///
/// Saves through the notifier's single-merchant update, which replaces the
/// list in provider state with what the server returned. Pops with `true`
/// once that lands, and on failure stays open showing the error so the edit
/// isn't lost.
class EditMerchantWidget extends ConsumerStatefulWidget {
  const EditMerchantWidget({super.key, required this.merchant});

  final StadiumMerchantModel merchant;

  @override
  ConsumerState<EditMerchantWidget> createState() => _EditMerchantWidgetState();
}

class _EditMerchantWidgetState extends ConsumerState<EditMerchantWidget> {
  late MerchantProviderModel _provider = widget.merchant.provider;
  late String _merchantNumber = widget.merchant.merchantNumber;

  final _formKey = GlobalKey<FormState>();
  bool isSubmitting = false;
  String? _errorText;

  bool get isChanged =>
      _provider.id != widget.merchant.provider.id ||
      _merchantNumber.trim() != widget.merchant.merchantNumber.trim();

  /// `stadium_merchants` is unique on
  /// `(stadium_id, provider_id, merchant_number)`, so the chosen provider
  /// can't already hold this number. Checked against current state to fail
  /// legibly instead of as a Postgres constraint violation.
  String? _duplicateError() {
    final merchants = ref.read(merchantNotifierProvider).value ?? const [];
    final number = _merchantNumber.trim();

    final clash = merchants.any(
      (merchant) =>
          merchant.id != widget.merchant.id &&
          merchant.provider.id == _provider.id &&
          merchant.merchantNumber.trim() == number,
    );

    return clash ? "${_provider.providerName} already has that number." : null;
  }

  Future<void> _handleSave() async {
    if (isSubmitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final duplicate = _duplicateError();
    if (duplicate != null) {
      setState(() => _errorText = duplicate);
      return;
    }

    setState(() {
      isSubmitting = true;
      _errorText = null;
    });

    try {
      await ref
          .read(merchantNotifierProvider.notifier)
          .updateMerchant(
            widget.merchant.copyWith(
              merchantNumber: _merchantNumber.trim(),
              provider: _provider,
            ),
          );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isSubmitting = false;
        _errorText = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // The sheet only opens from a screen that has already loaded the
    // providers, so this is a cache read. The merchant's own provider is the
    // fallback, keeping the dropdown correct even if that ever changes.
    final providers =
        ref.watch(merchantProvidersProvider).value ??
        [widget.merchant.provider];

    return PopScope(
      canPop: !isSubmitting,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _provider.id,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: "Provider",
                  prefixIcon: Icon(Symbols.account_balance_wallet),
                ),
                items: [
                  for (final provider in providers)
                    DropdownMenuItem(
                      value: provider.id,
                      child: Text(
                        "${provider.providerName} · ${provider.providerService}",
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: isSubmitting
                    ? null
                    : (id) => setState(() {
                        _provider = providers.firstWhere(
                          (provider) => provider.id == id,
                        );
                        _errorText = null;
                      }),
                validator: (id) => id == null ? "Select a provider" : null,
              ),
              AppInputTextWidget(
                label: "Merchant number",
                prefixIcon: Symbols.dialpad,
                value: _merchantNumber,
                enabled: !isSubmitting,
                capitalize: false,
                maxLength: 20,
                counterText: "",
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9*#]')),
                ],
                onChanged: (v) => setState(() {
                  _merchantNumber = v;
                  _errorText = null;
                }),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return "Enter the merchant number";
                  if (value.length < 6) return "Enter a valid merchant number";
                  return null;
                },
              ),
              if (_errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: isSubmitting
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: isSubmitting || !isChanged
                          ? null
                          : _handleSave,
                      icon: isSubmitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Symbols.check),
                      label: const Text("Save"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
