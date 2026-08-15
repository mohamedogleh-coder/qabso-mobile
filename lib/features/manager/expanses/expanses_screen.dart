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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Center(
            // A wide window keeps the header and the cards together in the
            // middle instead of stretching them across the whole screen.
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 20),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: expansesMenuList.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Color.alphaBlend(
          colorScheme.primary.withValues(alpha: 0.10),
          colorScheme.surface,
        ),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Symbols.account_balance_wallet,
              fill: 1,
              size: 30,
              color: colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Expanses", style: theme.textTheme.headlineLarge),
                const SizedBox(height: 6),
                Text(
                  "Halkan waxaad ka diwaan gelin kartaa wixii kharashaad ah ee garoonka, "
                  "waxaanad ka eegtaa kuwii hore.",
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
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
