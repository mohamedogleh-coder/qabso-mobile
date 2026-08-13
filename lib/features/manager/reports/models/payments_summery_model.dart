class PaymentsSummeryModel {
  final double totalPayments;
  final double totalRefunds;
  final double totalExpenses;
  final double totalDiscounts;
  final List<MerchantSummeryModel> merchants;

  const PaymentsSummeryModel({
    required this.totalPayments,
    required this.totalRefunds,
    required this.totalExpenses,
    required this.totalDiscounts,
    required this.merchants,
  });

  factory PaymentsSummeryModel.fromJson(Map<String, dynamic> json) {
    final merchants = (json['merchants'] as List?) ?? [];

    return PaymentsSummeryModel(
      totalPayments: toDouble(json['totalPayments']),
      totalRefunds: toDouble(json['totalRefunds']),
      totalExpenses: toDouble(json['totalExpenses']),
      totalDiscounts: toDouble(json['totalDiscounts']),
      merchants: merchants
          .map(
            (merchant) =>
                MerchantSummeryModel.fromJson(merchant as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  static double toDouble(dynamic value) => (value as num?)?.toDouble() ?? 0;
}

class MerchantSummeryModel {
  final String merchantNumber;
  final String providerName;
  final String providerService;

  final double totalAmount;

  const MerchantSummeryModel({
    required this.merchantNumber,
    required this.providerName,
    required this.providerService,
    required this.totalAmount,
  });

  factory MerchantSummeryModel.fromJson(Map<String, dynamic> json) {
    return MerchantSummeryModel(
      merchantNumber: json['merchantNumber'] ?? '',
      providerName: json['providerName'] ?? '',
      providerService: json['providerService'] ?? '',
      totalAmount: PaymentsSummeryModel.toDouble(json['totalAmount']),
    );
  }
}
