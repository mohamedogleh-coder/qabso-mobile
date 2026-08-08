import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

import '../../utill/app_constants.dart';
import '../auth/app_user_model.dart';

class MenuItemsModel {
  final IconData iconData;
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final String path;

  const MenuItemsModel({
    required this.iconData,
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.path,
  });
}

final managerMenuList = [
  MenuItemsModel(
    iconData: Symbols.home,
    label: "Home",
    backgroundColor: const Color(0xFFE8F1FF),
    foregroundColor: const Color(0xFF2563EB),
    path: AppConstants.dashboard,
  ),

  MenuItemsModel(
    iconData: Symbols.grass,
    label: "Fields",
    backgroundColor: const Color(0xFFF1F8E9),
    foregroundColor: const Color(0xFF689F38),
    path: AppConstants.fields,
  ),

  MenuItemsModel(
    iconData: Symbols.calendar_clock,
    label: "Events",
    backgroundColor: const Color(0xFFF3E5F5),
    foregroundColor: const Color(0xFF8E24AA),
    path: AppConstants.events,
  ),
  MenuItemsModel(
    iconData: Symbols.settings,
    label: "Settings",
    backgroundColor: const Color(0xFFFFF8E1),
    foregroundColor: const Color(0xFFF9A825),
    path: AppConstants.workingDays,
  ),
];

final userMenuList = [
  MenuItemsModel(
    iconData: Symbols.search,
    label: "Explore",
    backgroundColor: const Color(0xFFE8F1FF),
    foregroundColor: const Color(0xFF2563EB),
    path: AppConstants.dashboard,
  ),

  MenuItemsModel(
    iconData: Symbols.history,
    label: "Fav stadiums",
    backgroundColor: const Color(0xFFF1F8E9),
    foregroundColor: const Color(0xFF689F38),
    path: AppConstants.fields,
  ),

  MenuItemsModel(
    iconData: Symbols.group,
    label: "Teams",
    backgroundColor: const Color(0xFFF3E5F5),
    foregroundColor: const Color(0xFF8E24AA),
    path: AppConstants.events,
  ),
  MenuItemsModel(
    iconData: Symbols.settings,
    label: "Settings",
    backgroundColor: const Color(0xFFFFF8E1),
    foregroundColor: const Color(0xFFF9A825),
    path: AppConstants.workingDays,
  ),
];

final Map<AppUserRole, List<MenuItemsModel>> menuItemsByRole = {
  AppUserRole.user: userMenuList,
  AppUserRole.manager: managerMenuList,
};
