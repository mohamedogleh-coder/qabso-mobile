import 'package:flutter/material.dart';

import '../features/auth/menu_items_model.dart';

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onItemSelected,
  });

  final List<MenuItemsModel> items;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onItemSelected,
      backgroundColor: colorScheme.surface,
      height: 72,
      destinations: [
        for (final item in items)
          NavigationDestination(
            icon: Icon(item.iconData, color: item.foregroundColor),
            selectedIcon: Icon(
              item.iconData,
              color: item.foregroundColor,
              fill: 1,
            ),
            label: item.label,
          ),
      ],
    );
  }
}
