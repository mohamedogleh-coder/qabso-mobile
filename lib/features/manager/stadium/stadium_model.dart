import 'package:equatable/equatable.dart';

class StadiumModel extends Equatable {
  final String? stadiumId;
  final String stadiumName;
  final double? latitude;
  final double? longitude;
  final int extraTime;
  final bool allowHalfBooking;

  const StadiumModel({
    this.stadiumId,
    required this.stadiumName,
    this.latitude,
    this.longitude,
    required this.extraTime,
    required this.allowHalfBooking,
  });

  factory StadiumModel.fromJson(Map<String, dynamic> json) {
    return StadiumModel(
      stadiumId: json['id'] as String?,
      stadiumName: json['stadium_name'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      extraTime: json['extra_time'] as int,
      allowHalfBooking: json['allow_half_booking'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stadiumName': stadiumName,
      'latitude': latitude,
      'longitude': longitude,
      'extraTime': extraTime,
      'allowHalfBooking': allowHalfBooking,
    };
  }

  StadiumModel copyWith({
    String? stadiumId,
    String? stadiumName,
    int? extraTime,
    double? Function()? latitude,
    double? Function()? longitude,
    String? profileUrl,
    bool? allowHalfBooking,
  }) {
    return StadiumModel(
      stadiumId: stadiumId ?? this.stadiumId,
      stadiumName: stadiumName ?? this.stadiumName,
      extraTime: extraTime ?? this.extraTime,
      latitude: latitude != null ? latitude() : this.latitude,
      longitude: longitude != null ? longitude() : this.longitude,
      allowHalfBooking: allowHalfBooking ?? this.allowHalfBooking,
    );
  }

  @override
  List<Object?> get props => [
    stadiumId,
    stadiumName,
    latitude,
    longitude,
    extraTime,
    allowHalfBooking,
  ];
}
