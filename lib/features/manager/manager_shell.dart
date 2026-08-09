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

    return stadiumAsync.when(
      data: (stadium) {
        if (stadium == null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Symbols.stadium, size: 64),
                    const SizedBox(height: 12),
                    Text(
                      "Stadium not exists",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      onPressed: () {
                        // push (not pushReplacement): keeps the shell on
                        // the stack so StadiumSettingsScreen's own submit
                        // handler has a route to pop back to on success.
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const StadiumSettingsScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Symbols.add),
                      label: const Text("Create new stadium"),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final managerScreens = [
          ManagerHomeScreen(stadium: stadium),
          const Center(child: Text("data")),
          const Center(child: Text("data")),
          StadiumSettingsScreen(stadiumModel: stadium),
        ];

        return Scaffold(
          body: managerScreens[_selectedIndex],
          bottomNavigationBar: AppBottomNavigation(
            items: items,
            selectedIndex: _selectedIndex,
            onItemSelected: (index) => setState(() => _selectedIndex = index),
          ),
        );
      },
      error: (error, stackTrace) => Scaffold(
        body: ErrorRetryWidget(
          errorMessage: error.toString(),
          onRetry: () => ref.read(stadiumNotifierProvider.notifier).refresh(),
        ),
      ),
      loading: () => Scaffold(appBar: AppBar(title: _buildTitleShimmer(theme))),
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
