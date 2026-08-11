import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/features/manager/merchants/stadium_merchant_model.dart';

/// One registered payment number: the provider it belongs to, the service
/// customers know it by, and the number itself.
///
/// Tapping the card is the edit affordance ([onTap]); the trailing icon
/// deletes ([onDelete]). Both are optional — with neither, the card is a
/// plain read-only summary.
class MerchantCardWidget extends StatelessWidget {
  const MerchantCardWidget({
    super.key,
    required this.model,
    this.onTap,
    this.onDelete,
  });

  final StadiumMerchantModel model;

  final VoidCallback? onTap;
  final VoidCallback? onDelete;

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
                  color: colorScheme.primary,
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
                    Text(
                      model.merchantNumber,
                      style: theme.textTheme.headlineMedium,
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
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  tooltip: "Delete",
                  icon: Icon(Symbols.delete, color: colorScheme.error),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
