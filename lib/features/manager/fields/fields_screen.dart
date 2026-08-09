import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qabso_mobile/features/manager/fields/field_notifier_provider.dart';
import 'package:qabso_mobile/utill/error_widget.dart';
import 'package:qabso_mobile/utill/loading_widget.dart';

class FieldsScreen extends ConsumerWidget {
  const FieldsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fieldsAsync = ref.watch(fieldNotifierProvider);
    return Scaffold(
      appBar: AppBar(title: Text("Fields")),
      body: fieldsAsync.when(
        skipLoadingOnRefresh: false,
        data: (fields){
          if(fields.isEmpty){
            return Center(child: Text("Staduium has no fields"),);
          }
          return Text("Data");
        },
        error: (error, stackTrace) => ErrorRetryWidget(
          errorMessage: error.toString(),
          onRetry: () => ref.read(fieldNotifierProvider.notifier).refresh(),
        ),
        loading: () => LoadingWidget(),
      ),
    );
  }
}
