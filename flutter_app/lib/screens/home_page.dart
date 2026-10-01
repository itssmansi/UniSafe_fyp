import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'heatmap_ui/map_screen.dart';
import 'interactive_map/map_screen.dart';
import 'interactive_map/report_model.dart';
import 'interactive_map/report_provider.dart';
import 'kanban_board_ui/kanban_board_screen.dart';
import 'SignupLogin_ui/welcome_screen.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;
  String _selectedInboxFilter = 'All';

  // Linear-style demo reports for the Inbox
  final List<Map<String, dynamic>> _demoReports = [
    {
      'id': 'uni-101',
      'title': 'Flickering streetlight along Library walkway',
      'category': IssueCategory.infrastructure,
      'status': 'In Progress',
      'author': 'kristin assigned to maintenance',
      'time': '2h',
      'unread': true,
      'priority': 'High',
      'description': 'Light turns off intermittently creating a dark unsafe blind spot for students walking at night.',
      'location': 'North Library Path • Sector 3',
    },
    {
      'id': 'uni-102',
      'title': 'Overflowing waste bin near Central Cafeteria',
      'category': IssueCategory.sanitation,
      'status': 'Done',
      'author': 'bryan marked as resolved',
      'time': '4h',
      'unread': false,
      'priority': 'Medium',
      'description': 'Litter spilling onto walking path, attracting stray animals. Cleaned and sanitised.',
      'location': 'Central Plaza Food Court',
    },
    {
      'id': 'uni-103',
      'title': 'Loose electrical wiring hanging near C-Block',
      'category': IssueCategory.safety,
      'status': 'Triage',
      'author': 'safety inspection team notified',
      'time': '6h',
      'unread': true,
      'priority': 'Urgent',
      'description': 'Exposed conduit wire hanging near the ground near main external staircase.',
      'location': 'Science C-Block Garden Staircase',
    },
    {
      'id': 'uni-104',
      'title': 'Fallen tree branch obstructing bicycle lane',
      'category': IssueCategory.greenery,
      'status': 'Done',
      'author': 'grounds team cleared path',
      'time': '1d',
      'unread': false,
      'priority': 'Low',
      'description': 'Storm debris completely obstructing the bicycle lane after rain.',
      'location': 'South Campus Perimeter Bike Track',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // Active Tab Content
            IndexedStack(
              index: _currentIndex,
              children: [
                _buildHomeTab(),
                _buildInboxTab(),
                _buildAccountTab(),
              ],
            ),

            // Linear-Style Floating Bottom Navigation Dock
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: _buildLinearFloatingDock(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // LINEAR FLOATING BOTTOM DOCK (White Background, Black Icons & Fluid Draggable Selector)
  // ==========================================
  Widget _buildLinearFloatingDock() {
    return _LinearDraggableDock(
      currentIndex: _currentIndex,
      onTabSelected: (index) {
        setState(() => _currentIndex = index);
      },
    );
  }

  // ==========================================
  // TAB 0: HOME PAGE (Linear Style White Mode)
  // ==========================================
  Widget _buildHomeTab() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: Row(
          children: [
            // Linear Workspace Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4F5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE4E4E7), width: 1),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.shield, color: Color(0xFF18181B), size: 16),
                  SizedBox(width: 8),
                  Text(
                    'UniSafe',
                    style: TextStyle(
                      color: Color(0xFF18181B),
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(LucideIcons.chevronDown, color: Color(0xFF71717A), size: 14),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const InteractiveMapScreen()),
              );
            },
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4F5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE4E4E7), width: 1),
              ),
              child: const Icon(LucideIcons.penSquare, color: Color(0xFF18181B), size: 17),
            ),
          ),
          const SizedBox(width: 14),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF4F4F5), height: 1),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          children: [
            // Linear Section Header: FAVORITES
            const Text(
              'FAVORITES',
              style: TextStyle(
                color: Color(0xFF71717A),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),

            // 4 Original Buttons in Clean Linear Rows
            _buildLinearRowItem(
              icon: LucideIcons.layers,
              iconColor: const Color(0xFFF97316),
              title: 'Open Heatmap',
              badgeText: 'HEATMAP',
              badgeColor: const Color(0xFFFFF7ED),
              badgeTextColor: const Color(0xFFEA580C),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const MapScreen()),
                );
              },
            ),
            const SizedBox(height: 8),

            _buildLinearRowItem(
              icon: LucideIcons.compass,
              iconColor: const Color(0xFF3B82F6),
              title: 'Open Interactive Map',
              badgeText: 'LIVE MAP',
              badgeColor: const Color(0xFFEFF6FF),
              badgeTextColor: const Color(0xFF2563EB),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const InteractiveMapScreen()),
                );
              },
            ),
            const SizedBox(height: 8),

            _buildLinearRowItem(
              icon: LucideIcons.layoutGrid,
              iconColor: const Color(0xFF8B5CF6),
              title: 'Open Kanban Board',
              badgeText: 'TASKS',
              badgeColor: const Color(0xFFF5F3FF),
              badgeTextColor: const Color(0xFF7C3AED),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const KanbanBoardScreen()),
                );
              },
            ),
            const SizedBox(height: 8),

            _buildLinearRowItem(
              icon: LucideIcons.shieldCheck,
              iconColor: const Color(0xFF0D9488),
              title: 'Citizen Auth (Login / Signup)',
              badgeText: 'AUTH',
              badgeColor: const Color(0xFFF0FDFA),
              badgeTextColor: const Color(0xFF0D9488),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const WelcomeSelectionScreen()),
                );
              },
            ),
            const SizedBox(height: 28),

            // Linear Section Header: TEAMS & SERVICES
            const Text(
              'CAMPUS TEAMS',
              style: TextStyle(
                color: Color(0xFF71717A),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),

            _buildLinearTeamGroup(
              title: 'Infrastructure Maintenance',
              icon: LucideIcons.building,
              items: ['Roads & Walkways', 'Streetlights', 'Civil Repairs'],
            ),
            const SizedBox(height: 12),
            _buildLinearTeamGroup(
              title: 'Health & Sanitation',
              icon: LucideIcons.trash2,
              items: ['Waste Management', 'Water Supply', 'Hygiene Clean'],
            ),
            const SizedBox(height: 12),
            _buildLinearTeamGroup(
              title: 'Safety & Emergency Escorts',
              icon: LucideIcons.shieldAlert,
              items: ['Night Patrol', 'Campus Guard Post', 'Emergency Medic'],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinearRowItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String badgeText,
    required Color badgeColor,
    required Color badgeTextColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E4E7), width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF18181B),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      color: badgeTextColor,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(LucideIcons.chevronRight, color: Color(0xFFA1A1AA), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLinearTeamGroup({
    required String title,
    required IconData icon,
    required List<String> items,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE4E4E7), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF71717A), size: 16),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF18181B),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map((sub) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Color(0xFFA1A1AA),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        sub,
                        style: const TextStyle(color: Color(0xFF71717A), fontSize: 13),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 1: INBOX / YOUR REPORTS (Linear Style)
  // ==========================================
  Widget _buildInboxTab() {
    final liveReports = ref.watch(interactiveReportProvider);

    // Merge live reports with demo reports
    final allReports = <Map<String, dynamic>>[];
    for (final r in liveReports) {
      allReports.add({
        'id': 'uni-${r.id.substring(0, 4)}',
        'title': r.title,
        'category': r.category,
        'status': 'Triage',
        'author': 'submitted by you',
        'time': 'just now',
        'unread': true,
        'priority': 'Medium',
        'description': r.description,
        'location': '${r.location.latitude.toStringAsFixed(3)}, ${r.location.longitude.toStringAsFixed(3)}',
      });
    }
    allReports.addAll(_demoReports);

    final filtered = allReports.where((r) {
      if (_selectedInboxFilter == 'All') return true;
      if (_selectedInboxFilter == 'Unread') return r['unread'] == true;
      return (r['status'] as String).toLowerCase() == _selectedInboxFilter.toLowerCase();
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: const Text(
          'Inbox',
          style: TextStyle(
            color: Color(0xFF18181B),
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const InteractiveMapScreen()),
              );
            },
            icon: const Icon(LucideIcons.penSquare, color: Color(0xFF18181B), size: 19),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(LucideIcons.moreHorizontal, color: Color(0xFF71717A), size: 19),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFF4F4F5), width: 1)),
            ),
            child: Row(
              children: [
                _buildInboxFilterChip('All'),
                const SizedBox(width: 8),
                _buildInboxFilterChip('Unread'),
                const SizedBox(width: 8),
                _buildInboxFilterChip('In Progress'),
                const SizedBox(width: 8),
                _buildInboxFilterChip('Done'),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: filtered.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.inbox, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text(
                      'No issues in this view',
                      style: TextStyle(color: Color(0xFF71717A), fontSize: 14.5, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 110),
                itemCount: filtered.length,
                separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF4F4F5)),
                itemBuilder: (context, index) {
                  final item = filtered[index];
                  return _buildLinearInboxItem(item);
                },
              ),
      ),
    );
  }

  Widget _buildInboxFilterChip(String label) {
    final isSelected = _selectedInboxFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedInboxFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF18181B) : const Color(0xFFF4F4F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF71717A),
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLinearInboxItem(Map<String, dynamic> item) {
    final bool isUnread = item['unread'] as bool;
    final String status = item['status'] as String;

    Color statusDotColor;
    if (status.contains('Done')) {
      statusDotColor = const Color(0xFF10B981);
    } else if (status.contains('In Progress')) {
      statusDotColor = const Color(0xFFF59E0B);
    } else {
      statusDotColor = const Color(0xFF3B82F6);
    }

    return InkWell(
      onTap: () => _showLinearIssueModal(item),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Indicator Circle
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: isUnread ? statusDotColor : Colors.transparent,
                  border: isUnread ? null : Border.all(color: const Color(0xFFA1A1AA), width: 1.2),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['title'] as String,
                    style: TextStyle(
                      color: const Color(0xFF18181B),
                      fontSize: 14.5,
                      fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item['author']} • ${item['time']}',
                    style: const TextStyle(
                      color: Color(0xFF71717A),
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),

            // Priority Indicator Tag
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4F5),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                item['priority'] as String,
                style: const TextStyle(
                  color: Color(0xFF71717A),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLinearIssueModal(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE4E4E7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F4F5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item['id'] as String,
                      style: const TextStyle(color: Color(0xFF71717A), fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.x, size: 18, color: Color(0xFF71717A)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item['title'] as String,
                style: const TextStyle(color: Color(0xFF18181B), fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                item['description'] as String,
                style: const TextStyle(color: Color(0xFF52525B), fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(LucideIcons.mapPin, color: Color(0xFF71717A), size: 15),
                  const SizedBox(width: 6),
                  Text(
                    item['location'] as String,
                    style: const TextStyle(color: Color(0xFF71717A), fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => const InteractiveMapScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF18181B),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                  ),
                  icon: const Icon(LucideIcons.map, size: 16),
                  label: const Text('View on Map', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 2: ACCOUNT (Linear Style White Mode)
  // ==========================================
  Widget _buildAccountTab() {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: const Text(
          'Account',
          style: TextStyle(
            color: Color(0xFF18181B),
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(LucideIcons.moreHorizontal, color: Color(0xFF71717A), size: 19),
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF4F4F5), height: 1),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          children: [
            // Linear Profile Header Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE4E4E7), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF18181B),
                      border: Border.all(color: const Color(0xFFE4E4E7), width: 1.5),
                    ),
                    child: const Center(
                      child: Text(
                        'AM',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alex Morgan',
                          style: TextStyle(
                            color: Color(0xFF18181B),
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'citizen@unisafe.org',
                          style: TextStyle(color: Color(0xFF71717A), fontSize: 13),
                        ),
                        SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(LucideIcons.circleCheck, color: Color(0xFF10B981), size: 13),
                            SizedBox(width: 4),
                            Text(
                              'Verified Citizen',
                              style: TextStyle(color: Color(0xFF10B981), fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Linear Status Chips Row
            const Text(
              'SAFETY TELEMETRY',
              style: TextStyle(
                color: Color(0xFF71717A),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                _buildLinearMetricChip('4', 'Issues Filed'),
                const SizedBox(width: 8),
                _buildLinearMetricChip('2', 'Resolved'),
                const SizedBox(width: 8),
                _buildLinearMetricChip('98%', 'Trust Rating'),
              ],
            ),
            const SizedBox(height: 28),

            // Settings Group
            const Text(
              'SETTINGS & PREFERENCES',
              style: TextStyle(
                color: Color(0xFF71717A),
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE4E4E7), width: 1),
              ),
              child: Column(
                children: [
                  _buildLinearSettingTile(LucideIcons.bell, 'Push Notifications', true),
                  const Divider(height: 1, color: Color(0xFFF4F4F5)),
                  _buildLinearSettingTile(LucideIcons.eyeOff, 'Anonymous Reporting', false),
                  const Divider(height: 1, color: Color(0xFFF4F4F5)),
                  _buildLinearSettingAction(LucideIcons.phone, 'Emergency Contacts', '2 guardians'),
                  const Divider(height: 1, color: Color(0xFFF4F4F5)),
                  _buildLinearSettingAction(LucideIcons.fileText, 'Terms & Privacy Policy', null),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Sign Out
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const WelcomeSelectionScreen()),
                    (route) => false,
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFFECACA), width: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  backgroundColor: const Color(0xFFFEF2F2),
                ),
                icon: const Icon(LucideIcons.logOut, size: 16),
                label: const Text('Sign Out', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinearMetricChip(String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE4E4E7), width: 1),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(color: Color(0xFF18181B), fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Color(0xFF71717A), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinearSettingTile(IconData icon, String title, bool value) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: const Color(0xFF71717A), size: 18),
      title: Text(title, style: const TextStyle(color: Color(0xFF18181B), fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: Switch(
        value: value,
        activeThumbColor: const Color(0xFF18181B),
        onChanged: (_) {},
      ),
    );
  }

  Widget _buildLinearSettingAction(IconData icon, String title, String? trailingText) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: const Color(0xFF71717A), size: 18),
      title: Text(title, style: const TextStyle(color: Color(0xFF18181B), fontSize: 14, fontWeight: FontWeight.w600)),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailingText != null)
            Text(trailingText, style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 12)),
          const SizedBox(width: 4),
          const Icon(LucideIcons.chevronRight, color: Color(0xFFA1A1AA), size: 15),
        ],
      ),
    );
  }
}

// ==========================================
// FLUID DRAGGABLE DOCK (Linear Style White/Black)
// ==========================================
class _LinearDraggableDock extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  const _LinearDraggableDock({
    required this.currentIndex,
    required this.onTabSelected,
  });

  @override
  State<_LinearDraggableDock> createState() => _LinearDraggableDockState();
}

class _LinearDraggableDockState extends State<_LinearDraggableDock>
    with TickerProviderStateMixin {
  static const double _itemWidth = 66.0;
  static const double _itemHeight = 44.0;
  static const double _padding = 6.0;
  static const int _itemCount = 3;

  late AnimationController _snapController;
  late Animation<double> _snapAnimation;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  double _dragProgress = 0.0;
  bool _isDragging = false;
  bool _isPointerDown = false;
  int _lastHapticTarget = 0;
  double _velocityStretch = 0.0;

  @override
  void initState() {
    super.initState();
    _dragProgress = widget.currentIndex.toDouble();
    _lastHapticTarget = widget.currentIndex;

    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _snapAnimation = Tween<double>(begin: _dragProgress, end: _dragProgress).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOutBack),
    );
    _snapController.addListener(_onSnapTick);

    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    );
    _expandController.addListener(() {
      setState(() {});
    });
  }

  void _onSnapTick() {
    if (!_isDragging) {
      setState(() {
        _dragProgress = _snapAnimation.value;
      });
    }
  }

  @override
  void didUpdateWidget(covariant _LinearDraggableDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isDragging && widget.currentIndex != oldWidget.currentIndex) {
      _lastHapticTarget = widget.currentIndex;
      _animateTo(widget.currentIndex);
    }
  }

  @override
  void dispose() {
    _snapController.removeListener(_onSnapTick);
    _snapController.dispose();
    _expandController.dispose();
    super.dispose();
  }

  void _animateTo(int targetIndex, {bool withStretch = false}) {
    _snapController.stop();
    final double start = _dragProgress;
    final double end = targetIndex.toDouble();
    final double distance = (end - start).abs();

    _snapAnimation = Tween<double>(
      begin: start,
      end: end,
    ).animate(CurvedAnimation(
      parent: _snapController,
      curve: Curves.easeOutBack,
    ));

    if (withStretch && distance > 0.1) {
      _expandController.forward(from: 0.0).then((_) {
        if (mounted && !_isDragging && !_isPointerDown) {
          _expandController.animateTo(
            0.0,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutBack,
          );
        }
      });
    }

    _snapController.forward(from: 0.0);
  }

  // Expansion triggers the moment user presses/holds on the bar
  void _handlePointerDown(PointerDownEvent event) {
    _isPointerDown = true;
    _snapController.stop();
    _expandController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
    );
    HapticFeedback.selectionClick();
  }

  void _handlePointerUp(PointerUpEvent event) {
    _isPointerDown = false;
    if (!_isDragging) {
      _expandController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutBack,
      );
    }
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _isPointerDown = false;
    _isDragging = false;
    _expandController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
    );
  }

  void _handleDragStart(DragStartDetails details) {
    _snapController.stop();
    _isDragging = true;
    _velocityStretch = 0.0;
    _expandController.animateTo(
      1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
    );
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      final double delta = details.primaryDelta! / _itemWidth;
      final double speed = (details.primaryDelta!).abs();
      _velocityStretch = (_velocityStretch * 0.6 + speed * 1.5).clamp(0.0, 9.0);

      // Fluid rubber band clamping
      _dragProgress = (_dragProgress + delta).clamp(-0.15, (_itemCount - 1) + 0.15);

      final int nearest = _dragProgress.round().clamp(0, _itemCount - 1);
      if (nearest != _lastHapticTarget && (_dragProgress - nearest).abs() < 0.22) {
        HapticFeedback.selectionClick();
        _lastHapticTarget = nearest;
      }
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    _isDragging = false;
    _isPointerDown = false;
    _velocityStretch = 0.0;
    final double velocity = details.primaryVelocity ?? 0.0;
    final double projected = _dragProgress + (velocity / 1200.0);
    final int target = projected.round().clamp(0, _itemCount - 1);

    _lastHapticTarget = target;
    _animateTo(target);

    // Spring contract back to resting pill size
    _expandController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
    );

    if (target != widget.currentIndex) {
      HapticFeedback.lightImpact();
      widget.onTabSelected(target);
    }
  }

  void _handleTapUp(TapUpDetails details) {
    _isDragging = false;
    _isPointerDown = false;
    final double localX = details.localPosition.dx;
    final int tappedIndex = (localX / _itemWidth).floor().clamp(0, _itemCount - 1);
    if (tappedIndex != widget.currentIndex || (_dragProgress - tappedIndex).abs() > 0.05) {
      HapticFeedback.lightImpact();
      _lastHapticTarget = tappedIndex;
      _animateTo(tappedIndex, withStretch: true);
      widget.onTabSelected(tappedIndex);
    }
    _expandController.animateTo(
      0.0,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutBack,
    );
  }

  @override
  Widget build(BuildContext context) {
    const double trackWidth = _itemWidth * _itemCount; // 198.0
    const double dockWidth = trackWidth + (_padding * 2); // 210.0
    const double dockHeight = 52.0;

    // Selector width and height magnification on hold/drag:
    // Resting: 66x44. Magnified on hold/drag: +16px width (82px), +16px height (60px).
    final double extraWidth = 16.0 * _expandAnimation.value + (_isDragging ? _velocityStretch.clamp(0.0, 4.0) : 0.0);
    final double extraHeight = 16.0 * _expandAnimation.value;

    final double currentWidth = _itemWidth + extraWidth;
    final double currentHeight = _itemHeight + extraHeight;

    // Symmetrically center expanded pill around item center
    final double centerX = (_dragProgress + 0.5) * _itemWidth;
    final double visualLeft = centerX - (currentWidth / 2.0);
    // Extends above & below the dock bar when magnified (matches user diagram)
    final double visualTop = - (extraHeight / 2.0);

    return SafeArea(
      top: false,
      child: SizedBox(
        width: dockWidth,
        height: dockHeight,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // 1. Fixed Dock Bar (Elongated rounded capsule behind selector)
            Container(
              width: dockWidth,
              height: dockHeight,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(dockHeight / 2.0),
                border: Border.all(
                  color: const Color(0xFFCBD5E1),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(dockHeight / 2.0),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: const SizedBox.expand(),
                ),
              ),
            ),

            // 2. Interactive Track & Magnifying Pill (extends above and below dock bar)
            SizedBox(
              width: trackWidth,
              height: _itemHeight,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _handlePointerDown,
                  onPointerUp: _handlePointerUp,
                  onPointerCancel: _handlePointerCancel,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: _handleDragStart,
                    onHorizontalDragUpdate: _handleDragUpdate,
                    onHorizontalDragEnd: _handleDragEnd,
                    onTapUp: _handleTapUp,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Liquid Glass Magnifying Pill: specular gradient rim, edge refraction & convex sheen
                        Positioned(
                          left: visualLeft,
                          top: visualTop,
                          width: currentWidth,
                          height: currentHeight,
                          child: Stack(
                            children: [
                              // 1. Ambient Elevation Shadow
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(currentHeight / 2.0),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.02 + 0.04 * _expandAnimation.value),
                                        blurRadius: 3.0 + 4.0 * _expandAnimation.value,
                                        offset: Offset(0, 1.0 + 1.5 * _expandAnimation.value),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // 2. Edge-blurred Meniscus Lens + 3D Convex Liquid Sheen
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(currentHeight / 2.0),
                                  child: ShaderMask(
                                    blendMode: BlendMode.dstIn,
                                    shaderCallback: (Rect bounds) {
                                      return RadialGradient(
                                        center: Alignment.center,
                                        radius: 0.95,
                                        colors: const [
                                          Colors.transparent,
                                          Colors.transparent,
                                          Color(0x59FFFFFF),
                                          Colors.white,
                                        ],
                                        stops: const [0.0, 0.40, 0.75, 1.0],
                                      ).createShader(bounds);
                                    },
                                    child: BackdropFilter(
                                      filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Colors.white.withValues(alpha: 0.08),
                                              Colors.white.withValues(alpha: 0.03),
                                              Colors.white.withValues(alpha: 0.01),
                                            ],
                                            stops: const [0.0, 0.45, 1.0],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // 3. Liquid Specular Gradient Rim (1.0px hairline with top light glint)
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: CustomPaint(
                                    painter: _SpecularGlassBorderPainter(
                                      radius: currentHeight / 2.0,
                                      strokeWidth: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Navigation Items (Magnifies active button icon by 10%)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildDockItem(0, LucideIcons.house, 'Home'),
                            _buildDockItem(1, LucideIcons.inbox, 'Your Reports'),
                            _buildDockItem(2, LucideIcons.user, 'Account'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDockItem(int index, IconData icon, String tooltip) {
    final double dist = (_dragProgress - index).abs().clamp(0.0, 1.0);
    final double activeFactor = (1.0 - dist).clamp(0.0, 1.0);

    final Color iconColor = Color.lerp(
      const Color(0xFF94A3B8), // slate 400 inactive
      const Color(0xFF0F172A), // slate 900 active black
      activeFactor,
    )!;

    // Normal base scale: 0.95 for inactive, 1.00 for active
    final double baseScale = 0.95 + (0.05 * activeFactor);
    // Magnify active button by 10% (1.10x) when selector expands on hold/drag
    final double magnification = 1.0 + (0.10 * activeFactor * _expandAnimation.value);
    final double scale = baseScale * magnification;

    return SizedBox(
      width: _itemWidth,
      height: _itemHeight,
      child: Tooltip(
        message: tooltip,
        child: Center(
          child: Transform.scale(
            scale: scale,
            child: Icon(
              icon,
              size: 22,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

/// Liquid Glass Specular Gradient Border Painter
/// Renders a delicate 1.0px hairline stroke with a brilliant specular glint on top
/// and subtle ambient shadow falloff at the bottom (Apple Liquid Glass).
class _SpecularGlassBorderPainter extends CustomPainter {
  final double radius;
  final double strokeWidth;

  const _SpecularGlassBorderPainter({
    required this.radius,
    this.strokeWidth = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(strokeWidth / 2.0),
      Radius.circular(radius),
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xD9FFFFFF), // 85% specular white glint at top curve
          Color(0x40CBD5E1), // Delicate slate highlight transition
          Color(0x2094A3B8), // Hairline definition on sides
          Color(0x3564748B), // Subtle bottom rim shadow
        ],
        stops: [0.0, 0.30, 0.70, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _SpecularGlassBorderPainter oldDelegate) {
    return oldDelegate.radius != radius || oldDelegate.strokeWidth != strokeWidth;
  }
}
