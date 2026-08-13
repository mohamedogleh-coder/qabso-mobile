import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../features/auth/menu_items_model.dart';
import 'app_constants.dart';
import 'app_dailogs.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.items, this.title});

  final List<MenuItemsModel> items;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Drawer(
      backgroundColor: colorScheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final item in items) _buildMenuTile(context, item),
                ],
              ),
            ),
            const Divider(height: 1),
            _buildLogoutTile(context),
            _buildVersion(context),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppConstants.primary.withValues(alpha: 0.15),
            child: const Icon(Icons.sports_soccer, color: AppConstants.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title ?? AppConstants.appName,
              style: theme.textTheme.bodyLarge!.copyWith(
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(BuildContext context, MenuItemsModel item) {
    return ListTile(
      leading: Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          color: item.backgroundColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(item.iconData, color: item.foregroundColor, size: 22),
      ),
      title: Text(item.label, style: Theme.of(context).textTheme.bodyLarge),
      onTap: () => _openItem(context, item),
    );
  }

  Widget _buildLogoutTile(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        height: 40,
        width: 40,
        decoration: BoxDecoration(
          color: colorScheme.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.logout, color: colorScheme.error, size: 22),
      ),
      title: Text(
        "Logout",
        style: Theme.of(
          context,
        ).textTheme.bodyLarge!.copyWith(color: colorScheme.error),
      ),
      onTap: () => _confirmLogout(context),
    );
  }

  Widget _buildVersion(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodySmall;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: Row(
        mainAxisAlignment: .center,
        children: [
          Text(AppConstants.appName, style: textStyle),
          const SizedBox(width: 12),
          Text(AppConstants.appVersion, style: textStyle),
        ],
      ),
    );
  }

  void _openItem(BuildContext context, MenuItemsModel item) {
    if (item.path == AppConstants.dashboard) return;
    Navigator.pushNamed(context, item.path);
  }

  Future<void> _confirmLogout(BuildContext context) async {
    await showAppConfirmationDialog(
      context: context,
      title: "Logout",
      message: "Are you sure you want to logout?",
      confirmText: "Logout",
      isDestructive: true,
      icon: Icons.logout,
      onConfirm: () => Supabase.instance.client.auth.signOut(),
    );
  }
}
