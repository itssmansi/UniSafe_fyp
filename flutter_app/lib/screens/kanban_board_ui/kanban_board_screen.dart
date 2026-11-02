import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/supabase_config.dart';
import '../../services/device_service.dart';
import '../../theme/unisafe_theme.dart';
import '../home_page.dart';
import '../interactive_map/report_model.dart';
import '../interactive_map/report_provider.dart';
import 'citizen_verification_screen.dart';

enum KanbanStatus {
  planned,
  inProgress,
  inReview,
  done,
}

class KanbanColumnData {
  final KanbanStatus status;
  final String name;
  final Color color;

  const KanbanColumnData({
    required this.status,
    required this.name,
    required this.color,
  });
}

class CivicReport {
  final String id;
  final String title;
  final String category;
  final Color categoryColor;
  final IconData categoryIcon;
  final String location;
  final String date;
  final String department;
  final String description;
  final KanbanStatus status;
  final ReportModel model;

  const CivicReport({
    required this.id,
    required this.title,
    required this.category,
    required this.categoryColor,
    required this.categoryIcon,
    required this.location,
    required this.date,
    required this.department,
    required this.description,
    required this.status,
    required this.model,
  });
}

class KanbanBoardScreen extends ConsumerStatefulWidget {
  const KanbanBoardScreen({super.key});

  @override
  ConsumerState<KanbanBoardScreen> createState() => _KanbanBoardScreenState();
}

class _KanbanBoardScreenState extends ConsumerState<KanbanBoardScreen> {
  final List<KanbanColumnData> columns = const [
    KanbanColumnData(
      status: KanbanStatus.planned,
      name: "Planned",
      color: Color(0xFF6B7280),
    ),
    KanbanColumnData(
      status: KanbanStatus.inProgress,
      name: "In Progress",
      color: Color(0xFFF59E0B),
    ),
    KanbanColumnData(
      status: KanbanStatus.inReview,
      name: "In Review",
      color: Color(0xFF3B82F6),
    ),
    KanbanColumnData(
      status: KanbanStatus.done,
      name: "Done",
      color: Color(0xFF10B981),
    ),
  ];

  final Set<String> _verifiedReportIds = {};
  Map<String, dynamic>? _citizenProfile;
  Set<String> _myDeviceReportIds = {};

  @override
  void initState() {
    super.initState();
    _loadCitizenProfile();
    _loadMyDeviceReportIds();
  }

  Future<void> _loadCitizenProfile() async {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user != null) {
      try {
        var query = SupabaseConfig.client.from('citizens').select();
        if (user.email != null && user.email!.isNotEmpty) {
          query = query.or('auth_user_id.eq.${user.id},email.eq.${user.email}');
        } else if (user.phone != null && user.phone!.isNotEmpty) {
          query = query.or('auth_user_id.eq.${user.id},phone.eq.${user.phone}');
        } else {
          query = query.eq('auth_user_id', user.id);
        }
        final data = await query.maybeSingle();
        if (mounted) {
          setState(() {
            _citizenProfile = data;
          });
        }
      } catch (e) {
        debugPrint('[Kanban] Error loading citizen profile: $e');
      }
    }
  }

  Future<void> _loadMyDeviceReportIds() async {
    try {
      final ids = await DeviceService.getMyReportIds();
      if (mounted) {
        setState(() {
          _myDeviceReportIds = ids.toSet();
        });
      }
    } catch (_) {}
  }

  static (Color, IconData, String) _getCategoryMeta(IssueCategory cat) {
    switch (cat) {
      case IssueCategory.infrastructure:
        return (const Color(0xFF0284C7), Icons.construction_rounded, 'Infrastructure');
      case IssueCategory.sanitation:
        return (const Color(0xFFD97706), Icons.delete_sweep_rounded, 'Sanitation');
      case IssueCategory.safety:
        return (const Color(0xFFDC2626), Icons.shield_rounded, 'Safety');
      case IssueCategory.greenery:
        return (const Color(0xFF16A34A), Icons.park_rounded, 'Greenery');
    }
  }

  static String _formatReportDate(DateTime? dt) {
    if (dt == null) return 'Recently';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  static KanbanStatus _mapReportStatus(String? status) {
    final s = (status ?? '').toLowerCase().trim();
    if (s == 'resolved' || s == 'done' || s == 'closed' || s == 'completed') {
      return KanbanStatus.done;
    }
    if (s.contains('review') || s.contains('verif')) {
      return KanbanStatus.inReview;
    }
    if (s.contains('progress') || s.contains('working') || s.contains('assigned')) {
      return KanbanStatus.inProgress;
    }
    return KanbanStatus.planned;
  }

  CivicReport _reportModelToCivicReport(ReportModel r) {
    final meta = _getCategoryMeta(r.category);
    final kanbanStatus = _mapReportStatus(r.status);

    String locationStr;
    if (r.address != null && r.address!.trim().isNotEmpty) {
      locationStr = r.address!.trim();
    } else {
      locationStr = 'Lat ${r.location.latitude.toStringAsFixed(3)}, Lng ${r.location.longitude.toStringAsFixed(3)}';
    }

    String department;
    if (r.assignedOfficerDepartment != null && r.assignedOfficerDepartment!.trim().isNotEmpty) {
      department = r.assignedOfficerDepartment!.trim();
      if (r.assignedOfficerName != null && r.assignedOfficerName!.trim().isNotEmpty) {
        department = '$department (${r.assignedOfficerName!.trim()})';
      }
    } else if (r.assignedOfficerName != null && r.assignedOfficerName!.trim().isNotEmpty) {
      department = 'Assigned to ${r.assignedOfficerName!.trim()}';
    } else {
      department = 'Pending BMC Assignment';
    }

    return CivicReport(
      id: r.id,
      title: r.title.isNotEmpty ? r.title : 'Civic Incident',
      category: meta.$3,
      categoryColor: meta.$1,
      categoryIcon: meta.$2,
      location: locationStr,
      date: _formatReportDate(r.createdAt),
      department: department,
      description: r.description.isNotEmpty ? r.description : 'No additional details provided.',
      status: kanbanStatus,
      model: r,
    );
  }

  List<ReportModel> _filterOwnedReports(List<ReportModel> allReports) {
    final citizenId = _citizenProfile?['id']?.toString();
    final authUserId = SupabaseConfig.client.auth.currentUser?.id;

    return allReports.where((r) {
      final bool isMyAuthUser = authUserId != null &&
          r.authUserId != null &&
          r.authUserId == authUserId;
      final bool isMyCitizen = citizenId != null &&
          r.citizenId != null &&
          r.citizenId!.isNotEmpty &&
          r.citizenId == citizenId;
      final bool isMyDevice = _myDeviceReportIds.contains(r.id);
      return isMyAuthUser || isMyCitizen || isMyDevice;
    }).toList();
  }

  List<CivicReport> _getReportsForStatus(KanbanStatus status, List<CivicReport> reports) {
    return reports.where((report) => report.status == status).toList();
  }

  Future<void> _openVerification(CivicReport report) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CitizenVerificationScreen(report: report.model),
      ),
    );

    if (result == true) {
      setState(() {
        _verifiedReportIds.add(report.id);
      });
    } else if (result == false) {
      setState(() {
        _verifiedReportIds.remove(report.id);
      });
    }
  }

  void _toggleVerify(CivicReport report) {
    _openVerification(report);
  }

  void _handleBackNavigation(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        UniSafePageRoute(builder: (context) => const HomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final allRawReports = ref.watch(interactiveReportProvider);
    final myRawReports = _filterOwnedReports(allRawReports);
    final List<CivicReport> activeReports = myRawReports.map(_reportModelToCivicReport).toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation(context);
      },
      child: Scaffold(
        backgroundColor: UniSafeColors.canvas,
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Resolution desk',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 19, letterSpacing: -0.35),
              ),
              Text(
                'My submitted civic reports (${activeReports.length})',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: UniSafeColors.mutedInk),
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _handleBackNavigation(context),
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh reports',
              icon: const Icon(Icons.refresh_rounded, size: 22, color: UniSafeColors.ink),
              onPressed: () {
                ref.read(interactiveReportProvider.notifier).refreshReports();
              },
            ),
            const SizedBox(width: 8),
          ],
          backgroundColor: UniSafeColors.canvas,
        ),
        body: EntranceReveal(
          child: LayoutBuilder(
            builder: (context, constraints) => constraints.maxWidth < 600
                ? _buildMobileGrid(activeReports)
                : _buildDesktopBoard(activeReports),
          ),
        ),
      ),
    );
  }

  // --- MOBILE VIEW (2x2 Grid) ---
  Widget _buildMobileGrid(List<CivicReport> reports) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildColumnContainer(columns[0], reports)),
                const SizedBox(width: 8),
                Expanded(child: _buildColumnContainer(columns[1], reports)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildColumnContainer(columns[2], reports)),
                const SizedBox(width: 8),
                Expanded(child: _buildColumnContainer(columns[3], reports)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TABLET / DESKTOP VIEW (4 Side-by-Side Columns) ---
  Widget _buildDesktopBoard(List<CivicReport> reports) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: columns.map((col) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: _buildColumnContainer(col, reports),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- COLUMN CONTAINER WIDGET (Citizen View-Only, No Drag Target) ---
  Widget _buildColumnContainer(KanbanColumnData col, List<CivicReport> reports) {
    final items = _getReportsForStatus(col.status, reports);

    return Container(
      decoration: BoxDecoration(
        color: UniSafeColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: UniSafeColors.line),
        boxShadow: [
          BoxShadow(
            color: UniSafeColors.ink.withValues(alpha: .035),
            blurRadius: 16,
            offset: const Offset(0, 7),
          )
        ],
      ),
      child: Column(
        children: [
          _buildHeader(col, items.length),
          const Divider(height: 1, thickness: 1, color: UniSafeColors.line),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.assignment_outlined,
                            size: 26,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'No reports in ${col.name}',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final report = items[index];
                      return _buildReportCard(report);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- COLUMN HEADER ---
  Widget _buildHeader(KanbanColumnData col, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
      decoration: BoxDecoration(
        color: col.color.withValues(alpha: 0.09),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: col.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              col.name,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: UniSafeColors.ink,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: col.color.withValues(alpha: 0.25)),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: col.color,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- CIVIC REPORT CARD (View & Inspect Details Only) ---
  Widget _buildReportCard(CivicReport report) {
    final isVerified = _verifiedReportIds.contains(report.id);
    final hasPhoto = report.model.imageBytes != null ||
        (report.model.imagePath != null &&
            report.model.imagePath!.isNotEmpty &&
            !report.model.imagePath!.startsWith('blob:'));

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: UniSafeColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: UniSafeColors.line),
        boxShadow: [
          BoxShadow(
            color: UniSafeColors.ink.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showReportDetails(report),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Category Tag Chip & Photo indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: report.categoryColor.withValues(alpha: 0.09),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(report.categoryIcon, size: 11, color: report.categoryColor),
                          const SizedBox(width: 4),
                          Text(
                            report.category,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: report.categoryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasPhoto)
                      Icon(Icons.photo_camera_rounded, size: 13, color: Colors.grey.shade400),
                  ],
                ),
                const SizedBox(height: 6),

                // Report Title
                Text(
                  report.title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: UniSafeColors.ink,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // Location Row
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 12,
                      color: Colors.grey.shade500,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        report.location,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Date Row
                Row(
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 11,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      report.date,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                if (report.status == KanbanStatus.inReview) ...[
                  const SizedBox(height: 8),

                  // Blue Verify Button (In Review only)
                  SizedBox(
                    width: double.infinity,
                    height: 28,
                    child: ElevatedButton(
                      onPressed: () => _toggleVerify(report),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isVerified
                            ? UniSafeColors.teal
                            : UniSafeColors.navy,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        isVerified ? 'Verified' : 'Verify',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- DETAILS BOTTOM SHEET ---
  void _showReportDetails(CivicReport report) {
    final colMeta = columns.firstWhere((col) => col.status == report.status);
    final hasPhotoBytes = report.model.imageBytes != null;
    final hasPhotoUrl = report.model.imagePath != null &&
        report.model.imagePath!.isNotEmpty &&
        !report.model.imagePath!.startsWith('blob:');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // Status & Category Badges Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Status Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: colMeta.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: colMeta.color.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: colMeta.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                colMeta.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: colMeta.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Category Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: report.categoryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(report.categoryIcon, size: 13, color: report.categoryColor),
                              const SizedBox(width: 5),
                              Text(
                                report.category,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: report.categoryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Close Button
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close, color: Colors.grey.shade600, size: 18),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Attached Photo Preview (if present)
                if (hasPhotoBytes) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      report.model.imageBytes!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 14),
                ] else if (hasPhotoUrl) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      report.model.imagePath!,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Title
                Text(
                  report.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),

                // Date Submitted
                Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 13, color: Colors.grey.shade500),
                    const SizedBox(width: 5),
                    Text(
                      'Reported on ${report.date}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Location Tile
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.location_on, color: Colors.blue, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Incident Location',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              report.location,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Assigned Department Tile
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.account_balance_outlined, color: Colors.deepPurple, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Assigned Authority / Department',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              report.department,
                              style: const TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Description Header
                const Text(
                  'Report Description',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),

                // Description Box
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    report.description,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.grey.shade800,
                      height: 1.45,
                    ),
                  ),
                ),

                if (report.status == KanbanStatus.inReview) ...[
                  const SizedBox(height: 20),

                  // Bottom Sheet Verify Button (In Review only)
                  StatefulBuilder(
                    builder: (context, setModalState) {
                      final isVerified = _verifiedReportIds.contains(report.id);
                      return SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          onPressed: () {
                            _toggleVerify(report);
                            setModalState(() {});
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isVerified
                                ? const Color(0xFF10B981)
                                : const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            isVerified ? 'Verified by Citizen' : 'Verify Report',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
