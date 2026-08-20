import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:qabso_mobile/features/user/explore/widgets/explore_search_stadiums_widget.dart';

import '../../../utill/app_brand_widget.dart';
import '../../../utill/app_dailogs.dart';
import '../../../utill/notification_button_widget.dart';
import '../histoty/history_home_section_widget.dart';
import '../histoty/history_notifier_provider.dart';

class ExploreScreen extends ConsumerWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const AppBrandWidget(),
        titleSpacing: 16,
        actions: [
          TextButton.icon(
            onPressed: () {},
            icon: Icon(Symbols.feedback),
            label: Text("Feed back"),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(historyNotifierProvider.notifier).refresh(),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExploreSearchStadiumsWidget(),
                  SizedBox(height: 12),
                  HistoryHomeSectionWidget(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
