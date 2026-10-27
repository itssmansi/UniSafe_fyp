import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../../services/device_service.dart';
import 'report_model.dart';

class InteractiveReportNotifier extends Notifier<List<ReportModel>> {
  RealtimeChannel? _complaintsChannel;

  @override
  List<ReportModel> build() {
    _loadReportsFromSupabase();
    _subscribeToRealtime();

    ref.onDispose(() {
      _complaintsChannel?.unsubscribe();
    });

    return [];
  }

  /// Loads all stored complaints from Supabase and joins the reporting citizen profile.
  Future<void> _loadReportsFromSupabase() async {
    try {
      dynamic response;
      try {
        response = await SupabaseConfig.client
            .from('complaints')
            .select('*, citizens(name, phone)')
            .order('created_at', ascending: false);
      } catch (joinErr) {
        debugPrint('[InteractiveReportNotifier] Joined query failed, falling back to direct select: $joinErr');
        response = await SupabaseConfig.client
            .from('complaints')
            .select('*')
            .order('created_at', ascending: false);
      }

      final list = (response as List)
          .map((row) => ReportModel.fromSupabase(Map<String, dynamic>.from(row)))
          .toList();

      state = list;
    } catch (e) {
      debugPrint('[InteractiveReportNotifier] Error loading complaints from Supabase: $e');
    }
  }

  /// Subscribes to Supabase Realtime for live cross-device synchronization.
  void _subscribeToRealtime() {
    try {
      _complaintsChannel?.unsubscribe();

      _complaintsChannel = SupabaseConfig.client
          .channel('public:complaints:realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'complaints',
            callback: (payload) async {
              debugPrint('[Realtime] complaints change: ${payload.eventType}');
              switch (payload.eventType) {
                case PostgresChangeEvent.insert:
                  final newRecord = payload.newRecord;
                  final reportId = newRecord['id']?.toString();
                  if (reportId == null) return;

                  try {
                    // Fetch enriched complaint with joined citizen profile
                    final row = await SupabaseConfig.client
                        .from('complaints')
                        .select('*, citizens(name, phone)')
                        .eq('id', reportId)
                        .maybeSingle();

                    if (row != null) {
                      final newReport = ReportModel.fromSupabase(row);
                      final existingIdx = state.indexWhere((r) => r.id == newReport.id);
                      if (existingIdx != -1) {
                        state = [
                          for (int i = 0; i < state.length; i++)
                            if (i == existingIdx) newReport else state[i],
                        ];
                      } else {
                        state = [newReport, ...state];
                      }
                    }
                  } catch (e) {
                    final newReport = ReportModel.fromSupabase(newRecord);
                    final existingIdx = state.indexWhere((r) => r.id == newReport.id);
                    if (existingIdx == -1) {
                      state = [newReport, ...state];
                    }
                  }
                  break;

                case PostgresChangeEvent.update:
                  final updatedRecord = payload.newRecord;
                  final reportId = updatedRecord['id']?.toString();
                  if (reportId == null) return;

                  final existingIdx = state.indexWhere((r) => r.id == reportId);
                  if (existingIdx != -1) {
                    final current = state[existingIdx];
                    final newUpvoteCount = (updatedRecord['upvote_count'] as num?)?.toInt() ?? current.upvoteCount;
                    final newStatus = updatedRecord['status']?.toString() ?? current.status;
                    final newLat = (updatedRecord['latitude'] as num?)?.toDouble() ?? current.location.latitude;
                    final newLng = (updatedRecord['longitude'] as num?)?.toDouble() ?? current.location.longitude;

                    final newAuthUserId = updatedRecord['auth_user_id']?.toString() ?? current.authUserId;

                    final updated = current.copyWith(
                      upvoteCount: newUpvoteCount,
                      status: newStatus,
                      location: LatLng(newLat, newLng),
                      authUserId: newAuthUserId,
                    );

                    state = [
                      for (int i = 0; i < state.length; i++)
                        if (i == existingIdx) updated else state[i],
                    ];
                  } else {
                    _loadReportsFromSupabase();
                  }
                  break;

                case PostgresChangeEvent.delete:
                  final oldRecord = payload.oldRecord;
                  final reportId = oldRecord['id']?.toString();
                  if (reportId != null) {
                    state = state.where((r) => r.id != reportId).toList();
                  }
                  break;
                default:
                  break;
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[InteractiveReportNotifier] Realtime subscription error: $e');
    }
  }

  /// Adds a new report both in state and in the Supabase complaints table with citizen credentials.
  Future<void> addReport(ReportModel report) async {
    // 1. Mark report as created on this device immediately
    await DeviceService.saveMyReportId(report.id);

    // 2. Snappy UI: Optimistically add to state immediately
    state = [report, ...state.where((r) => r.id != report.id)];

    try {
      final supabase = SupabaseConfig.client;
      final authUser = supabase.auth.currentUser;
      String? citizenId;
      String? citizenName;

      // 3. Fetch logged-in citizen credentials if available
      if (authUser != null) {
        try {
          var query = supabase.from('citizens').select('id, name');
          if (authUser.email != null && authUser.email!.isNotEmpty) {
            query = query.or('auth_user_id.eq.${authUser.id},email.eq.${authUser.email}');
          } else if (authUser.phone != null && authUser.phone!.isNotEmpty) {
            query = query.or('auth_user_id.eq.${authUser.id},phone.eq.${authUser.phone}');
          } else {
            query = query.eq('auth_user_id', authUser.id);
          }
          final citizenRecord = await query.maybeSingle();

          if (citizenRecord != null) {
            citizenId = citizenRecord['id']?.toString();
            citizenName = citizenRecord['name']?.toString();
          }
        } catch (e) {
          debugPrint('[InteractiveReportNotifier] Could not fetch citizen profile: $e');
        }
      }

      // 4. Attach citizen credentials and auth user ID to the report model
      final enrichedReport = report.copyWith(
        citizenId: citizenId,
        citizenName: citizenName,
        authUserId: authUser?.id,
      );

      // Update local state with the enriched credentials
      state = [
        for (final r in state)
          if (r.id == report.id) enrichedReport else r,
      ];

      // 5. Save to Supabase 'complaints' table
      final payload = enrichedReport.toSupabase(
        reporterCitizenId: citizenId,
        reporterAuthUserId: authUser?.id,
      );
      await supabase.from('complaints').insert(payload);
    } catch (e) {
      debugPrint('[InteractiveReportNotifier] Error saving report to Supabase: $e');
    }
  }

  /// Updates an existing report (e.g. location drag or status change) and syncs to Supabase.
  Future<void> updateReport(ReportModel updatedReport) async {
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
    } catch (e) {
      debugPrint('[InteractiveReportNotifier] Error updating complaint in Supabase: $e');
    }
  }

  /// Optimistically updates report upvote count in local state.
  void toggleUpvote(String reportId, bool isCurrentlyUpvoted) {
    final reportIndex = state.indexWhere((r) => r.id == reportId);
    if (reportIndex == -1) return;

    final current = state[reportIndex];
    final delta = isCurrentlyUpvoted ? -1 : 1;
    final newCount = math.max(0, current.upvoteCount + delta);
    final updated = current.copyWith(upvoteCount: newCount);

    state = [
      for (int i = 0; i < state.length; i++)
        if (i == reportIndex) updated else state[i],
    ];
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

class UpvotedReportsNotifier extends Notifier<Set<String>> {
  StreamSubscription? _authSubscription;
  RealtimeChannel? _upvotesChannel;

  @override
  Set<String> build() {
    _loadUserUpvotes();
    _subscribeToUpvotesRealtime();

    // Listen to Supabase auth state changes: when user logs in or logs out,
    // refresh and merge upvote records from the cloud.
    _authSubscription ??= SupabaseConfig.client.auth.onAuthStateChange.listen((data) {
      _loadUserUpvotes();
    });

    ref.onDispose(() {
      _authSubscription?.cancel();
      _upvotesChannel?.unsubscribe();
    });

    return <String>{};
  }

  bool isUpvoted(String reportId) => state.contains(reportId);

  /// Subscribes to Supabase Realtime for the complaint_upvotes table
  void _subscribeToUpvotesRealtime() {
    try {
      _upvotesChannel?.unsubscribe();

      _upvotesChannel = SupabaseConfig.client
          .channel('public:complaint_upvotes:realtime')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'complaint_upvotes',
            callback: (payload) async {
              final deviceId = await DeviceService.getDeviceId();
              final authUser = SupabaseConfig.client.auth.currentUser;
              String? citizenId;

              if (authUser != null) {
                try {
                  final citizenRecord = await SupabaseConfig.client
                      .from('citizens')
                      .select('id')
                      .eq('auth_user_id', authUser.id)
                      .maybeSingle();
                  if (citizenRecord != null) {
                    citizenId = citizenRecord['id']?.toString();
                  }
                } catch (_) {}
              }

              if (payload.eventType == PostgresChangeEvent.insert) {
                final rec = payload.newRecord;
                final recDeviceId = rec['device_id']?.toString();
                final recCitizenId = rec['citizen_id']?.toString();
                final complaintId = rec['complaint_id']?.toString();

                if (complaintId != null) {
                  final isMyVote = (citizenId != null && recCitizenId == citizenId) ||
                      (recDeviceId != null && recDeviceId == deviceId);
                  if (isMyVote && !state.contains(complaintId)) {
                    state = {...state, complaintId};
                  }
                }
              } else if (payload.eventType == PostgresChangeEvent.delete) {
                final rec = payload.oldRecord;
                final recDeviceId = rec['device_id']?.toString();
                final recCitizenId = rec['citizen_id']?.toString();
                final complaintId = rec['complaint_id']?.toString();

                if (complaintId != null) {
                  final wasMyVote = (citizenId != null && recCitizenId == citizenId) ||
                      (recDeviceId != null && recDeviceId == deviceId);
                  if (wasMyVote && state.contains(complaintId)) {
                    state = {...state}..remove(complaintId);
                  }
                }
              }
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('[UpvotedReportsNotifier] Upvotes realtime error: $e');
    }
  }

  /// Loads upvotes for the current device and logged-in citizen from Supabase
  Future<void> _loadUserUpvotes() async {
    try {
      final supabase = SupabaseConfig.client;
      final deviceId = await DeviceService.getDeviceId();
      final authUser = supabase.auth.currentUser;
      String? citizenId;

      if (authUser != null) {
        try {
          final citizenRecord = await supabase
              .from('citizens')
              .select('id')
              .eq('auth_user_id', authUser.id)
              .maybeSingle();
          if (citizenRecord != null) {
            citizenId = citizenRecord['id']?.toString();
          }
        } catch (e) {
          debugPrint('[UpvotedReportsNotifier] Error fetching citizen profile: $e');
        }
      }

      // Query complaint_upvotes for this citizen or device
      dynamic query = supabase.from('complaint_upvotes').select('complaint_id');
      if (citizenId != null) {
        query = query.or('citizen_id.eq.$citizenId,device_id.eq.$deviceId');
      } else {
        query = query.eq('device_id', deviceId);
      }

      final response = await query;
      final upvotedIds = (response as List)
          .map((row) => row['complaint_id']?.toString())
          .whereType<String>()
          .toSet();

      state = upvotedIds;

      // If user is logged in, associate unlinked device-level votes with this citizen
      if (citizenId != null) {
        try {
          await supabase
              .from('complaint_upvotes')
              .update({'citizen_id': citizenId})
              .eq('device_id', deviceId)
              .isFilter('citizen_id', null);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('[UpvotedReportsNotifier] Error loading upvotes from cloud: $e');
    }
  }

  /// Toggles an upvote for a report, syncing with the Supabase complaint_upvotes table.
  Future<void> toggle(String reportId) async {
    final isCurrentlyUpvoted = state.contains(reportId);

    // 1. Optimistic state toggle
    if (isCurrentlyUpvoted) {
      state = {...state}..remove(reportId);
    } else {
      state = {...state, reportId};
    }

    try {
      final supabase = SupabaseConfig.client;
      final deviceId = await DeviceService.getDeviceId();
      final authUser = supabase.auth.currentUser;
      String? citizenId;

      if (authUser != null) {
        final citizenRecord = await supabase
            .from('citizens')
            .select('id')
            .eq('auth_user_id', authUser.id)
            .maybeSingle();
        if (citizenRecord != null) {
          citizenId = citizenRecord['id']?.toString();
        }
      }

      if (isCurrentlyUpvoted) {
        // Delete upvote from complaint_upvotes
        // Note: The database trigger automatically decrements complaints.upvote_count!
        if (citizenId != null) {
          await supabase
              .from('complaint_upvotes')
              .delete()
              .eq('complaint_id', reportId)
              .or('citizen_id.eq.$citizenId,device_id.eq.$deviceId');
        } else {
          await supabase
              .from('complaint_upvotes')
              .delete()
              .eq('complaint_id', reportId)
              .eq('device_id', deviceId);
        }
      } else {
        // Insert upvote into complaint_upvotes
        // Note: The database trigger automatically increments complaints.upvote_count!
        final payload = <String, dynamic>{
          'complaint_id': reportId,
          'device_id': deviceId,
        };
        if (citizenId != null) {
          payload['citizen_id'] = citizenId;
        }
        await supabase.from('complaint_upvotes').insert(payload);
      }
    } catch (e) {
      debugPrint('[UpvotedReportsNotifier] Error syncing upvote to Supabase: $e');
      // Rollback optimistic state if cloud sync fails
      if (isCurrentlyUpvoted) {
        state = {...state, reportId};
      } else {
        state = {...state}..remove(reportId);
      }
    }
  }

  /// Manually forces a fresh fetch of upvotes from Supabase
  Future<void> refresh() async {
    await _loadUserUpvotes();
  }
}

final upvotedReportsProvider = NotifierProvider<UpvotedReportsNotifier, Set<String>>(() {
  return UpvotedReportsNotifier();
});
