import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'report_model.dart';

class InteractiveReportNotifier extends Notifier<List<ReportModel>> {
  @override
  List<ReportModel> build() {
    return [];
  }

  void addReport(ReportModel report) {
    state = [...state, report];
  }

  void updateReport(ReportModel updatedReport) {
    state = [
      for (final report in state)
        if (report.id == updatedReport.id) updatedReport else report,
    ];
  }

  void deleteReport(String id) {
    state = state.where((r) => r.id != id).toList();
  }
}

final interactiveReportProvider = NotifierProvider<InteractiveReportNotifier, List<ReportModel>>(() {
  return InteractiveReportNotifier();
});
