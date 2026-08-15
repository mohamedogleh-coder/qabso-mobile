import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../utill/app_brand_widget.dart';
import '../../../utill/app_dailogs.dart';
import '../../../utill/notification_button_widget.dart';
import '../../auth/profile_screen.dart';
import '../../auth/user_avatar_widget.dart';

class UserSettingsScreen extends StatelessWidget {
  const UserSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppBrandWidget(),
        titleSpacing: 0,
        actions: [
          NotificationButtonWidget(
            onTap: () => showNotImplementedDialog(context: context),
          ),
          UserAvatarWidget(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Symbols.logout),
            title: const Text("Logout"),
            onTap: () => _confirmLogout(context),
          ),
        ],
      ),
    );
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
