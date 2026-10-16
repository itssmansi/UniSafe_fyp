import 'package:flutter/material.dart';
import '../home_page.dart';

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
  });
}

class KanbanBoardScreen extends StatefulWidget {
  const KanbanBoardScreen({super.key});

  @override
  State<KanbanBoardScreen> createState() => _KanbanBoardScreenState();
}

class _KanbanBoardScreenState extends State<KanbanBoardScreen> {
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

  late final List<CivicReport> _reports;
  final Set<String> _verifiedReportIds = {};

  void _toggleVerify(CivicReport report) {
    final alreadyVerified = _verifiedReportIds.contains(report.id);
    setState(() {
      if (alreadyVerified) {
        _verifiedReportIds.remove(report.id);
      } else {
        _verifiedReportIds.add(report.id);
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                alreadyVerified ? Icons.info_outline : Icons.check_circle,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  alreadyVerified
                      ? 'Removed verification for "${report.title}".'
                      : 'Report "${report.title}" verified successfully!',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: alreadyVerified ? Colors.grey.shade800 : const Color(0xFF2563EB),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _reports = [
      // 3 Planned Reports
      const CivicReport(
        id: 'rep-1',
        title: 'Water Logging',
        category: 'Infrastructure',
        categoryColor: Color(0xFF0284C7),
        categoryIcon: Icons.water_drop_rounded,
        location: 'SV Road Junction, Bandra West',
        date: 'Oct 12, 2026',
        department: 'BMC Stormwater Drain Department',
        description:
            'Severe water accumulation reported after moderate rain. Standing water up to 1.5 feet obstructing road movement and pedestrian walkways. Scheduled for suction clearing and drain desilting.',
        status: KanbanStatus.planned,
      ),
      const CivicReport(
        id: 'rep-2',
        title: 'Waste Dumping in Green Area',
        category: 'Greenery',
        categoryColor: Color(0xFF16A34A),
        categoryIcon: Icons.park_rounded,
        location: "Jogger's Park Ecological Zone",
        date: 'Oct 11, 2026',
        department: 'Parks & Gardens Dept / Solid Waste Mgt',
        description:
            'Commercial debris and plastic waste dumped illegally inside the green belt buffer zone. Scheduled for heavy equipment cleanup, green restoration, and installation of warning barricades.',
        status: KanbanStatus.planned,
      ),
      const CivicReport(
        id: 'rep-3',
        title: 'Potholes on Main Junction',
        category: 'Infrastructure',
        categoryColor: Color(0xFF0284C7),
        categoryIcon: Icons.add_road_rounded,
        location: 'Link Road & 14th Cross Junction',
        date: 'Oct 10, 2026',
        department: 'Roads & Traffic Infrastructure Authority',
        description:
            'Cluster of deep potholes on the westbound lane causing vehicle congestion and skidding hazards for two-wheelers. Rapid cold-mix patch work queued in maintenance cycle.',
        status: KanbanStatus.planned,
      ),

      // 1 In Progress Report
      const CivicReport(
        id: 'rep-4',
        title: 'Electrical Hazard & Exposed Wires',
        category: 'Safety',
        categoryColor: Color(0xFFDC2626),
        categoryIcon: Icons.electric_bolt_rounded,
        location: 'Near Sector 4 Bus Stop',
        date: 'Oct 9, 2026',
        department: 'MSEDCL Electricity Board - Quick Response Unit',
        description:
            'Damaged junction feeder box with exposed live wires dangling near the public bus waiting shelter. Emergency response team dispatched on site; power isolated and line insulation in progress.',
        status: KanbanStatus.inProgress,
      ),

      // 1 In Review Report
      const CivicReport(
        id: 'rep-5',
        title: 'Untimely Garbage Overflowing',
        category: 'Sanitation',
        categoryColor: Color(0xFFD97706),
        categoryIcon: Icons.delete_sweep_rounded,
        location: 'Community Bin #18, Shivaji Nagar',
        date: 'Oct 8, 2026',
        department: 'Solid Waste Management (SWM) Division',
        description:
            'Community waste bin overflowing onto the pedestrian pathway creating sanitation and odor concerns. Waste clearing vehicle finished collection; awaiting final sanitary inspector sign-off.',
        status: KanbanStatus.inReview,
      ),

      // 1 Done Report
      const CivicReport(
        id: 'rep-6',
        title: 'Nonfunctional Street Lights',
        category: 'Infrastructure',
        categoryColor: Color(0xFF0284C7),
        categoryIcon: Icons.lightbulb_rounded,
        location: 'Subhash Avenue North, Ward 12',
        date: 'Oct 5, 2026',
        department: 'Street Lighting & Electrical Maintenance',
        description:
            'Three consecutive LED street light poles were dark for over a week creating an unsafe dark corridor for night commuters. New LED luminaire fixtures installed and fully verified operational.',
        status: KanbanStatus.done,
      ),
    ];
  }

  List<CivicReport> _getReportsForStatus(KanbanStatus status) {
    return _reports.where((report) => report.status == status).toList();
  }

  void _handleBackNavigation(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          title: const Text(
            'Kanban Board',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _handleBackNavigation(context),
          ),
          backgroundColor: Colors.white,
          elevation: 0.5,
          scrolledUnderElevation: 1,
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return _buildMobileGrid();
            }
            return _buildDesktopBoard();
          },
        ),
      ),
    );
  }

  // --- MOBILE VIEW (2x2 Grid) ---
  Widget _buildMobileGrid() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildColumnContainer(columns[0])),
                const SizedBox(width: 8),
                Expanded(child: _buildColumnContainer(columns[1])),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildColumnContainer(columns[2])),
                const SizedBox(width: 8),
                Expanded(child: _buildColumnContainer(columns[3])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TABLET / DESKTOP VIEW (4 Side-by-Side Columns) ---
  Widget _buildDesktopBoard() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: columns.map((col) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6.0),
              child: _buildColumnContainer(col),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- COLUMN CONTAINER WIDGET ---
  Widget _buildColumnContainer(KanbanColumnData col) {
    final items = _getReportsForStatus(col.status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildHeader(col, items.length),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Text(
                        'No reports',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                          fontWeight: FontWeight.w500,
                        ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: col.color.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
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
                color: Colors.black87,
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

  // --- CIVIC REPORT CARD ---
  Widget _buildReportCard(CivicReport report) {
    final isVerified = _verifiedReportIds.contains(report.id);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1.5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _showReportDetails(report),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Category Tag Chip
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
                const SizedBox(height: 6),

                // Report Title
                Text(
                  report.title,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
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

                  // Blue Verify Button (In Review only, no icon)
                  SizedBox(
                    width: double.infinity,
                    height: 28,
                    child: ElevatedButton(
                      onPressed: () => _toggleVerify(report),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isVerified
                            ? const Color(0xFF10B981)
                            : const Color(0xFF2563EB),
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

                // Bottom Sheet Verify Button (In Review only, no icon)
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
        );
      },
    );
  }
}
