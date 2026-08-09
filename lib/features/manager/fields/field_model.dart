import 'package:equatable/equatable.dart';

class FieldModel extends Equatable {
  final int? id;
  final int capacity;
  final double cost;
  final bool allowBooking;
  final List<String> fieldImages;

  const FieldModel({
    this.id,
    required this.capacity,
    required this.cost,
    this.allowBooking = true,
    this.fieldImages = const [],
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
  }) {
    return FieldModel(
      id: id ?? this.id,
      capacity: capacity ?? this.capacity,
      cost: cost ?? this.cost,
      allowBooking: allowBooking ?? this.allowBooking,
      fieldImages: fieldImages ?? this.fieldImages,
    );
  }

  @override
  List<Object?> get props => [id, capacity, cost, allowBooking, fieldImages];
}
