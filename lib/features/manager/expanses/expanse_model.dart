import '../../../utill/app_date_util.dart';

/// The kinds an expense can be, exactly as the `expenses.expense_type`
/// check constraint allows them.
enum ExpanseType {
  salary,
  expense,
  other;

  static ExpanseType fromString(String value) {
    return ExpanseType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => ExpanseType.expense,
    );
  }

  String get value => name;
}

/// One row of the `expenses` table.
///
/// `stadium_id` is not held here. The repository takes the stadium it works
/// on, the same way fields and merchants do.
class ExpanseModel {
  final int? id;
  final ExpanseType expanseType;
  final String? description;
  final DateTime expenseDate;
  final double expenseTotal;

  const ExpanseModel({
    this.id,
    this.expanseType = ExpanseType.expense,
    this.description,
    required this.expenseDate,
    required this.expenseTotal,
  });

  factory ExpanseModel.fromJson(Map<String, dynamic> json) {
    return ExpanseModel(
      id: json['id'] as int?,
      expanseType: ExpanseType.fromString(json['expense_type'] as String),
      description: json['description'] as String?,
      expenseDate: DateTime.parse(json['expense_date'].toString()),
      expenseTotal: (json['expense_total'] as num).toDouble(),
    );
  }

  /// The id is left out because Postgres gives it, and `expense_date` is
  /// written as `yyyy-MM-dd` because the column is a DATE.
  Map<String, dynamic> toJson() {
    return {
      'expense_type': expanseType.value,
      'description': description,
      'expense_date': AppDateUtil.formatDate(expenseDate),
      'expense_total': expenseTotal,
    };
  }

  ExpanseModel copyWith({
    int? id,
    ExpanseType? expanseType,
    String? description,
    DateTime? expenseDate,
    double? expenseTotal,
  }) {
    return ExpanseModel(
      id: id ?? this.id,
      expanseType: expanseType ?? this.expanseType,
      description: description ?? this.description,
      expenseDate: expenseDate ?? this.expenseDate,
      expenseTotal: expenseTotal ?? this.expenseTotal,
    );
  }
}
