import 'package:flutter/material.dart';

import '../../../utill/app_brand_widget.dart';
import '../../../utill/app_dailogs.dart';
import '../../../utill/notification_button_widget.dart';
import '../../auth/profile_screen.dart';
import '../../auth/user_avatar_widget.dart';

class TeamsScreen extends StatelessWidget {
  const TeamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
