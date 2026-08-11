import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/features/manager/events/time_slots_model.dart';
import 'package:qabso_mobile/payments/payment_allocation_model.dart';

import '../features/manager/merchants/merchant_repository.dart';
import '../features/manager/merchants/stadium_merchant_model.dart';
import '../utill/app_date_util.dart';
import '../utill/error_widget.dart';
import '../utill/loading_widget.dart';

/// Collects a customer's payment for one booked slot.
///
/// Deliberately narrower than [PaymentWidget], which lets a manager split one
/// amount across several methods: a customer pays the whole
/// [requiredAmount] through exactly one of the stadium's registered
/// merchants. No cash, no discount, no splitting — so there is one
/// allocation to return and nothing to reconcile.
///
/// It collects and validates only. [onSubmit] hands the finished
/// [PaymentAllocationModel] to the parent, which decides what to do with it.
class UserPaymentWidget extends StatefulWidget {
  final String stadiumId;
  final double requiredAmount;
  final TimeSlotModel timeSlotModel;

  /// Called with the chosen merchant and the full required amount, once and
  /// only once a merchant has been selected.
  final ValueChanged<PaymentAllocationModel> onSubmit;

  const UserPaymentWidget({
    super.key,
    required this.stadiumId,
    required this.requiredAmount,
    required this.timeSlotModel,
    required this.onSubmit,
  });

  @override
  State<UserPaymentWidget> createState() => _UserPaymentWidgetState();
}

class _UserPaymentWidgetState extends State<UserPaymentWidget> {
  /// Held in state rather than built in `build`: a future created inline
  /// would re-fetch on every rebuild — every tap of a merchant included.
  /// Created here, it fetches once per opening, which is what keeps the
  /// numbers fresh without re-reading them as the user chooses.
  late Future<List<StadiumMerchantModel>> _merchantsFuture;

  StadiumMerchantModel? _selectedMerchant;

  @override
  void initState() {
    super.initState();
    _merchantsFuture = _fetchMerchants();
  }

  Future<List<StadiumMerchantModel>> _fetchMerchants() =>
      MerchantRepository.getMerchants(stadiumId: widget.stadiumId);

  void _reload() {
    setState(() {
      _selectedMerchant = null;
      _merchantsFuture = _fetchMerchants();
    });
  }

  bool get _canPay => _selectedMerchant != null && widget.requiredAmount > 0;

  void _handleSubmit() {
    final merchant = _selectedMerchant;
    if (merchant == null || !_canPay) return;

    widget.onSubmit(
      PaymentAllocationModel(
        merchant: merchant,
        amountPaid: widget.requiredAmount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEventCard(),
          const SizedBox(height: 16),
          FutureBuilder<List<StadiumMerchantModel>>(
            future: _merchantsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: LoadingWidget(),
                );
              }

              if (snapshot.hasError) {
                return ErrorRetryWidget(
                  errorMessage: snapshot.error.toString(),
                  onRetry: _reload,
                );
              }

              final merchants = snapshot.data ?? const [];
              if (merchants.isEmpty) return _buildEmptyMerchants();

              return _buildMerchantPicker(merchants);
            },
          ),
          const SizedBox(height: 20),
          _buildPayButton(),
        ],
      ),
    );
  }

  /// What the customer is paying for, and what it costs.
  Widget _buildEventCard() {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: .25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Symbols.schedule,
              size: 25,
              color: theme.colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Selected Time", style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                Text(
                  widget.timeSlotModel.label,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppDateUtil.formatReadableDate(
                    widget.timeSlotModel.startTime,
                  ),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          Text(
            "\$${widget.requiredAmount.toStringAsFixed(2)}",
            style: theme.textTheme.headlineMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildMerchantPicker(List<StadiumMerchantModel> merchants) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Dooro qaabka lacag bixinta", style: theme.textTheme.bodyMedium),
        const SizedBox(height: 12),
        for (final merchant in merchants) ...[
          _buildMerchantTile(merchant),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildMerchantTile(StadiumMerchantModel merchant) {
    final theme = Theme.of(context);
    final isSelected = _selectedMerchant?.id == merchant.id;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _selectedMerchant = merchant),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.colorScheme.primary.withValues(alpha: .08)
              : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Symbols.account_balance_wallet_sharp,
                fill: isSelected ? 1 : 0,
                size: 22,
                color: isSelected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    merchant.provider.providerService,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "${merchant.provider.providerName} · "
                    "${merchant.merchantNumber}",
                    style: theme.textTheme.labelMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            Icon(
              isSelected
                  ? Symbols.radio_button_checked
                  : Symbols.radio_button_unchecked,
              fill: isSelected ? 1 : 0,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMerchants() {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.highlightColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            Symbols.account_balance_wallet,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 8),
          Text(
            "Garoonkan ma laha lambaro lacag bixin",
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            "La xidhiidh maamulaha garoonka.",
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPayButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _canPay ? _handleSubmit : null,
        icon: const Icon(Symbols.payments),
        label: Text("Pay Now  \$${widget.requiredAmount.toStringAsFixed(2)}"),
      ),
    );
  }
}
