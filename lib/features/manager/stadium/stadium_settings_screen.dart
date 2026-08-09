import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qabso_mobile/features/manager/stadium/stadium_model.dart';

class StadiumSettingsScreen extends ConsumerStatefulWidget {
  final StadiumModel? stadiumModel;

  const StadiumSettingsScreen({super.key, this.stadiumModel});

  @override
  ConsumerState<StadiumSettingsScreen> createState() =>
      _StadiumSettingsScreenState();
}

class _StadiumSettingsScreenState extends ConsumerState<StadiumSettingsScreen> {
  @override
  Widget build(BuildContext context) {
     return Scaffold(
      appBar: AppBar(title: Text("Settings")),
      body: Column(children: []),
    );
  }
}
