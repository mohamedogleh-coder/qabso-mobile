import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../../utill/app_constants.dart';
import '../reports/models/reports_model.dart';
import '../reports/widgets/report_card_widget.dart';

/// The expenses menu: what a manager can do with expenses, one card each.
///
/// Built the same way as the reports screen, so both drawer entries that lead
/// to more than one screen behave the same.
class ExpansesScreen extends StatelessWidget {
  const ExpansesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Expanses")),
      body: SafeArea(
        child: GridView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: expansesMenuList.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 150,
          ),
          itemBuilder: (context, index) {
            final menu = expansesMenuList[index];
            return ReportCardWidget(
              model: menu,
              onTap: () => Navigator.pushNamed(context, menu.path),
            );
          },
        ),
      ),
    );
  }
}

final expansesMenuList = [
  ReportsModel(
    iconData: Symbols.add_card,
    label: "Add Expanse",
    backgroundColor: const Color(0xFFFFF1F2),
    foregroundColor: const Color(0xFFE11D48),
    path: AppConstants.addExpense,
    description: "Diwaan geli kharash cusub",
  ),

  ReportsModel(
    iconData: Symbols.receipt_long,
    label: "List Expanses",
    backgroundColor: const Color(0xFFEEF2FF),
    foregroundColor: const Color(0xFF4F46E5),
    path: AppConstants.expensesList,
    description: "Kharashaadka la diwaan geliyay",
  ),
];
