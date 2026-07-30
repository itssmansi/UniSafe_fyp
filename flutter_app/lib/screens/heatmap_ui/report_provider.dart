import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/report_model.dart';

class ReportNotifier extends Notifier<List<ReportModel>> {
  @override
  List<ReportModel> build() {
    return [];
  }

  void addReport(ReportModel report) {
    state = [...state, report];
  }
}

final reportProvider = NotifierProvider<ReportNotifier, List<ReportModel>>(() {
  return ReportNotifier();
});
