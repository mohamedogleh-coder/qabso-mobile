import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:qabso_mobile/features/manager/fields/add_new_field_screen.dart';
import 'package:qabso_mobile/features/manager/fields/field_card_widget.dart';
import 'package:qabso_mobile/features/manager/fields/field_notifier_provider.dart';
import 'package:qabso_mobile/utill/error_widget.dart';
import 'package:qabso_mobile/utill/loading_widget.dart';

class FieldsScreen extends ConsumerStatefulWidget {
  const FieldsScreen({super.key});

  @override
  ConsumerState<FieldsScreen> createState() => _FieldsScreenState();
}

class _FieldsScreenState extends ConsumerState<FieldsScreen> {
  int expandedFieldId = 0;

  @override
  Widget build(BuildContext context) {
    final fieldsAsync = ref.watch(fieldNotifierProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text("Fields"),
        actions: [
          if (!fieldsAsync.isLoading && fieldsAsync.hasValue)
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => AddNewFieldScreen()),
                );
              },
              icon: Icon(Symbols.add),
              label: Text("Add new field"),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8),
        child: fieldsAsync.when(
          skipLoadingOnRefresh: false,
          data: (fields) {
            if (fields.isEmpty) {
              return Center(child: Text("Staduium has no fields"));
            }
            return RefreshIndicator(
              onRefresh: () async =>
                  ref.read(fieldNotifierProvider.notifier).refresh(),
              child: ListView.builder(
                itemCount: fields.length,
                itemBuilder: (context, index) =>
                    FieldCardWidget(model: fields[index]),
              ),
            );
          },
          error: (error, stackTrace) => ErrorRetryWidget(
            errorMessage: error.toString(),
            onRetry: () => ref.read(fieldNotifierProvider.notifier).refresh(),
          ),
          loading: () => LoadingWidget(),
        ),
      ),
    );
  }
}
