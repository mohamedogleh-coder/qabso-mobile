import 'package:flutter/material.dart';

import '../auth/menu_items_model.dart';
import '../auth/user_avatar_widget.dart';

class UserBottomNavigation extends StatelessWidget {
  const UserBottomNavigation({
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
    final lastIndex = items.length - 1;

    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onItemSelected,
      backgroundColor: colorScheme.surface,
      height: 72,
      destinations: [
        for (final (index, item) in items.indexed)
          if (index == lastIndex)
            NavigationDestination(
              icon: const UserAvatarWidget(radius: 13),
              label: item.label,
            )
          else
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
