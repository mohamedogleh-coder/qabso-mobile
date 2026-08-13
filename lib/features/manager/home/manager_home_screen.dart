import 'package:flutter/material.dart';

import '../../../utill/app_drawer.dart';
import '../../auth/menu_items_model.dart';
import '../stadium/stadium_model.dart';

class ManagerHomeScreen extends StatelessWidget {
  const ManagerHomeScreen({super.key, required this.stadium});

  final StadiumModel stadium;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(items: managerMenuList, title: stadium.stadiumName),
      appBar: AppBar(titleSpacing: 2,title: Text(stadium.stadiumName)),
    );
  }
}
