import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../payments/payment_allocation_model.dart';
import '../../../utill/app_date_util.dart';
import 'expanse_model.dart';

class ExpanseRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static const _expensesTable = 'expenses';

  /// Reads the stadium's expenses, newest first.
  ///
  /// The dates and the type narrow the read in the database, so the screen
  /// only ever holds the rows it shows.
  static Future<List<ExpanseModel>> getExpanses({
    required String stadiumId,
    DateTime? startDate,
    DateTime? endDate,
    ExpanseType? type,
  }) async {
    if (startDate != null && endDate != null && startDate.isAfter(endDate)) {
      throw ArgumentError('The start date cannot be after the end date.');
    }

    var query = _client
        .from(_expensesTable)
        .select()
        .eq('stadium_id', stadiumId);

    if (startDate != null) {
      query = query.gte('expense_date', AppDateUtil.formatDate(startDate));
    }
    if (endDate != null) {
      query = query.lte('expense_date', AppDateUtil.formatDate(endDate));
    }
    if (type != null) {
      query = query.eq('expense_type', type.value);
    }

    final rows = await query.order('expense_date', ascending: false);

    return rows.map(ExpanseModel.fromJson).toList();
  }

  static Future<int> addExpanse({
    required String stadiumId,
    required ExpanseModel expanse,
    required List<PaymentAllocationModel> payments,
  }) async {
    final processedBy = _client.auth.currentUser?.id;
    if (processedBy == null) {
      throw StateError('Cannot add expense: no authenticated user.');
    }
    _checkPayments(payments);

    final expenseId = await _client.rpc(
      'add_expense_fn',
      params: {
        'p_stadium_id': stadiumId,
        ..._expensePayload(expanse),
        'p_processed_by': processedBy,
        'p_merchants': payments.map((payment) => payment.toJson()).toList(),
      },
    );

    return expenseId as int;
  }

  static Future<int> updateExpanse({
    required String stadiumId,
    required ExpanseModel expanse,
    required List<PaymentAllocationModel> payments,
  }) async {
    final id = expanse.id;
    if (id == null) {
      throw ArgumentError.value(
        expanse,
        'expanse',
        'An unsaved expense cannot be updated.',
      );
    }

    _checkPayments(payments);

    final expenseId = await _client.rpc(
      'update_expense_fn',
      params: {
        'p_expense_id': id,
        'p_stadium_id': stadiumId,
        ..._expensePayload(expanse),
        'p_merchants': payments.map((payment) => payment.toJson()).toList(),
      },
    );

    return expenseId as int;
  }

  static Map<String, dynamic> _expensePayload(ExpanseModel expanse) {
    return {
      'p_expense_type': expanse.expanseType.value,
      'p_description': expanse.description,
      'p_expense_date': AppDateUtil.formatDate(expanse.expenseDate),
      'p_expense_total': expanse.expenseTotal,
    };
  }

  static void _checkPayments(List<PaymentAllocationModel> payments) {
    if (payments.isEmpty) {
      throw ArgumentError.value(
        payments,
        'payments',
        'At least one payment is required.',
      );
    }

    if (payments.any((payment) => payment.amountPaid <= 0)) {
      throw ArgumentError.value(
        payments,
        'payments',
        'Every payment must be greater than zero.',
      );
    }
  }
}
