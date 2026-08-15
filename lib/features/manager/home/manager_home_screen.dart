import 'package:flutter/material.dart';

import '../../../utill/app_brand_widget.dart';
import '../../../utill/app_dailogs.dart';
import '../../../utill/app_drawer.dart';
import '../../../utill/notification_button_widget.dart';
import '../../auth/menu_items_model.dart';
import '../../auth/profile_screen.dart';
import '../../auth/user_avatar_widget.dart';
import '../stadium/stadium_model.dart';

class ManagerHomeScreen extends StatelessWidget {
  const ManagerHomeScreen({super.key, required this.stadium});

  final StadiumModel stadium;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(items: managerMenuList, title: stadium.stadiumName),
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
    );
  }
}
