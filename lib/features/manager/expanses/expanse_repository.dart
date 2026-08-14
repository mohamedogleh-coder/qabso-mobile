import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../payments/payment_allocation_model.dart';
import '../../../utill/app_date_util.dart';
import 'expanse_model.dart';
import 'expanse_receipt_model.dart';

class ExpanseRepository {
  static final SupabaseClient _client = Supabase.instance.client;

  static const _expensesTable = 'expenses';
  static const _receiptView = 'expense_receipt_view';

  /// Reads one expense with everything a receipt shows — the transaction that
  /// settled it, who paid it out, and every portion the money left in.
  static Future<ExpanseReceiptModel> getExpanseReceipt({
    required int expenseId,
  }) async {
    final row = await _client
        .from(_receiptView)
        .select()
        .eq('id', expenseId)
        .maybeSingle();

    if (row == null) {
      throw StateError('Expense $expenseId was not found.');
    }

    return ExpanseReceiptModel.fromJson(row);
  }

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

  /// Changes what an expense says about itself — its kind, its date, its
  /// description — and nothing else.
  ///
  /// `expense_total` is deliberately left out. The amount is what the payment
  /// was written for, so changing it here would leave the transaction saying
  /// one figure and the expense another. Use [updateExpanse] to change the
  /// amount, which rewrites the payment with it.
  static Future<ExpanseModel> updateExpanseInfo({
    required ExpanseModel expanse,
  }) async {
    final id = expanse.id;
    if (id == null) {
      throw ArgumentError.value(
        expanse,
        'expanse',
        'An unsaved expense cannot be updated.',
      );
    }

    final rows = await _client
        .from(_expensesTable)
        .update({
          'expense_type': expanse.expanseType.value,
          'description': expanse.description,
          'expense_date': AppDateUtil.formatDate(expanse.expenseDate),
        })
        .eq('id', id)
        .select();

    if (rows.isEmpty) {
      throw StateError('Expense $id was not found.');
    }

    return ExpanseModel.fromJson(rows.first);
  }

  /// Removes one expense.
  ///
  /// The payment goes with it: `transactions.expense_id` points at the expense
  /// with ON DELETE CASCADE, and the transaction's `transaction_details`
  /// follow it, so nothing is left pointing at a row that is gone.
  ///
  /// The `.select()` turns a delete that matched nothing into an error, since
  /// a delete matching no row is otherwise silently fine.
  static Future<void> deleteExpanse({required int expenseId}) async {
    final deletedRows = await _client
        .from(_expensesTable)
        .delete()
        .eq('id', expenseId)
        .select('id');

    if (deletedRows.isEmpty) {
      throw StateError('Expense $expenseId was not found.');
    }
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
