import 'package:qabso_mobile/features/manager/stadium/stadium_model.dart';

class ExploredStadiumModel extends StadiumModel {
  final double? distance;
  final int fieldId;
  final int capacity;
  final double cost;

  final List<String> imageUrls;

  final bool fav;

  const ExploredStadiumModel({
    super.stadiumId,
    required super.stadiumName,
    super.latitude,
    super.longitude,
    required super.extraTime,
    required super.allowHalfBooking,
    this.distance,
    required this.fieldId,
    required this.capacity,
    required this.cost,
    this.imageUrls = const [],
    this.fav = false,
  });

  factory ExploredStadiumModel.fromJson(Map<String, dynamic> json) {
    return ExploredStadiumModel(
      stadiumId: json['id'] as String?,
      stadiumName: json['stadium_name'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      extraTime: json['extra_time'] as int,
      allowHalfBooking: json['allow_half_booking'] as bool,
      distance: (json['distance'] as num?)?.toDouble(),
      fieldId: json['field_id'] as int,
      capacity: json['capacity'] as int,
      cost: (json['cost'] as num).toDouble(),
      imageUrls: json['image_urls'] != null
          ? List<String>.from(json['image_urls'] as List)
          : const [],
      fav: json['fav'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    ...super.props,
    distance,
    fieldId,
    capacity,
    cost,
    imageUrls,
    fav,
  ];
}
