import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../utill/app_constants.dart';
import '../models/payments_summery_model.dart';

class MerchantRowWidget extends StatelessWidget {
  final MerchantSummeryModel model;

  const MerchantRowWidget({super.key, required this.model});

  bool get _isCash => model.merchantNumber == 'Cash';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _isCash ? AppConstants.warning : AppConstants.tertiary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _isCash ? Symbols.payments : Symbols.account_balance_wallet,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isCash ? "Cash" : model.providerService,
                  style: theme.textTheme.bodyLarge!.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (!_isCash)
                  Text(
                    "${model.providerName}  •  ${model.merchantNumber}",
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "\$${model.totalAmount.toStringAsFixed(2)}",
            style: theme.textTheme.bodyLarge!.copyWith(
              fontWeight: FontWeight.bold,
              color: model.totalAmount < 0
                  ? AppConstants.error
                  : theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
