import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qabso_mobile/features/manager/home/manager_home_screen.dart';
import 'package:qabso_mobile/features/manager/stadium/stadium_notifier_provider.dart';
import 'package:qabso_mobile/features/manager/stadium/stadium_settings_screen.dart';
import 'package:shimmer/shimmer.dart';

import '../../utill/app_bottom_navigation.dart';
import '../../utill/error_widget.dart';
import '../auth/app_user_model.dart';
import '../auth/menu_items_model.dart';

class ManagerShell extends ConsumerStatefulWidget {
  const ManagerShell({super.key});

  @override
  ConsumerState<ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends ConsumerState<ManagerShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final items = menuItemsByRole[AppUserRole.manager]!;
    final theme = Theme.of(context);
    final stadiumAsync = ref.watch(stadiumNotifierProvider);

    final managerScreens = [
      ManagerHomeScreen(),
      Center(child: Text("data")),
      Center(child: Text("data")),
      StadiumSettingsScreen(),
    ];
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: stadiumAsync.when(
        data: (stadium) {
          if (stadium == null) {
            return Column(
              mainAxisAlignment: .center,
              children: [
                const Icon(Symbols.stadium, size: 64),
                const SizedBox(height: 12),
                Text(
                  "Stadium not exists",
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => StadiumSettingsScreen(),
                      ),
                    );
                  },
                  icon: Icon(Symbols.add),
                  label: Text("Create new stadium"),
                ),
              ],
            );
          }
          return Scaffold(
            body: managerScreens[_selectedIndex],
            bottomNavigationBar: AppBottomNavigation(
              items: items,
              selectedIndex: _selectedIndex,
              onItemSelected: (index) => setState(() => _selectedIndex = index),
            ),
          );
        },
        error: (error, stackTrace) => ErrorRetryWidget(
          errorMessage: error.toString(),
          onRetry: () => ref.read(stadiumNotifierProvider.notifier).refresh(),
        ),
        loading: () =>
            Scaffold(appBar: AppBar(title: _buildTitleShimmer(theme))),
      ),
    );
  }

  Widget _buildTitleShimmer(ThemeData theme) {
    return Shimmer.fromColors(
      baseColor: theme.hintColor.withValues(alpha: 0.5),
      highlightColor: Theme.of(context).cardColor,
      child: Container(
        height: 16,
        width: 120,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }
}
