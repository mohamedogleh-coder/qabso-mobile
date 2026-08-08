import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/app_user_model.dart';
import '../auth/app_user_notifer.dart';
import '../home/app_bottom_navigation.dart';
import '../home/menu_items_model.dart';
import '../home/placeholder_screen.dart';

class ManagerShell extends ConsumerStatefulWidget {
  const ManagerShell({super.key});

  @override
  ConsumerState<ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends ConsumerState<ManagerShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final appUser = ref.watch(appUserNotifierProvider).value;
    final appUserNotifier = ref.read(appUserNotifierProvider.notifier);
    final items = menuItemsByRole[AppUserRole.manager]!;

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
