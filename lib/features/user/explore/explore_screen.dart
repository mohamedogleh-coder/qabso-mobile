import 'package:flutter/material.dart';
import 'package:qabso_mobile/features/user/explore/widgets/explore_search_stadiums_widget.dart';

import '../../../utill/app_brand_widget.dart';
import '../../../utill/app_dailogs.dart';
import '../../../utill/notification_button_widget.dart';
import '../../auth/profile_screen.dart';
import '../../auth/user_avatar_widget.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppBrandWidget(),
        titleSpacing: 16,
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
      body: Column(children: [ExploreSearchStadiumsWidget()],),
    );
  }
}
