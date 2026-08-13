import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:qabso_mobile/features/auth/menu_items_model.dart';

import '../../../../utill/app_constants.dart';

class ReportsModel extends MenuItemsModel {
  final String description;

  const ReportsModel({
    required super.iconData,
    required super.label,
    required super.backgroundColor,
    required super.foregroundColor,
    required super.path,
    required this.description,
  });
}

final reportsList = [
  ReportsModel(
    iconData: Symbols.analytics,
    label: "Events Report",
    backgroundColor: const Color(0xFFEEF2FF),
    foregroundColor: const Color(0xFF4F46E5),
    path: AppConstants.eventsReport,
    description: "Booking summery for every field",
  ),

  ReportsModel(
    iconData: Symbols.payments,
    label: "Expanses Report",
    backgroundColor: const Color(0xFFFFF1F2),
    foregroundColor: const Color(0xFFE11D48),
    path: AppConstants.expansesReport,
    description: "Expanses list",
  ),

  ReportsModel(
    iconData: Symbols.account_balance_wallet_sharp,
    label: "Merchants Report",
    backgroundColor: const Color(0xFFECFDF5),
    foregroundColor: const Color(0xFF059669),
    path: AppConstants.merchantsReport,
    description: "Money in every merchant",
  ),
];
