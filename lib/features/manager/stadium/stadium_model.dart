import 'package:equatable/equatable.dart';

class StadiumModel extends Equatable {
  final String? stadiumId;
  final String stadiumName;
  final double? latitude;
  final double? longitude;
  final int extraTime;
  final bool allowHalfBooking;

  /// The day the stadium was registered, and the last time its details were
  /// changed. Both are set by the database, so they are null on a stadium that
  /// has not been saved yet.
  ///
  /// [createdAt] is where the app's date pickers start: nothing happened at
  /// this stadium before it existed.
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const StadiumModel({
    this.stadiumId,
    required this.stadiumName,
    this.latitude,
    this.longitude,
    required this.extraTime,
    required this.allowHalfBooking,
    this.createdAt,
    this.updatedAt,
  });

  factory StadiumModel.fromJson(Map<String, dynamic> json) {
    return StadiumModel(
      stadiumId: json['id'] as String?,
      stadiumName: json['stadium_name'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      extraTime: json['extra_time'] as int,
      allowHalfBooking: json['allow_half_booking'] as bool,
      // Both are timestamptz, so they arrive with an offset and are moved to
      // the phone's own time.
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'].toString()).toLocal(),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'].toString()).toLocal(),
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
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StadiumModel(
      stadiumId: stadiumId ?? this.stadiumId,
      stadiumName: stadiumName ?? this.stadiumName,
      extraTime: extraTime ?? this.extraTime,
      latitude: latitude != null ? latitude() : this.latitude,
      longitude: longitude != null ? longitude() : this.longitude,
      allowHalfBooking: allowHalfBooking ?? this.allowHalfBooking,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    createdAt,
    updatedAt,
  ];
}
