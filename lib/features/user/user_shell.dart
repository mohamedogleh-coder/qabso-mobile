import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../utill/app_bottom_navigation.dart';
import '../auth/menu_items_model.dart';
import 'explore/explore_screen.dart';
import 'favourites/fav_stadiums_screen.dart';
import 'settings/user_settings_screen.dart';
import 'teams/teams_screen.dart';

final selectedIndexProvider = StateProvider<int>((ref) => 0);

class UserShell extends ConsumerStatefulWidget {
  const UserShell({super.key});

  @override
  ConsumerState<UserShell> createState() => _UserShellState();
}

class _UserShellState extends ConsumerState<UserShell> {
  static const _screens = [
    ExploreScreen(),
    FavStadiumsScreen(),
    TeamsScreen(),
    UserSettingsScreen(),
  ];


  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(selectedIndexProvider);
    final selectedIndexNotifier = ref.read(selectedIndexProvider.notifier);
    return Scaffold(
      body: IndexedStack(index: selectedIndex, children: _screens),
      bottomNavigationBar: AppBottomNavigation(
        items: userMenuList,
        selectedIndex: selectedIndex,
        onItemSelected: (index) =>
            setState(() => selectedIndexNotifier.state = index),
      ),
    );
  }
}
