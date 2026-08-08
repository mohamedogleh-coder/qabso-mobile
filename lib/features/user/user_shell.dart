import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/app_user_model.dart';
import '../auth/app_user_notifer.dart';
import '../home/app_bottom_navigation.dart';
import '../home/menu_items_model.dart';
import '../home/placeholder_screen.dart';

class UserShell extends ConsumerStatefulWidget {
  const UserShell({super.key});

  @override
  ConsumerState<UserShell> createState() => _UserShellState();
}

class _UserShellState extends ConsumerState<UserShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(appUserNotifierProvider).value;
    final items = menuItemsByRole[AppUserRole.user]!;
    return Scaffold(
      appBar: AppBar(
        title: Text(items[_selectedIndex].label),
        actions: [
          IconButton(
            onPressed: () async {
              await Supabase.instance.client.auth.signOut();
            },
            icon: Icon(Symbols.exit_to_app),
          ),
        ],
      ),
      body: PlaceholderScreen(title: items[_selectedIndex].label),
      bottomNavigationBar: AppBottomNavigation(
        items: items,
        selectedIndex: _selectedIndex,
        onItemSelected: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}
