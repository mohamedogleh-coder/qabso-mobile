import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../payments/payment_widget.dart';
import '../../../utill/app_dailogs.dart';
import '../../../utill/app_date_util.dart';
import '../../../utill/app_input_text_widget.dart';
import '../../../utill/app_utility_service.dart';
import '../stadium/stadium_notifier_provider.dart';
import 'expanse_card_widget.dart';
import 'expanse_model.dart';
import 'expanse_repository.dart';

/// Changes an expense that was already registered.
///
/// There are two kinds of change here, and the screen decides which one it is
/// from what the manager touched:
///
/// Changing the kind, the date or the description says nothing about money, so
/// only the `expenses` row is written and the payment is left alone.
///
/// Changing the amount does say something about money — what was paid out is
/// no longer what the expense says — so the split has to be collected again
/// and the transaction rewritten with it. Asking to change the payment on its
/// own does the same thing without moving the amount.
///
/// Pops with `true` when something was saved, so the list behind it knows to
/// reload.
class UpdateExpanseScreen extends ConsumerStatefulWidget {
  final ExpanseModel expanse;

  const UpdateExpanseScreen({super.key, required this.expanse});

  @override
  ConsumerState<UpdateExpanseScreen> createState() =>
      _UpdateExpanseScreenState();
}

class _UpdateExpanseScreenState extends ConsumerState<UpdateExpanseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _expenseCostController;
  late final TextEditingController _expenseDateController;
  late final TextEditingController _descriptionController;

  late ExpanseType _expenseType;

  /// Set when the manager asks to redo the split without moving the amount.
  bool _changePaymentAsked = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final expanse = widget.expanse;

    _expenseType = expanse.expanseType;
    _expenseCostController = TextEditingController(
      text: expanse.expenseTotal.toStringAsFixed(2),
    );
    _expenseDateController = TextEditingController(
      text: AppDateUtil.formatDate(expanse.expenseDate),
    );
    _descriptionController = TextEditingController(
      text: expanse.description ?? '',
    );

    _expenseCostController.addListener(_onCostChanged);
  }

  @override
  void dispose() {
    _expenseCostController.removeListener(_onCostChanged);
    _expenseCostController.dispose();
    _expenseDateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  /// Redraws the payment notice as soon as the amount stops matching what was
  /// paid, so the manager sees what saving will ask of them before they save.
  void _onCostChanged() => setState(() {});

  double get _cost => double.tryParse(_expenseCostController.text.trim()) ?? 0;

  /// Money is compared in whole cents, the way the payment sheet compares it.
  bool get _isCostChanged =>
      (_cost * 100).round() != (widget.expanse.expenseTotal * 100).round();

  /// Whether saving has to collect the split again.
  bool get _willRewritePayment => _isCostChanged || _changePaymentAsked;

  String get _description => _descriptionController.text.trim();

  DateTime get _expenseDate =>
      DateTime.tryParse(_expenseDateController.text) ??
      widget.expanse.expenseDate;

  bool get _isChanged {
    final expanse = widget.expanse;

    return _expenseType != expanse.expanseType ||
        _description != (expanse.description ?? '') ||
        AppDateUtil.formatDate(_expenseDate) !=
            AppDateUtil.formatDate(expanse.expenseDate) ||
        _willRewritePayment;
  }

  ExpanseModel get _editedExpanse {
    return widget.expanse.copyWith(
      expanseType: _expenseType,
      description: _description.isEmpty ? null : _description,
      expenseDate: _expenseDate,
      expenseTotal: _cost,
    );
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_willRewritePayment) {
      await _saveWithPayment();
      return;
    }

    await _saveInfoOnly();
  }

  /// Nothing about the money moved, so only the expense row is written.
  Future<void> _saveInfoOnly() async {
    setState(() => _isSaving = true);

    try {
      await ExpanseRepository.updateExpanseInfo(expanse: _editedExpanse);

      if (!mounted) return;
      setState(() => _isSaving = false);
      _leaveWithSuccess("Kharashka waa la beddelay.");
    } catch (e) {
      _showFailure(e);
    }
  }

  /// The amount moved, or the split is being redone, so the payment is
  /// collected again and the transaction rewritten with it.
  Future<void> _saveWithPayment() async {
    final stadiumId = ref.read(stadiumNotifierProvider).value?.stadiumId;
    if (stadiumId == null) {
      await showAppErrorDialog(
        context: context,
        message: "Garoonkaaga lama helin. Fadlan mar kale isku day.",
      );
      return;
    }

    final expanse = _editedExpanse;

    final payment = await showPaymentSheet(
      context: context,
      requiredAmount: expanse.expenseTotal,
      title: "Lacag bixinta kharashka",
      confirmText: "Update",
      allowDiscount: false,
    );

    if (payment == null || !mounted) return;

    setState(() => _isSaving = true);

    try {
      await ExpanseRepository.updateExpanse(
        stadiumId: stadiumId,
        expanse: expanse,
        payments: payment.allocations,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);
      _leaveWithSuccess("Kharashka iyo lacag bixintiisa waa la beddelay.");
    } catch (e) {
      _showFailure(e);
    }
  }

  void _leaveWithSuccess(String message) {
    showSuccessSnackBar(context: context, message: message);
    Navigator.of(context).pop(true);
  }

  Future<void> _showFailure(Object error) async {
    if (!mounted) return;
    setState(() => _isSaving = false);

    // A rule the database refuses comes back with its own message, already
    // written for the manager.
    await showAppErrorDialog(
      context: context,
      title: "Wax lama beddelin",
      message: error is PostgrestException ? error.message : error.toString(),
    );
  }

  Future<void> _selectDate() async {
    final picked = await AppUtilityService.pickDate(
      context: context,
      initialDate: _expenseDate,
      // The stadium paid nothing out before it existed.
      firstDate: ref.read(stadiumFirstDateProvider),
      lastDate: DateTime.now(),
      helpText: "Taariikhda kharashka",
    );

    if (picked == null) return;

    setState(() {
      _expenseDateController.text = AppDateUtil.formatDate(picked);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Update Expense")),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildTypeField(),
                  const SizedBox(height: 12),
                  _buildCostField(),
                  const SizedBox(height: 12),
                  _buildDateField(),
                  const SizedBox(height: 12),
                  _buildDescriptionField(),
                  const SizedBox(height: 16),
                  _buildPaymentNotice(),
                  const SizedBox(height: 24),
                  _buildSaveButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeField() {
    return DropdownButtonFormField<ExpanseType>(
      initialValue: _expenseType,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: "Nooca kharashaadka",
        prefixIcon: Icon(Symbols.keyboard_option_key),
      ),
      items: [
        for (final type in ExpanseType.values)
          DropdownMenuItem(value: type, child: Text(type.label)),
      ],
      onChanged: _isSaving
          ? null
          : (type) => setState(() => _expenseType = type ?? _expenseType),
      validator: (v) => v == null ? "Dooro nooca kharashaadka" : null,
    );
  }

  Widget _buildCostField() {
    return AppInputTextWidget(
      controller: _expenseCostController,
      label: "Qiimaha lacagta",
      hintText: "0.00",
      prefixIcon: Symbols.attach_money,
      capitalize: false,
      enabled: !_isSaving,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        LengthLimitingTextInputFormatter(9),
      ],
      validator: (v) {
        final value = v?.trim() ?? '';
        if (value.isEmpty) return "Required";
        final cost = double.tryParse(value);
        if (cost == null) return "Enter a valid number";
        if (cost <= 0) return "Must be greater than 0";
        return null;
      },
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: _isSaving ? null : _selectDate,
      child: AbsorbPointer(
        child: AppInputTextWidget(
          controller: _expenseDateController,
          label: "Expense Date",
          prefixIcon: Symbols.calendar_month,
          suffixIcon: Symbols.edit_calendar,
          enabled: !_isSaving,
          validator: (v) => v == null || v.trim().isEmpty ? "Required" : null,
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return AppInputTextWidget(
      controller: _descriptionController,
      label: "Faah fahinta",
      hintText: "Wixii faahfahin ah halkan geli",
      prefixIcon: Symbols.notes,
      enabled: !_isSaving,
      maxLines: 3,
      maxLength: 100,
      onChanged: (_) => setState(() {}),
    );
  }

  /// Says plainly what saving will do to the payment, and lets the manager ask
  /// to redo the split even when the amount has not moved.
  Widget _buildPaymentNotice() {
    final theme = Theme.of(context);
    final willRewrite = _willRewritePayment;
    final color = willRewrite
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    final title = switch ((_isCostChanged, _changePaymentAsked)) {
      (true, _) =>
        "Lacagtu way beddelantay — lacag bixinta cusub ayaa la qori doonaa",
      (false, true) => "Lacag bixinta ayaa dib loo qaybin doonaa",
      _ => "Lacag bixintu sidii bay ahaan doontaa",
    };

    final subtitle = willRewrite
        ? "Marka aad keydiso, waxaa ku soo bixi doona meesha lacagtu ka baxday "
              "si aad dib u qeybiso."
        : "Waxaa la beddelayaa macluumaadka kharashka oo kaliya.";

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        color: Color.alphaBlend(
          color.withValues(alpha: 0.08),
          theme.colorScheme.surface,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                willRewrite ? Symbols.published_with_changes : Symbols.lock,
                size: 20,
                color: color,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: theme.textTheme.bodySmall),
          if (!_isCostChanged) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _isSaving
                    ? null
                    : () => setState(
                        () => _changePaymentAsked = !_changePaymentAsked,
                      ),
                icon: Icon(
                  _changePaymentAsked
                      ? Symbols.undo
                      : Symbols.account_balance_wallet,
                  size: 18,
                ),
                label: Text(
                  _changePaymentAsked
                      ? "Ha beddelin lacag bixinta"
                      : "Beddel lacag bixinta",
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      height: 48,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isSaving || !_isChanged ? null : _save,
        icon: _isSaving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(_willRewritePayment ? Symbols.payments : Symbols.save),
        label: Text(
          _willRewritePayment ? "Continue to payment" : "Save changes",
        ),
      ),
    );
  }
}
