import 'merchant_provider_model.dart';

class StadiumMerchantModel {
  final int? id;
  final String merchantNumber;
  final MerchantProviderModel provider;

  /// Turned off for new payments. A number that has taken money is never
  /// deleted, so this is what retires it.
  final bool disabled;

  const StadiumMerchantModel({
    this.id,
    required this.merchantNumber,
    required this.provider,
    this.disabled = false,
  });

  factory StadiumMerchantModel.fromJson(Map<String, dynamic> json) {
    return StadiumMerchantModel(
      id: json['id'] as int?,
      merchantNumber: json['merchant_number'] as String,
      disabled: json['disabled'] as bool? ?? false,
      provider: MerchantProviderModel.fromJson(
        json['provider'] as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchant_number': merchantNumber,
      'disabled': disabled,
      'provider': provider.toJson(),
    };
  }

  StadiumMerchantModel copyWith({
    int? id,
    String? merchantNumber,
    MerchantProviderModel? provider,
    bool? disabled,
  }) {
    return StadiumMerchantModel(
      id: id ?? this.id,
      merchantNumber: merchantNumber ?? this.merchantNumber,
      provider: provider ?? this.provider,
      disabled: disabled ?? this.disabled,
    );
  }
}
