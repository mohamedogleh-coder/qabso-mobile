import 'package:flutter/material.dart';
import 'package:qabso_mobile/features/manager/reports/models/reports_model.dart';
import 'package:qabso_mobile/features/manager/reports/widgets/report_card_widget.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Reports")),
      body: SafeArea(
        child: GridView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: reportsList.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 150,
          ),
          itemBuilder: (context, index) {
            final report = reportsList[index];
            return ReportCardWidget(
              model: report,
              onTap: () => Navigator.pushNamed(context, report.path),
            );
          },
        ),
      ),
    );
  }
}
