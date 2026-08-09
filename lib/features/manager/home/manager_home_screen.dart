import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qabso_mobile/features/manager/stadium/stadium_notifier_provider.dart';

class ManagerHomeScreen extends ConsumerWidget {
  const ManagerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stadium = ref.watch(stadiumNotifierProvider).value;
    if (stadium == null) {
      return Center(child: Text("No stadium"));
    }
    return Scaffold(appBar: AppBar(title: Text(stadium.stadiumName)));
  }
}
