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
import 'expanse_model.dart';
import 'expanse_repository.dart';

class AddExpanseScreen extends ConsumerStatefulWidget {
  const AddExpanseScreen({super.key});

  @override
  ConsumerState<AddExpanseScreen> createState() => _AddExpanseScreenState();
}

class _AddExpanseScreenState extends ConsumerState<AddExpanseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _expenseCostController = TextEditingController();
  final _expenseDateController = TextEditingController();
  final _descriptionController = TextEditingController();

  ExpanseType _expenseType = ExpanseType.expense;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _expenseDateController.text = AppDateUtil.formatDate(DateTime.now());
  }

  @override
  void dispose() {
    _expenseCostController.dispose();
    _expenseDateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _registerExpense() async {
    if (_isSaving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final stadiumId = ref.read(stadiumNotifierProvider).value?.stadiumId;
    if (stadiumId == null) {
      await showAppErrorDialog(
        context: context,
        message: "Garoonkaaga lama helin. Fadlan mar kale isku day.",
      );
      return;
    }

    final description = _descriptionController.text.trim();

    final expense = ExpanseModel(
      expanseType: _expenseType,
      description: description.isEmpty ? null : description,
      expenseDate:
          DateTime.tryParse(_expenseDateController.text) ?? DateTime.now(),
      expenseTotal: double.parse(_expenseCostController.text.trim()),
    );

    final payment = await showPaymentSheet(
      context: context,
      requiredAmount: expense.expenseTotal,
      title: "Lacag bixinta kharashka",
      confirmText: "Register",
      allowDiscount: false,
    );

    if (payment == null || !mounted) return;

    setState(() => _isSaving = true);

    try {
      await ExpanseRepository.addExpanse(
        stadiumId: stadiumId,
        expanse: expense,
        payments: payment.allocations,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      await _showSavedDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);

      await showAppErrorDialog(
        context: context,
        title: "Kharashku ma diwaan gelin",
        message: e is PostgrestException ? e.message : e.toString(),
      );
    }
  }

  Future<void> _showSavedDialog() async {
    final registerAnother = await showAppConfirmationDialog(
      context: context,
      title: "Expanse registered",
      message: "Ma rabtaa inaad diwaan geliso kharashaad cusub",
      confirmText: "Register new expanse",
      cancelText: "No,Thanks",
      icon: Symbols.check_circle,
      barrierDismissible: false,
    );

    if (!mounted) return;

    if (registerAnother) {
      _clearForm();
      return;
    }

    Navigator.of(context).pop();
  }

  void _clearForm() {
    _formKey.currentState?.reset();
    _expenseCostController.clear();
    _descriptionController.clear();

    setState(() {
      _expenseDateController.text = AppDateUtil.formatDate(DateTime.now());
    });
  }

  Future<void> _selectDate() async {
    final picked = await AppUtilityService.pickDate(
      context: context,
      initialDate:
          DateTime.tryParse(_expenseDateController.text) ?? DateTime.now(),
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
      appBar: AppBar(title: const Text("Register Expense")),
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
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: "Nooca kharashaadka",
        prefixIcon: Icon(Symbols.keyboard_option_key),
      ),
      items: [
        for (final type in ExpanseType.values)
          DropdownMenuItem(value: type, child: Text(_typeLabel(type))),
      ],
      onChanged: _isSaving
          ? null
          : (type) => setState(() => _expenseType = type ?? _expenseType),
      validator: (v) {
        if (v == null) return "Dooro nooca kharashaadka";
        return null;
      },
    );
  }

  Widget _buildCostField() {
    return AppInputTextWidget(
      controller: _expenseCostController,
      label: "Qiimaha lacagta",
      hintText: "0.00",
      prefixIcon: Symbols.attach_money,
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
      hintText: "Wixii faahfahin ah halakan geli",
      prefixIcon: Symbols.notes,
      enabled: !_isSaving,
      maxLines: 3,
      maxLength: 100,
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isSaving ? null : _registerExpense,
        icon: _isSaving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Symbols.payment),
        label: const Text("Go to Expanse Payment"),
      ),
    );
  }

  String _typeLabel(ExpanseType type) {
    return switch (type) {
      ExpanseType.salary => "Salary",
      ExpanseType.expense => "Expense",
      // ExpanseType.other => "Other",
    };
  }
}
