import 'merchant_provider_model.dart';

class StadiumMerchantModel {
  final int? id;
  final String merchantNumber;
  final MerchantProviderModel provider;

  const StadiumMerchantModel({
    this.id,
    required this.merchantNumber,
    required this.provider,
  });

  factory StadiumMerchantModel.fromJson(Map<String, dynamic> json) {
    return StadiumMerchantModel(
      id: json['id'] as int?,
      merchantNumber: json['merchant_number'] as String,
      provider: MerchantProviderModel.fromJson(
        json['provider'] as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchant_number': merchantNumber,
      'provider': provider.toJson(),
    };
  }

  StadiumMerchantModel copyWith({
    int? id,
    String? merchantNumber,
    MerchantProviderModel? provider,
  }) {
    return StadiumMerchantModel(
      id: id ?? this.id,
      merchantNumber: merchantNumber ?? this.merchantNumber,
      provider: provider ?? this.provider,
    );
  }
}
