import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class NotificationButtonWidget extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const NotificationButtonWidget({super.key, this.count = 0, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return badges.Badge(
      showBadge: count > 0,
      position: badges.BadgePosition.topEnd(top: 2, end: 2),
      badgeAnimation: const badges.BadgeAnimation.scale(
        animationDuration: Duration(milliseconds: 200),
      ),
      badgeStyle: badges.BadgeStyle(
        shape: badges.BadgeShape.circle,
        badgeColor: theme.colorScheme.error,
        padding: const EdgeInsets.all(5),
        elevation: 0,
        // Cuts the badge away from the bell behind it, so the two never blur
        // into one shape.
        borderSide: BorderSide(color: theme.colorScheme.surface, width: 1.5),
      ),
      badgeContent: Text(
        count > 99 ? "99+" : "$count",
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onError,
          fontWeight: FontWeight.bold,
          height: 1,
        ),
      ),
      child: IconButton(
        onPressed: onTap,
        tooltip: "Notifications",
        icon: Icon(Symbols.notifications, fill: count > 0 ? 1 : 0),
      ),
    );
  }
}
