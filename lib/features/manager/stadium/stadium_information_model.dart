import 'package:qabso_mobile/features/manager/fields/field_model.dart';
import 'package:qabso_mobile/features/manager/stadium/stadium_model.dart';

class StadiumInformationModel extends StadiumModel {
  final List<FieldModel> fields;

  const StadiumInformationModel({
    super.stadiumId,
    required super.stadiumName,
    super.latitude,
    super.longitude,
    required super.extraTime,
    required super.allowHalfBooking,
    super.createdAt,
    super.updatedAt,
    required this.fields,
  });

  factory StadiumInformationModel.fromJson(Map<String, dynamic> json) {
    final fields = (json['fields'] as List?) ?? [];

    return StadiumInformationModel(
      stadiumId: json['id'] as String?,
      stadiumName: json['stadium_name'] as String,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      extraTime: json['extra_time'] as int,
      allowHalfBooking: json['allow_half_booking'] as bool,
      // Both are timestamptz, so they arrive with an offset and are moved to
      // the phone's own time, the same way StadiumModel does it.
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'].toString()).toLocal(),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'].toString()).toLocal(),
      fields: fields
          .map(
            (field) =>
                FieldModel.fromJson(Map<String, dynamic>.from(field as Map)),
          )
          .toList(),
    );
  }

  @override
  List<Object?> get props => [...super.props, fields];
}
