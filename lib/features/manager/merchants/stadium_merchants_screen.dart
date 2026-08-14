import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/features/manager/merchants/merchant_notifier_provider.dart';
import 'package:qabso_mobile/features/manager/merchants/merchant_provider_model.dart';
import 'package:qabso_mobile/features/manager/merchants/stadium_merchant_model.dart';

import '../../../utill/app_dailogs.dart';
import '../../../utill/app_input_text_widget.dart';
import '../../../utill/error_widget.dart';
import '../../../utill/loading_widget.dart';
import 'edit_merchant_widget.dart';
import 'merchant_card_widget.dart';

class MerchantDraft {
  MerchantDraft();

  final Key key = UniqueKey();

  MerchantProviderModel? provider;
  String merchantNumber = '';
}

class StadiumMerchantsScreen extends ConsumerStatefulWidget {
  const StadiumMerchantsScreen({super.key});

  @override
  ConsumerState<StadiumMerchantsScreen> createState() =>
      _StadiumMerchantsScreenState();
}

class _StadiumMerchantsScreenState
    extends ConsumerState<StadiumMerchantsScreen> {
  final List<MerchantDraft> _drafts = [];
  final _formKey = GlobalKey<FormState>();
  bool isSubmitting = false;

  void _addDraft() {
    setState(() => _drafts.add(MerchantDraft()));
  }

  void _removeDraft(MerchantDraft draft) {
    setState(() => _drafts.remove(draft));
  }

  bool get isChanged => _drafts.isNotEmpty;

  Future<void> _editMerchant(StadiumMerchantModel merchant) async {
    final saved = await showAppBottomSheet<bool>(
      context: context,
      title: "Edit merchant",
      builder: (sheetContext) =>
          SafeArea(child: EditMerchantWidget(merchant: merchant)),
    );

    if (saved == true && mounted) {
      showSuccessSnackBar(context: context, message: "Merchant updated.");
    }
  }

  /// A number that has taken money is kept, so it is turned off instead of
  /// being removed. The same action turns it back on.
  Future<void> _toggleMerchantDisabled(StadiumMerchantModel merchant) async {
    final disable = !merchant.disabled;
    final action = disable ? "Disable" : "Enable";

    final changed = await showAppConfirmationDialog(
      context: context,
      title: "$action merchant?",
      message:
          "Ma hubtaa inaad ${action.toLowerCase()}-garayso merchantka (${merchant.merchantNumber} ${merchant.provider.providerName})",
      confirmText: action,
      isDestructive: disable,
      icon: disable ? Symbols.block : Symbols.play_circle,
      onConfirm: () => ref
          .read(merchantNotifierProvider.notifier)
          .setMerchantDisabled(merchant, disable),
    );

    if (changed && mounted) {
      showSuccessSnackBar(
        context: context,
        message: disable ? "Merchant disabled." : "Merchant enabled.",
      );
    }
  }

  String? _duplicateError(List<StadiumMerchantModel> existing) {
    final seen = <String>{
      for (final merchant in existing)
        '${merchant.provider.id}:${merchant.merchantNumber.trim()}',
    };

    for (final draft in _drafts) {
      final provider = draft.provider;
      if (provider == null) continue;

      final key = '${provider.id}:${draft.merchantNumber.trim()}';
      if (!seen.add(key)) {
        return "${provider.providerName} already has the number "
            "${draft.merchantNumber.trim()}.";
      }
    }

    return null;
  }

  Future<void> _handleSubmit(List<StadiumMerchantModel> existing) async {
    if (isSubmitting || !isChanged) return;

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final duplicate = _duplicateError(existing);
    if (duplicate != null) {
      showErrorSnackBar(context: context, message: duplicate);
      return;
    }

    setState(() => isSubmitting = true);

    try {
      await ref.read(merchantNotifierProvider.notifier).addMerchants([
        for (final draft in _drafts)
          StadiumMerchantModel(
            merchantNumber: draft.merchantNumber.trim(),
            provider: draft.provider!,
          ),
      ]);

      if (!mounted) return;
      setState(() {
        isSubmitting = false;
        _drafts.clear();
      });

      showSuccessSnackBar(context: context, message: "Merchants registered.");
    } catch (e) {
      if (!mounted) return;
      setState(() => isSubmitting = false);
      showErrorSnackBar(context: context, message: e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final merchantsAsync = ref.watch(merchantNotifierProvider);
    final providersAsync = ref.watch(merchantProvidersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Merchants"),
        actions: [
          TextButton.icon(
            onPressed:
                isSubmitting || !isChanged || merchantsAsync.value == null
                ? null
                : () => _handleSubmit(merchantsAsync.value!),
            label: Text(_drafts.length > 1 ? "Save all" : "Save"),
            icon: isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Symbols.check),
          ),
        ],
      ),
      floatingActionButton: providersAsync.hasValue
          ? FloatingActionButton.extended(
              onPressed: isSubmitting ? null : _addDraft,
              icon: const Icon(Symbols.add),
              label: const Text("Add"),
            )
          : null,
      body: merchantsAsync.when(
        skipLoadingOnRefresh: false,
        data: (merchants) => providersAsync.when(
          data: (providers) => _buildForm(merchants, providers),
          error: (error, stackTrace) => ErrorRetryWidget(
            errorMessage: error.toString(),
            onRetry: () => ref.invalidate(merchantProvidersProvider),
          ),
          loading: () => const LoadingWidget(),
        ),
        error: (error, stackTrace) => ErrorRetryWidget(
          errorMessage: error.toString(),
          onRetry: () => ref.read(merchantNotifierProvider.notifier).refresh(),
        ),
        loading: () => const LoadingWidget(),
      ),
    );
  }

  Widget _buildForm(
    List<StadiumMerchantModel> merchants,
    List<MerchantProviderModel> providers,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 96),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (merchants.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  "Merchant numberska maxaamiishu lacagta kusoo diri karaan",
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            const SizedBox(height: 12),
            if (merchants.isNotEmpty) ...[
              _buildNewCounterTitle("Registered", merchants.length),
              for (final merchant in merchants)
                RefreshIndicator(
                  onRefresh: () async =>
                      ref.read(merchantNotifierProvider.notifier).refresh(),
                  child: MerchantCardWidget(
                    model: merchant,
                    onTap: isSubmitting ? null : () => _editMerchant(merchant),
                    onToggleDisabled: isSubmitting
                        ? null
                        : () => _toggleMerchantDisabled(merchant),
                  ),
                ),
              const SizedBox(height: 12),
            ],
            if (_drafts.isNotEmpty)
              _buildNewCounterTitle("New", _drafts.length),
            if (merchants.isEmpty && _drafts.isEmpty)
              _buildEmptyDrafts(merchants.isEmpty),
            for (final draft in _drafts)
              _buildDraftCard(draft, providers, key: draft.key),
          ],
        ),
      ),
    );
  }

  Widget _buildNewCounterTitle(String title, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Text(
        "$title ($count)",
        style: Theme.of(context).textTheme.headlineMedium,
      ),
    );
  }

  Widget _buildEmptyDrafts(bool hasNoMerchants) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).highlightColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Symbols.account_balance_wallet_sharp,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            hasNoMerchants
                ? "Macaamiisha looma soo ban dhigi doono garoonkaga hadii aanu lahayn meel lacagta"
                      "lagugu soo diri karo"
                : "No new merchants added",
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Taabo \"Add\" si mid cusub u samayso.",
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildDraftCard(
    MerchantDraft draft,
    List<MerchantProviderModel> providers, {
    required Key key,
  }) {
    final theme = Theme.of(context);

    return Card(
      key: key,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("New merchant", style: theme.textTheme.bodySmall),
                IconButton(
                  onPressed: isSubmitting ? null : () => _removeDraft(draft),
                  icon: Icon(Symbols.delete, color: theme.colorScheme.error),
                ),
              ],
            ),
            DropdownButtonFormField<int>(
              initialValue: draft.provider?.id,
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
                      draft.provider = providers.firstWhere(
                        (provider) => provider.id == id,
                      );
                    }),
              validator: (id) => id == null ? "Select a provider" : null,
            ),
            AppInputTextWidget(
              label: "Merchant number",
              hintText: "e.g. 063xxxxxxx",
              prefixIcon: Symbols.dialpad,
              value: draft.merchantNumber,
              enabled: !isSubmitting,
              capitalize: false,
              maxLength: 20,
              counterText: "",
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9*#]')),
              ],
              onChanged: (v) => draft.merchantNumber = v,
              validator: (v) {
                final value = v?.trim() ?? '';
                if (value.isEmpty) return "Enter the merchant number";
                if (value.length < 6) return "Enter a valid merchant number";
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}
