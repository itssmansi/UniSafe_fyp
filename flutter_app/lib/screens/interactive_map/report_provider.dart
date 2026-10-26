import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
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
  Future<Map<String, dynamic>> addReport(ReportModel report) async {
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
              .or('auth_user_id.eq.${authUser.id},id.eq.${authUser.id}')
              .maybeSingle();

          if (citizenRecord != null) {
            citizenId = citizenRecord['id']?.toString();
            citizenName = citizenRecord['name']?.toString();
          }
        } catch (e) {
          debugPrint('[InteractiveReportNotifier] Could not fetch citizen profile: $e');
        }
      }

      if (authUser == null || citizenId == null) {
        throw Exception('Your citizen profile is not linked. Please sign in again.');
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

      // Upload photos before submission so the server receives a usable URL.
      var submissionReport = enrichedReport;
      if (enrichedReport.imageBytes != null) {
        final imagePath = '${authUser.id}/${enrichedReport.id}.jpg';
        final storage = supabase.storage.from('complaint_images');
        await storage.uploadBinary(
          imagePath,
          enrichedReport.imageBytes!,
          fileOptions: FileOptions(contentType: 'image/jpeg'),
        );
        submissionReport = enrichedReport.copyWith(
          imagePath: storage.getPublicUrl(imagePath),
        );
      }

      // Route and save the complaint atomically through the Edge Function.
      final payload = submissionReport.toSupabase(reporterCitizenId: citizenId);
      final functionResponse = await supabase.functions.invoke(
        'submit-complaint',
        body: {
          ...payload,
          'address': submissionReport.address,
          'image_url': submissionReport.imagePath,
        },
      );
      final responseData = functionResponse.data;
      if (responseData is! Map || responseData['complaint'] is! Map) {
        throw Exception('The server did not confirm that this report was saved.');
      }
      final routedComplaint = Map<String, dynamic>.from(responseData['complaint'] as Map);

      // Add the report to the local map only after the server confirms the save.
      state = [submissionReport, ...state.where((r) => r.id != report.id)];

      try {
        await NotificationService.notifyComplaintSubmitted(
          complaintId: enrichedReport.id,
          title: enrichedReport.title,
          citizenId: citizenId,
        );
        final safetyCount = state.where((r) => r.category == IssueCategory.safety).length;
        if (enrichedReport.category == IssueCategory.safety && safetyCount >= 3) {
          await NotificationService.notifySafetyThresholdReached(
            zoneType: 'Safety & Hazard',
            reportCount: safetyCount,
            citizenId: citizenId,
          );
        }
      } catch (notificationError) {
        debugPrint('[InteractiveReportNotifier] Complaint saved but notification failed: $notificationError');
      }
      return routedComplaint;
    } catch (e) {
      debugPrint('[InteractiveReportNotifier] Error saving report to Supabase: $e');
      rethrow;
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
