enum AppUserRole {
  manager,
  referee,
  user;

  factory AppUserRole.fromJson(String value) {
    return AppUserRole.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AppUserRole.user,
    );
  }

  String toJson() => name;
}

class AppUserModel {
  final String id;
  final String fullName;
  final String? profile;
  final String phoneNumber;
  final AppUserRole role;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const AppUserModel({
    required this.id,
    required this.fullName,
    required this.phoneNumber,
    required this.role,
    required this.createdAt,
    this.updatedAt,
    this.profile,
  });

  factory AppUserModel.fromJson(Map<String, dynamic> json) {
    return AppUserModel(
      id: json['id'],
      fullName: json['full_name'],
      phoneNumber: json['phone_number'],
      profile: json['photo_url'],
      role: AppUserRole.fromJson(json['role']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'profile':profile,
      'role': role.toJson(),
    };
  }
}
