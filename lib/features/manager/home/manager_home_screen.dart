import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../utill/app_brand_widget.dart';
import '../../../utill/app_constants.dart';
import '../../../utill/app_date_util.dart';
import '../../../utill/app_drawer.dart';
import '../../../utill/error_widget.dart';
import '../../auth/menu_items_model.dart';
import '../../auth/profile_screen.dart';
import '../../auth/user_avatar_widget.dart';
import '../stadium/stadium_model.dart';
import 'manager_home_model.dart';
import 'manager_home_notifier.dart';
import 'widgets/home_blockers_widget.dart';
import 'widgets/home_free_slots_widget.dart';
import 'widgets/home_next_game_widget.dart';
import 'widgets/home_refresh_countdown_widget.dart';
import 'widgets/home_shimmer_widget.dart';
import 'widgets/home_stats_widget.dart';

/// What is happening at the stadium right now.
///
/// Only today. What the stadium has earned is not here on purpose — takings
/// live in the reports, behind a deliberate tap, rather than on a screen
/// anyone standing nearby can read.
class ManagerHomeScreen extends ConsumerWidget {
  const ManagerHomeScreen({super.key, required this.stadium});

  final StadiumModel stadium;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeAsync = ref.watch(managerHomeNotifierProvider);

    return Scaffold(
      drawer: AppDrawer(items: managerMenuList, title: stadium.stadiumName),
      appBar: AppBar(
        title: const AppBrandWidget(),
        titleSpacing: 0,
        actions: [
          IconButton(onPressed: () {}, icon: Icon(Icons.search)),
          IconButton(onPressed: () {}, icon: Icon(Icons.help_outline)),

          // TextButton.icon(onPressed: (){}, label: Text("Feed back"),icon: Icon(Icons.feedback),),
          UserAvatarWidget(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: _buildBookFab(context),
      body: homeAsync.when(
        data: (home) => home == null
            ? _buildNoStadium(context)
            : _buildHome(context, ref, home),
        error: (error, stackTrace) {
          print(stackTrace);
          return ErrorRetryWidget(
            errorMessage: error is PostgrestException
                ? error.message
                : error.toString(),
            onRetry: () =>
                ref.read(managerHomeNotifierProvider.notifier).refresh(),
          );
        },

        loading: () => const HomeShimmerWidget(),
      ),
    );
  }

  Widget _buildHome(
    BuildContext context,
    WidgetRef ref,
    ManagerHomeModel home,
  ) {
    return RefreshIndicator(
      onRefresh: () => ref.read(managerHomeNotifierProvider.notifier).refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // The bottom padding is what keeps the last card clear of the
        // floating button rather than tucked underneath it.
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        children: [
          _buildGreeting(context),
          const SizedBox(height: 12),

          // What is stopping bookings comes before anything else, because
          // nothing else on the screen matters while it is true.
          if (!home.canTakeBookings) ...[
            HomeBlockersWidget(home: home),
            const SizedBox(height: 16),
          ],

          HomeNextGameWidget(home: home),
          const SizedBox(height: 12),
          HomeStatsWidget(home: home),
          const SizedBox(height: 12),

          // Last, and as big as the next game: what is still there to sell is
          // the other thing the manager can do something about today.
          HomeFreeSlotsWidget(home: home),
          const SizedBox(height: 20),

          // Says when the numbers above will next be checked, so a screen
          // left open on the desk is never silently out of date.
          Center(child: HomeRefreshCountdownWidget(restartOn: home)),
        ],
      ),
    );
  }

  /// The stadium and the day, so the numbers underneath have something to
  /// belong to.
  Widget _buildGreeting(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0,horizontal: 12),
        child: Column(
          // mainAxisAlignment: .spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Quick daily info",
              style: theme.textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              AppDateUtil.formatReadableDate(DateTime.now()),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The thing a manager at the desk does most, so it stays reachable however
  /// far the dashboard is scrolled. Bookings are taken from a field's slots,
  /// so it opens the fields.
  Widget _buildBookFab(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => Navigator.of(context).pushNamed(AppConstants.fields),
      icon: const Icon(Symbols.calendar_add_on),
      label: const Text("Qabo"),
    );
  }

  Widget _buildNoStadium(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Symbols.stadium,
              size: 56,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              "No stadium yet",
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
