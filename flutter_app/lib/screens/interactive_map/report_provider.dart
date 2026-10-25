import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/supabase_config.dart';
import '../../services/notification_service.dart';
import 'report_model.dart';

class InteractiveReportNotifier extends Notifier<List<ReportModel>> {
  @override
  List<ReportModel> build() {
    _loadReportsFromSupabase();
    return [];
  }

  /// Loads all stored complaints from Supabase and joins the reporting citizen profile.
  Future<void> _loadReportsFromSupabase() async {
    try {
      final response = await SupabaseConfig.client
          .from('complaints')
          .select('*, citizens(name, phone)')
          .order('created_at', ascending: false);

      final list = (response as List)
          .map((row) => ReportModel.fromSupabase(Map<String, dynamic>.from(row)))
          .toList();

      state = list;
    } catch (e) {
      debugPrint('[InteractiveReportNotifier] Error loading complaints from Supabase: $e');
    }
  }

  /// Adds a new report both in state and in the Supabase complaints table with citizen credentials.
  Future<void> addReport(ReportModel report) async {
    // 1. Snappy UI: Optimistically add to state immediately
    state = [report, ...state.where((r) => r.id != report.id)];

    try {
      final supabase = SupabaseConfig.client;
      final authUser = supabase.auth.currentUser;
      String? citizenId;
      String? citizenName;

      // 2. Fetch logged-in citizen credentials if available
      if (authUser != null) {
        try {
          final citizenRecord = await supabase
              .from('citizens')
              .select('id, name')
              .eq('auth_user_id', authUser.id)
              .maybeSingle();

          if (citizenRecord != null) {
            citizenId = citizenRecord['id']?.toString();
            citizenName = citizenRecord['name']?.toString();
          }
        } catch (e) {
          debugPrint('[InteractiveReportNotifier] Could not fetch citizen profile: $e');
        }
      }

      // 3. Attach citizen credentials to the report model
      final enrichedReport = report.copyWith(
        citizenId: citizenId,
        citizenName: citizenName,
      );

      // Update local state with the enriched credentials
      state = [
        for (final r in state)
          if (r.id == report.id) enrichedReport else r,
      ];

      // 4. Save to Supabase 'complaints' table
      final payload = enrichedReport.toSupabase(reporterCitizenId: citizenId);
      await supabase.from('complaints').insert(payload);

      // 5. Notify citizen of successful complaint submission
      await NotificationService.notifyComplaintSubmitted(
        complaintId: enrichedReport.id,
        title: enrichedReport.title,
        citizenId: citizenId,
      );

      // 6. Safety threshold alert if density or recurring reports in safety category
      final safetyCount = state.where((r) => r.category == IssueCategory.safety).length;
      if (enrichedReport.category == IssueCategory.safety && safetyCount >= 3) {
        await NotificationService.notifySafetyThresholdReached(
          zoneType: 'Safety & Hazard',
          reportCount: safetyCount,
          citizenId: citizenId,
        );
      }
    } catch (e) {
      debugPrint('[InteractiveReportNotifier] Error saving report to Supabase: $e');
    }
  }

  /// Updates an existing report (e.g. location drag or status change) and syncs to Supabase.
  Future<void> updateReport(ReportModel updatedReport) async {
    final oldReport = state.firstWhere(
      (r) => r.id == updatedReport.id,
      orElse: () => updatedReport,
    );
    final statusChanged = oldReport.status.toLowerCase() != updatedReport.status.toLowerCase();

    state = [
      for (final report in state)
        if (report.id == updatedReport.id) updatedReport else report,
    ];

    try {
      await SupabaseConfig.client.from('complaints').update({
        'latitude': updatedReport.location.latitude,
        'longitude': updatedReport.location.longitude,
        'upvote_count': updatedReport.upvoteCount,
        'status': updatedReport.status,
      }).eq('id', updatedReport.id);

      // Trigger status update or resolution notification if status changed
      if (statusChanged) {
        if (updatedReport.status.toLowerCase() == 'resolved') {
          await NotificationService.notifyComplaintResolved(
            complaintId: updatedReport.id,
            title: updatedReport.title,
            citizenId: updatedReport.citizenId,
          );
        } else {
          await NotificationService.notifyComplaintStatusChanged(
            complaintId: updatedReport.id,
            title: updatedReport.title,
            newStatus: updatedReport.status,
            citizenId: updatedReport.citizenId,
          );
        }
      }
    } catch (e) {
      debugPrint('[InteractiveReportNotifier] Error updating complaint in Supabase: $e');
    }
  }

  /// Deletes a report locally and removes it from Supabase.
  Future<void> deleteReport(String id) async {
    state = state.where((r) => r.id != id).toList();

    try {
      await SupabaseConfig.client.from('complaints').delete().eq('id', id);
    } catch (e) {
      debugPrint('[InteractiveReportNotifier] Error deleting complaint from Supabase: $e');
    }
  }

  /// Reloads reports from the database manually.
  Future<void> refreshReports() async {
    await _loadReportsFromSupabase();
  }
}

final interactiveReportProvider = NotifierProvider<InteractiveReportNotifier, List<ReportModel>>(() {
  return InteractiveReportNotifier();
});
