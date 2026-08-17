import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'stadium_model.dart';
import 'stadium_profile_provider.dart';
import 'stadium_working_days_provider.dart';
import 'widgets/stadium_profile_widget.dart';
import 'widgets/stadium_working_days_widget.dart';

/// The stadium a customer opened from their saved list.
///
/// Nothing is read from the database here yet. The stadium comes in from the
/// card that was tapped, which is all the screen needs to name itself, and
/// each tab holds an empty state until its own data is wired up.
class StadiumInformationScreen extends ConsumerStatefulWidget {
  final StadiumModel stadium;

  const StadiumInformationScreen({super.key, required this.stadium});

  @override
  ConsumerState<StadiumInformationScreen> createState() =>
      _StadiumInformationScreenState();
}

class _StadiumInformationScreenState
    extends ConsumerState<StadiumInformationScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// The four parts of a stadium, in the order the customer reads them.
  static const _tabs = <_StadiumTab>[
    _StadiumTab(
      icon: Symbols.info,
      label: "Profile",
      emptyTitle: "Stadium profile",
      emptyMessage: "Where the stadium is, and how it likes to be booked.",
    ),
    _StadiumTab(
      icon: Symbols.grass,
      label: "Fields",
      emptyTitle: "The fields",
      emptyMessage: "Every field with its pictures, its size and its price.",
    ),
    _StadiumTab(
      icon: Symbols.calendar_month,
      label: "Working days",
      emptyTitle: "Working days",
      emptyMessage: "The days the stadium opens, and the hours it plays.",
    ),
    _StadiumTab(
      icon: Symbols.account_balance_wallet,
      label: "Numbers",
      emptyTitle: "Payment numbers",
      emptyMessage: "The numbers this stadium takes its money on.",
    ),
  ];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: _tabs.length, vsync: this);

    // Holds the stadium's data for as long as this screen is open.
    //
    // TabBarView throws a tab's widget away once the user swipes far enough
    // from it, and without a listener the provider would go with it — so
    // coming back to the tab would read the stadium again. This listener is
    // closed for us when the screen is disposed, which is what lets the data
    // go then.
    final stadiumId = widget.stadium.stadiumId;

    if (stadiumId != null) {
      ref.listenManual(stadiumProfileProvider(stadiumId), (_, _) {});
      ref.listenManual(stadiumWorkingDaysProvider(stadiumId), (_, _) {});
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Text(
          widget.stadium.stadiumName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: _buildTabBar(),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProfileTab(),
          _buildEmptyTab(_tabs[1]),
          _buildWorkingDaysTab(),
          _buildEmptyTab(_tabs[3]),
        ],
      ),
    );
  }

  /// The icon sits over its label, and the selected tab is underlined. The
  /// underline is rounded and sized to the tab rather than the label, so it
  /// reads as one bar under the whole tab.
  PreferredSizeWidget _buildTabBar() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return TabBar(
      controller: _tabController,
      labelColor: colorScheme.primary,
      unselectedLabelColor: colorScheme.onSurfaceVariant,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: UnderlineTabIndicator(
        borderRadius: BorderRadius.circular(3),
        borderSide: BorderSide(width: 3, color: colorScheme.primary),
      ),
      labelStyle: theme.textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelStyle: theme.textTheme.bodySmall,
      tabs: [
        for (final tab in _tabs)
          Tab(
            height: 62,
            icon: Icon(tab.icon, size: 22, fill: 1),
            child: Text(
              tab.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  /// The Profile tab. The stadium id is all the widget needs — it reads its
  /// own data. A stadium that arrived without an id has nothing to read.
  Widget _buildProfileTab() {
    final stadiumId = widget.stadium.stadiumId;

    if (stadiumId == null) return _buildEmptyTab(_tabs.first);

    return StadiumProfileWidget(stadiumId: stadiumId);
  }

  /// The Working days tab, read the same way the Profile tab is.
  Widget _buildWorkingDaysTab() {
    final stadiumId = widget.stadium.stadiumId;

    if (stadiumId == null) return _buildEmptyTab(_tabs[2]);

    return StadiumWorkingDaysWidget(stadiumId: stadiumId);
  }

  /// What a tab shows until its data is wired up: the tab's own icon, what
  /// will live there, and one line saying what it is for.
  Widget _buildEmptyTab(_StadiumTab tab) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                tab.icon,
                size: 36,
                fill: 1,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tab.emptyTitle,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              tab.emptyMessage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// One tab: how it is labelled, and what its empty state says.
class _StadiumTab {
  final IconData icon;
  final String label;
  final String emptyTitle;
  final String emptyMessage;

  const _StadiumTab({
    required this.icon,
    required this.label,
    required this.emptyTitle,
    required this.emptyMessage,
  });
}
