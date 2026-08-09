import 'package:flutter/material.dart';

import '../stadium/stadium_model.dart';

class ManagerHomeScreen extends StatelessWidget {
  const ManagerHomeScreen({super.key, required this.stadium});

  final StadiumModel stadium;

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text(stadium.stadiumName)));
  }
}
