import 'package:equatable/equatable.dart';

class FieldModel extends Equatable {
  final int? id;
  final int capacity;
  final double cost;
  final bool allowBooking;
  final List<String> fieldImages;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FieldModel({
    this.id,
    required this.capacity,
    required this.cost,
    this.allowBooking = true,
    this.fieldImages = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory FieldModel.fromJson(Map<String, dynamic> json) {
    return FieldModel(
      id: json['id'] as int?,
      capacity: json['capacity'] as int,
      cost: (json['cost'] as num).toDouble(),
      allowBooking: json['allow_booking'] as bool? ?? true,
      fieldImages: json['field_images'] != null
          ? List<String>.from(json['field_images'] as List)
          : [],
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
      'id': id,
      'capacity': capacity,
      'cost': cost,
      'allow_booking': allowBooking,
    };
  }

  FieldModel copyWith({
    int? id,
    int? capacity,
    double? cost,
    bool? allowBooking,
    List<String>? fieldImages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FieldModel(
      id: id ?? this.id,
      capacity: capacity ?? this.capacity,
      cost: cost ?? this.cost,
      allowBooking: allowBooking ?? this.allowBooking,
      fieldImages: fieldImages ?? this.fieldImages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    capacity,
    cost,
    allowBooking,
    fieldImages,
    createdAt,
    updatedAt,
  ];
}
