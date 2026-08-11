class MerchantProviderModel {
  final int id;
  final String providerName;
  final String providerService;

  const MerchantProviderModel({
    required this.id,
    required this.providerName,
    required this.providerService,
  });

  factory MerchantProviderModel.fromJson(Map<String, dynamic> json) {
    return MerchantProviderModel(
      id: json['id'] as int,
      providerName: json['provider_name'] as String,
      providerService: json['provider_service'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'provider_name': providerName,
      'provider_service': providerService,
    };
  }

  MerchantProviderModel copyWith({
    int? id,
    String? providerName,
    String? providerService,
  }) {
    return MerchantProviderModel(
      id: id ?? this.id,
      providerName: providerName ?? this.providerName,
      providerService: providerService ?? this.providerService,
    );
  }
}
