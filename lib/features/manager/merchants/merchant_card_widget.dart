import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/features/manager/merchants/stadium_merchant_model.dart';

/// One registered payment number: the provider it belongs to, the service
/// customers know it by, and the number itself.
///
/// Tapping the card is the edit affordance ([onTap]); the trailing icon turns
/// the number off, or back on ([onToggleDisabled]). Both are optional — with
/// neither, the card is a plain read-only summary.
///
/// A number is never deleted, so a disabled one stays on the list, dimmed and
/// labelled.
class MerchantCardWidget extends StatelessWidget {
  const MerchantCardWidget({
    super.key,
    required this.model,
    this.onTap,
    this.onToggleDisabled,
  });

  final StadiumMerchantModel model;

  final VoidCallback? onTap;
  final VoidCallback? onToggleDisabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: model.disabled
                      ? colorScheme.outline
                      : colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Symbols.account_balance_wallet,
                  fill: 1,
                  size: 24,
                  color: colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            model.merchantNumber,
                            style: theme.textTheme.headlineMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (model.disabled) ...[
                          const SizedBox(width: 8),
                          Text(
                            "Disabled",
                            style: theme.textTheme.bodySmall!.copyWith(
                              color: colorScheme.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Symbols.contactless, size: 16),
                        Expanded(
                          child: Text(
                            " ${model.provider.providerName} · "
                            "${model.provider.providerService}",
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onToggleDisabled != null)
                IconButton(
                  onPressed: onToggleDisabled,
                  tooltip: model.disabled ? "Enable" : "Disable",
                  icon: Icon(
                    model.disabled ? Symbols.play_circle : Symbols.block,
                    color: model.disabled
                        ? colorScheme.primary
                        : colorScheme.error,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
