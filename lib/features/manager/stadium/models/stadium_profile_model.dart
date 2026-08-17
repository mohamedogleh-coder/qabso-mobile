import '../stadium_model.dart';

/// A stadium's profile: the stadium itself, how many fields it is working
/// with, and the pictures of its fields.
///
/// Read from `stadium_profile_fn`.
class StadiumProfileModel extends StadiumModel {
  /// How many of the stadium's fields are open to booking. Fields the manager
  /// has closed are not counted.
  final int workingFields;

  /// Every picture the stadium's fields have, each carrying the field it
  /// belongs to so the grid can label it.
  final List<StadiumFieldImageModel> fieldImages;

  const StadiumProfileModel({
    super.stadiumId,
    required super.stadiumName,
    super.latitude,
    super.longitude,
    required super.extraTime,
    required super.allowHalfBooking,
    super.createdAt,
    super.updatedAt,
    required this.workingFields,
    this.fieldImages = const [],
  });

  factory StadiumProfileModel.fromJson(Map<String, dynamic> json) {
    final images = (json['field_images'] as List?) ?? [];

    return StadiumProfileModel(
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
      workingFields: json['working_fields'] as int,
      fieldImages: images
          .map(
            (image) => StadiumFieldImageModel.fromJson(
              Map<String, dynamic>.from(image as Map),
            ),
          )
          .toList(),
    );
  }

  bool get hasLocation => latitude != null && longitude != null;

  @override
  List<Object?> get props => [...super.props, workingFields, fieldImages];
}

/// One picture of one field, with what the grid overlays on it.
class StadiumFieldImageModel {
  final int fieldId;

  /// How many players that field holds.
  final int capacity;

  /// A link, not a storage path. The repository turns the stored path into a
  /// public URL before the model is built.
  final String imageUrl;

  const StadiumFieldImageModel({
    required this.fieldId,
    required this.capacity,
    required this.imageUrl,
  });

  factory StadiumFieldImageModel.fromJson(Map<String, dynamic> json) {
    return StadiumFieldImageModel(
      fieldId: json['field_id'] as int,
      capacity: json['capacity'] as int,
      imageUrl: json['image_url'] as String,
    );
  }
}
