import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'heatmap_ui/map_screen.dart' hide kCategoryStyles, CategoryStyle;
import 'package:latlong2/latlong.dart' hide Path;
import 'interactive_map/map_screen.dart';
import 'interactive_map/report_model.dart';
import 'interactive_map/report_provider.dart';
import 'interactive_map/street_view_modal.dart';
import 'kanban_board_ui/kanban_board_screen.dart';
import 'instant_capture/instant_camera_screen.dart';
import 'instant_capture/instant_gallery_screen.dart';
import '../services/instant_capture_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/supabase_config.dart';
import '../services/account_preferences.dart';
import '../services/device_service.dart';
import '../theme/unisafe_theme.dart';
import 'SignupLogin_ui/services/digilocker_service.dart';
import 'SignupLogin_ui/services/url_opener.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  int _currentIndex = 0;
  bool _isGallerySelectionMode = false;
  late final PageController _pageController;
  String _selectedInboxFilter = 'All';

  User? _currentUser;
  Map<String, dynamic>? _citizenProfile;
  LatLng? _userLocation;
  bool _isLocating = true;
  List<String> _myDeviceReportIds = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _checkAuthAndLoadProfile();
    _determineUserLocation();
    _loadMyDeviceReportIds();
    AccountPreferences.instance.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _switchTab(int index) {
    if (_currentIndex == index) return;
    final int oldIndex = _currentIndex;
    setState(() => _currentIndex = index);

    if (_pageController.hasClients) {
      final int diff = (index - oldIndex).abs();
      if (diff > 1) {
        // Direct jump between non-adjacent pages (e.g. Home <-> Account):
        // Instant switch with no right/left animation
        _pageController.jumpToPage(index);
      } else {
        // Smooth directional slide for adjacent pages (Home <-> Inbox, Inbox <-> Account)
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  Future<void> _loadMyDeviceReportIds() async {
    final ids = await DeviceService.getMyReportIds();
    if (mounted) {
      setState(() {
        _myDeviceReportIds = ids;
      });
    }
  }

  Future<void> _determineUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _userLocation = const LatLng(19.0760, 72.8777);
            _isLocating = false;
          });
        }
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _userLocation = const LatLng(19.0760, 72.8777);
            _isLocating = false;
          });
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
          _isLocating = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _userLocation = const LatLng(19.0760, 72.8777);
          _isLocating = false;
        });
      }
    }
  }

  Future<void> _checkAuthAndLoadProfile() async {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/citizen-auth-welcome',
            (route) => false,
          );
        }
      });
      return;
    }

    setState(() {
      _currentUser = user;
    });

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
      debugPrint('[AuthProfile] Current user email: ${user.email}, id: ${user.id}, citizenProfile: $data');
      if (mounted) {
        setState(() {
          _citizenProfile = data;
        });
        _loadMyDeviceReportIds();
      }
    } catch (e) {
      debugPrint('[AuthProfile] Error loading citizen profile: $e');
    }
  }

  String get _displayName {
    if (_citizenProfile != null && _citizenProfile!['name'] != null && (_citizenProfile!['name'] as String).trim().isNotEmpty) {
      return (_citizenProfile!['name'] as String).trim();
    }
    if (_citizenProfile != null && _citizenProfile!['username'] != null && (_citizenProfile!['username'] as String).trim().isNotEmpty) {
      return (_citizenProfile!['username'] as String).trim();
    }
    final metaName = _currentUser?.userMetadata?['name'] ?? _currentUser?.userMetadata?['full_name'] ?? _currentUser?.userMetadata?['username'];
    if (metaName != null && metaName.toString().trim().isNotEmpty) {
      return metaName.toString().trim();
    }
    final email = _currentUser?.email;
    if (email != null && email.contains('@')) {
      final handle = email.split('@').first;
      return handle.isNotEmpty ? '${handle[0].toUpperCase()}${handle.substring(1)}' : 'Citizen';
    }
    final phone = _currentUser?.phone;
    if (phone != null && phone.isNotEmpty) {
      return phone;
    }
    return 'Citizen';
  }

  String get _firstName {
    final full = _displayName.trim();
    if (full.isEmpty) return 'Citizen';
    return full.split(RegExp(r'\s+')).first;
  }

  String get _displayEmailOrPhone {
    if (_citizenProfile != null && _citizenProfile!['email'] != null && (_citizenProfile!['email'] as String).trim().isNotEmpty) {
      return _citizenProfile!['email'] as String;
    }
    if (_currentUser?.email != null && _currentUser!.email!.isNotEmpty) {
      return _currentUser!.email!;
    }
    if (_citizenProfile != null && _citizenProfile!['phone'] != null && (_citizenProfile!['phone'] as String).trim().isNotEmpty) {
      return _citizenProfile!['phone'] as String;
    }
    if (_currentUser?.phone != null && _currentUser!.phone!.isNotEmpty) {
      return _currentUser!.phone!;
    }
    return 'citizen@unisafe.org';
  }

  String get _avatarInitials {
    final name = _displayName.trim();
    if (name.isEmpty) return 'U';
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      final first = parts[0].isNotEmpty ? parts[0][0] : '';
      final second = parts[1].isNotEmpty ? parts[1][0] : '';
      final combined = '$first$second'.toUpperCase();
      if (combined.isNotEmpty) return combined;
    }
    return name.substring(0, math.min(2, name.length)).toUpperCase();
  }

  bool get _isVerified {
    if (_citizenProfile != null) {
      if (_citizenProfile!['aadhaar_verified'] == true) return true;
      if (_citizenProfile!['phone_verified'] == true) return true;
      final status = _citizenProfile!['verification_status']?.toString().toUpperCase();
      if (status == 'VERIFIED') return true;
    }
    return _currentUser != null;
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: UniSafeColors.canvas,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
        content: const Text('Are you sure you want to sign out of UniSafe?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF71717A), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await SupabaseConfig.client.auth.signOut();
      } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/citizen-auth-welcome',
        (route) => false,
      );
    }
  }


  String _formatReportStatus(String status) {
    final s = status.toLowerCase().trim();
    if (s == 'resolved' || s == 'done') return 'Done';
    if (s.contains('progress')) return 'In Progress';
    return 'Pending';
  }

  String _formatReportPriority(int upvotes) {
    if (upvotes >= 5) return 'Urgent';
    if (upvotes >= 2) return 'High';
    return 'Normal';
  }

  /// Reports submitted by the signed-in citizen, matched on auth user id,
  /// citizen id or the ids persisted on this device.
  List<ReportModel> _ownedReports(List<ReportModel> reports) {
    final citizenId = _citizenProfile?['id']?.toString();
    final authUserId = _currentUser?.id ?? SupabaseConfig.client.auth.currentUser?.id;

    return reports.where((r) {
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

  bool _isResolvedReport(ReportModel report) {
    final s = report.status.toLowerCase().trim();
    return s == 'resolved' || s == 'done' || s == 'closed';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            // Active Tab Content (Swipeable & Animated Directionally like Instagram)
            PageView(
              controller: _pageController,
              onPageChanged: (index) {
                if (_currentIndex != index) {
                  setState(() {
                    _currentIndex = index;
                    if (index != 2) {
                      _isGallerySelectionMode = false;
                    }
                  });
                }
              },
              children: [
                _KeepAliveWrapper(child: _buildHomeTab()),
                _KeepAliveWrapper(child: _buildInboxTab()),
                _KeepAliveWrapper(
                  child: InstantGalleryScreen(
                    isTab: true,
                    onSelectionModeChanged: (isSelecting) {
                      if (mounted) setState(() => _isGallerySelectionMode = isSelecting);
                    },
                  ),
                ),
                _KeepAliveWrapper(child: _buildAccountTab()),
              ],
            ),

            // Linear-Style Floating Bottom Navigation Dock
            AnimatedPositioned(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              left: 0,
              right: 0,
              bottom: (_currentIndex == 2 && _isGallerySelectionMode) ? -120 : 24,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: (_currentIndex == 2 && _isGallerySelectionMode) ? 0.0 : 1.0,
                child: IgnorePointer(
                  ignoring: _currentIndex == 2 && _isGallerySelectionMode,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: _buildLinearFloatingDock(),
                  ),
                ),
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
      onTabSelected: _switchTab,
    );
  }

  // ==========================================
  // TAB 0: HOME PAGE (Apple HIG Light Mode Dashboard)
  // ==========================================
  // ==========================================
  // TAB 0: HOME / CITIZEN SAFETY DASHBOARD
  // ==========================================
  Widget _buildHomeTab() {
    return Scaffold(
      backgroundColor: UniSafeColors.canvas,
      body: SafeArea(
        bottom: false,
        child: GestureDetector(
          onHorizontalDragEnd: (details) {
            // Drag left-to-right (swipe right)
            if (details.primaryVelocity != null && details.primaryVelocity! > 250) {
              _openInstantCamera();
            }
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 130),
            children: [
              // 1. Native Header (Greeting)
              EntranceReveal(child: _buildHeader()),
              const SizedBox(height: 18),

              // 2. Civic & Safety Bento Grid
              EntranceReveal(child: _buildCivicActions()),
              const SizedBox(height: 26),

              // 3. Neighborhood Safety Feed (Realistic, Beautiful Civic Activity Stream)
              EntranceReveal(child: _buildNeighborhoodFeed()),
            ],
          ),
        ),
      ),
    );
  }

  void _openInstantCamera() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const InstantCameraScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final tween = Tween<Offset>(begin: const Offset(-1.0, 0.0), end: Offset.zero)
              .chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  void _openInstantGallery() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const InstantGalleryScreen()),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  String _greetingTime() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${_greetingTime()},',
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _firstName,
          style: const TextStyle(
            color: Color(0xFF111827),
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            height: 1.15,
          ),
        ),
      ],
    );
  }

  /// High-Impact 2x2 Bento Action Hub
  Widget _buildCivicActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header with live indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: UniSafeColors.teal,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'CIVIC & SAFETY BENTO',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'Ward 12 Hub',
                style: TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Row 1: Interactive Map (Left) & Missing Persons (Right)
        Row(
          children: [
            Expanded(
              child: _buildBentoActionCard(
                icon: LucideIcons.map,
                accentColor: UniSafeColors.navy,
                iconBg: const Color(0xFFEAF3FA),
                iconBorder: const Color(0xFFC8DFEF),
                badgeText: 'LIVE GPS',
                title: 'Interactive Map',
                subtitle: 'Report hazards & safe transit navigation',
                actionText: 'Open Map',
                watermarkIcon: LucideIcons.map,
                onTap: () {
                  Navigator.of(context).push(
                    UniSafePageRoute(builder: (context) => const InteractiveMapScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBentoActionCard(
                icon: LucideIcons.users,
                accentColor: UniSafeColors.amber,
                iconBg: const Color(0xFFFFF5E6),
                iconBorder: const Color(0xFFF6D6A7),
                badgeText: '1 ACTIVE',
                title: 'Missing Persons',
                subtitle: 'AI face search & local police bulletin',
                actionText: 'Search Cases',
                watermarkIcon: LucideIcons.users,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF1E293B),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      content: const Row(
                        children: [
                          Icon(LucideIcons.users, color: Color(0xFFF59E0B), size: 20),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Missing Persons bulletin module is coming soon.',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Row 2: Kanban Board (Left) & Safety Heatmaps (Right)
        Row(
          children: [
            Expanded(
              child: _buildBentoActionCard(
                icon: LucideIcons.kanban,
                accentColor: UniSafeColors.blue,
                iconBg: const Color(0xFFEAF3FA),
                iconBorder: const Color(0xFFC8DFEF),
                badgeText: 'TRIAGE',
                title: 'Kanban Board',
                subtitle: 'Civic issue triage & resolution pipeline',
                actionText: 'Open Board',
                watermarkIcon: LucideIcons.kanban,
                onTap: () {
                  Navigator.of(context).push(
                    UniSafePageRoute(builder: (context) => const KanbanBoardScreen()),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildBentoActionCard(
                icon: LucideIcons.flame,
                accentColor: UniSafeColors.teal,
                iconBg: UniSafeColors.mint,
                iconBorder: const Color(0xFFB9E3DB),
                badgeText: '94% SAFE',
                title: 'Safety Heatmaps',
                subtitle: 'Lighting & crime risk density analysis',
                actionText: 'View Heatmap',
                watermarkIcon: LucideIcons.flame,
                onTap: () {
                  Navigator.of(context).push(
                    UniSafePageRoute(builder: (context) => const MapScreen()),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Unified Bento Action Card (Exact Same Design for All 4 Civic Actions)
  Widget _buildBentoActionCard({
    required IconData icon,
    required Color accentColor,
    required Color iconBg,
    required Color iconBorder,
    required String badgeText,
    required String title,
    required String subtitle,
    required String actionText,
    required IconData watermarkIcon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 168,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                // Corner Watermark Glyph
                Positioned(
                  right: -10,
                  bottom: -10,
                  child: Icon(
                    watermarkIcon,
                    size: 74,
                    color: accentColor.withValues(alpha: 0.05),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Icon + Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: iconBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: iconBorder,
                                width: 0.8,
                              ),
                            ),
                            child: Icon(
                              icon,
                              size: 18,
                              color: accentColor,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: iconBg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: iconBorder,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: accentColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  badgeText,
                                  style: TextStyle(
                                    color: accentColor,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),

                      // Title & Subtitle
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          maxLines: 1,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 10.5,
                          height: 1.22,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Bottom Action Trigger
                      Row(
                        children: [
                          Text(
                            actionText,
                            style: TextStyle(
                              color: accentColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            LucideIcons.arrowRight,
                            size: 11,
                            color: accentColor,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Real-Time Neighborhood Safety & Civic Activity Feed (Within 3 km Radius)
  Widget _buildNeighborhoodFeed() {
    final liveReports = ref.watch(interactiveReportProvider);
    final userLoc = _userLocation ?? const LatLng(19.0760, 72.8777);
    const distanceCalc = Distance();

    // 1. Filter reports to strictly within 3 km (3000 meters)
    final reportsWithin3Km = <_ReportWithDistance>[];
    for (final report in liveReports) {
      final meters = distanceCalc.as(LengthUnit.Meter, userLoc, report.location);
      if (meters <= 3000.0) {
        reportsWithin3Km.add(_ReportWithDistance(report, meters));
      }
    }

    // 2. Priority-Weighted Sorting: Higher upvote count first (urgent issues bubble up), then proximity
    reportsWithin3Km.sort((a, b) {
      final upvoteCmp = b.report.upvoteCount.compareTo(a.report.upvoteCount);
      if (upvoteCmp != 0) return upvoteCmp;
      return a.distanceMeters.compareTo(b.distanceMeters);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.radio, size: 14, color: Color(0xFF2563EB)),
            const SizedBox(width: 7),
            const Expanded(
              child: Text(
                'NEIGHBORHOOD ACTIVITY',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Text(
                'Within 3 km • ${reportsWithin3Km.length} active',
                style: const TextStyle(
                  color: Color(0xFF1D4ED8),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        if (_isLocating && reportsWithin3Km.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Detecting neighborhood radius...',
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (reportsWithin3Km.isEmpty)
          // Strict Empty State when no reports within 3 km
          _buildStrictEmptyState()
        else
          ...reportsWithin3Km.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _buildNeighborhoodActivityCard(item.report, item.distanceMeters),
              )),
      ],
    );
  }

  /// Strict Empty State card when no safety hazards exist within 3 km
  Widget _buildStrictEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x04000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: const Icon(
              LucideIcons.shieldCheck,
              color: Color(0xFF059669),
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'All Clear Within 3 km',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'No safety or civic issues reported within your 3 km neighborhood radius. Keep your community safe by reporting any hazards you spot.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const InteractiveMapScreen()),
              );
            },
            icon: const Icon(LucideIcons.plusCircle, size: 16, color: Color(0xFF0F172A)),
            label: const Text(
              'Report a Hazard on Map',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Hero Media Card for a verified neighborhood report
  Widget _buildNeighborhoodActivityCard(ReportModel report, double distanceMeters) {
    final upvotedIds = ref.watch(upvotedReportsProvider);
    final isUpvoted = upvotedIds.contains(report.id);
    final categoryStyle = kCategoryStyles[report.category] ?? kCategoryStyles[IssueCategory.infrastructure]!;

    // Priority badge based on community upvote count
    final bool isCriticalPriority = report.upvoteCount >= 5;
    final bool isHighPriority = report.upvoteCount >= 2 && report.upvoteCount < 5;

    final hasImage = report.imageBytes != null ||
        (report.imagePath != null &&
            report.imagePath!.isNotEmpty &&
            !report.imagePath!.startsWith('blob:'));

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCriticalPriority
              ? const Color(0xFFFCA5A5)
              : (isHighPriority ? const Color(0xFFFDE68A) : const Color(0xFFE5E7EB)),
          width: isCriticalPriority || isHighPriority ? 1.4 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: isCriticalPriority
                ? const Color(0x14EF4444)
                : const Color(0x06000000),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Meta Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                // Category Icon Badge
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: categoryStyle.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(categoryStyle.icon, size: 16, color: categoryStyle.color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${categoryStyle.label} • ${_formatReportTime(report.createdAt)}',
                        style: const TextStyle(
                          color: Color(0xFF6B7280),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (report.citizenName != null && report.citizenName!.isNotEmpty)
                        Text(
                          'Reported by ${report.citizenName}',
                          style: const TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),

                // Priority Badge based on upvotes
                if (isCriticalPriority)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.flame, size: 11, color: Color(0xFFDC2626)),
                        SizedBox(width: 4),
                        Text(
                          'Urgent Priority',
                          style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (isHighPriority)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(LucideIcons.zap, size: 11, color: Color(0xFFD97706)),
                        SizedBox(width: 4),
                        Text(
                          'High Priority',
                          style: TextStyle(
                            color: Color(0xFFD97706),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      report.status.toUpperCase(),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // 2. Title & Description
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                if (report.address != null && report.address!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(LucideIcons.mapPin, size: 12, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          report.address!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                if (report.description.isNotEmpty && report.description != report.title) ...[
                  const SizedBox(height: 6),
                  Text(
                    report.description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF4B5563),
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 3. Hero Photo Banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: GestureDetector(
                onTap: hasImage
                    ? () => _openFullScreenImage(
                          imageBytes: report.imageBytes,
                          imagePath: report.imagePath,
                          title: report.title,
                        )
                    : null,
                child: Stack(
                  children: [
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        gradient: !hasImage
                            ? LinearGradient(
                                colors: [
                                  categoryStyle.color.withValues(alpha: 0.08),
                                  categoryStyle.color.withValues(alpha: 0.02),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                      ),
                      child: hasImage
                          ? (report.imageBytes != null
                              ? Image.memory(
                                  report.imageBytes!,
                                  fit: BoxFit.cover,
                                )
                              : (report.imagePath!.startsWith('data:image')
                                  ? Image.memory(
                                      base64Decode(report.imagePath!.split(',').last),
                                      fit: BoxFit.cover,
                                    )
                                  : (report.imagePath!.startsWith('http')
                                      ? Image.network(
                                          report.imagePath!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(categoryStyle),
                                        )
                                      : Image.asset(
                                          report.imagePath!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => _buildImagePlaceholder(categoryStyle),
                                        ))))
                          : _buildImagePlaceholder(categoryStyle),
                    ),
                    if (hasImage)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.maximize2, color: Colors.white, size: 11),
                              SizedBox(width: 4),
                              Text(
                                'Full Screen',
                                style: TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 4. Open 360° Street View Action Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  StreetViewModal.show(
                    context,
                    latitude: report.location.latitude,
                    longitude: report.location.longitude,
                    title: report.title,
                  );
                },
                icon: const Icon(LucideIcons.compass, size: 17, color: Color(0xFF059669)),
                label: const Text(
                  'Open 360° Street View',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF059669),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: const Color(0xFF059669).withValues(alpha: 0.06),
                  side: BorderSide(
                    color: const Color(0xFF059669).withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // 5. Card Footer: Distance Indicator & Upvote Action
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(19)),
              border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Distance badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(LucideIcons.navigation, size: 12, color: Color(0xFF2563EB)),
                      const SizedBox(width: 5),
                      Text(
                        _formatDistance(distanceMeters),
                        style: const TextStyle(
                          color: Color(0xFF334155),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Interactive Upvote Toggle Button
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ref.read(upvotedReportsProvider.notifier).toggle(report.id);
                      ref.read(interactiveReportProvider.notifier).toggleUpvote(report.id, isUpvoted);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
                      decoration: BoxDecoration(
                        color: isUpvoted ? const Color(0xFFEFF6FF) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isUpvoted ? const Color(0xFF3B82F6) : const Color(0xFFCBD5E1),
                          width: isUpvoted ? 1.4 : 1.0,
                        ),
                        boxShadow: isUpvoted
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isUpvoted ? LucideIcons.thumbsUp : LucideIcons.thumbsUp,
                            size: 14,
                            color: isUpvoted ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isUpvoted ? 'Upvoted (${report.upvoteCount})' : 'Upvote (${report.upvoteCount})',
                            style: TextStyle(
                              color: isUpvoted ? const Color(0xFF2563EB) : const Color(0xFF334155),
                              fontSize: 12,
                              fontWeight: isUpvoted ? FontWeight.w800 : FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder(CategoryStyle categoryStyle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            categoryStyle.icon,
            size: 38,
            color: categoryStyle.color.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 6),
          Text(
            'Scene photo not attached • 360° Street View available',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B).withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m away';
    } else {
      return '${(meters / 1000.0).toStringAsFixed(1)} km away';
    }
  }

  String _formatReportTime(DateTime? dt) {
    if (dt == null) return 'Just now';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  void _openFullScreenImage({Uint8List? imageBytes, String? imagePath, String? title}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(color: Colors.transparent),
                ),
              ),
              Center(
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: imageBytes != null
                      ? Image.memory(imageBytes, fit: BoxFit.contain)
                      : (imagePath != null && imagePath.startsWith('data:image')
                          ? Image.memory(base64Decode(imagePath.split(',').last), fit: BoxFit.contain)
                          : (imagePath != null && imagePath.startsWith('http')
                              ? Image.network(imagePath, fit: BoxFit.contain)
                              : (imagePath != null && imagePath.isNotEmpty && !imagePath.startsWith('blob:')
                                  ? Image.asset(imagePath, fit: BoxFit.contain)
                                  : const Icon(LucideIcons.image, size: 80, color: Colors.white54)))),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      if (title != null && title.isNotEmpty)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(LucideIcons.x, color: Colors.white, size: 22),
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ==========================================
  // TAB 1: INBOX / YOUR REPORTS (Linear Style)
  // ==========================================
  Widget _buildInboxTab() {
    final liveReports = ref.watch(interactiveReportProvider);

    // Filter strictly to reports submitted by this user (by auth user ID, citizen ID, or device-persisted ID)
    final allReports = <Map<String, dynamic>>[];
    for (final r in _ownedReports(liveReports)) {
      final statusDisplay = _formatReportStatus(r.status);
      final isUnread = r.status.toLowerCase() == 'pending' || r.status.toLowerCase() == 'triage';

      allReports.add({
        'id': r.id.length >= 8 ? 'uni-${r.id.substring(0, 8)}' : 'uni-${r.id}',
        'realId': r.id,
        'title': r.title,
        'category': r.category,
        'status': statusDisplay,
        'rawStatus': r.status,
        'author': 'submitted by you',
        'time': _formatReportTime(r.createdAt),
        'createdAt': r.createdAt,
        'unread': isUnread,
        'priority': _formatReportPriority(r.upvoteCount),
        'description': r.description,
        'location': (r.address != null && r.address!.trim().isNotEmpty)
            ? r.address!
            : '${r.location.latitude.toStringAsFixed(3)}, ${r.location.longitude.toStringAsFixed(3)}',
        'targetCoord': r.location,
        'imagePath': r.imagePath,
        'imageBytes': r.imageBytes,
        'upvoteCount': r.upvoteCount,
        'assignedAuthorityId': r.assignedAuthorityId,
        'assignedOfficerName': r.assignedOfficerName,
        'assignedOfficerPhone': r.assignedOfficerPhone,
        'assignedOfficerDepartment': r.assignedOfficerDepartment,
        'assignedOfficerJurisdiction': r.assignedOfficerJurisdiction,
        'assignedOfficerRole': r.assignedOfficerRole,
        'assignedOfficerAvatar': r.assignedOfficerAvatar,
        'assignedOfficerSolvedCount': r.assignedOfficerSolvedCount,
      });
    }

    final filtered = allReports.where((r) {
      if (_selectedInboxFilter == 'All') return true;
      if (_selectedInboxFilter == 'Unread') return r['unread'] == true;
      return (r['status'] as String).toLowerCase() == _selectedInboxFilter.toLowerCase();
    }).toList();

    int countFor(String filter) {
      if (filter == 'All') return allReports.length;
      if (filter == 'Unread') return allReports.where((r) => r['unread'] == true).length;
      return allReports
          .where((r) => (r['status'] as String).toLowerCase() == filter.toLowerCase())
          .length;
    }

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
            tooltip: 'Report an issue',
          ),
          IconButton(
            onPressed: () async {
              await _loadMyDeviceReportIds();
              ref.invalidate(interactiveReportProvider);
            },
            icon: const Icon(LucideIcons.refreshCw, color: Color(0xFF71717A), size: 18),
            tooltip: 'Refresh',
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
                _buildInboxFilterChip('All', countFor('All')),
                const SizedBox(width: 8),
                _buildInboxFilterChip('Unread', countFor('Unread')),
                const SizedBox(width: 8),
                _buildInboxFilterChip('In Progress', countFor('In Progress')),
                const SizedBox(width: 8),
                _buildInboxFilterChip('Done', countFor('Done')),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: allReports.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F4F5),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE4E4E7)),
                        ),
                        child: const Icon(
                          LucideIcons.inbox,
                          size: 32,
                          color: Color(0xFF71717A),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'No reports yet',
                        style: TextStyle(
                          color: Color(0xFF18181B),
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Reports you file from the map land here, with their live status and resolution progress.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF71717A),
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const InteractiveMapScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF18181B),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(LucideIcons.plus, size: 16),
                        label: const Text(
                          'Report an Issue',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : filtered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF4F4F5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.inbox,
                              size: 26,
                              color: Color(0xFFA1A1AA),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Nothing in $_selectedInboxFilter',
                            style: const TextStyle(
                              color: Color(0xFF18181B),
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'You have ${allReports.length} report${allReports.length == 1 ? '' : 's'} in total.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFFA1A1AA),
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 18),
                          TextButton(
                            onPressed: () => setState(() => _selectedInboxFilter = 'All'),
                            child: const Text(
                              'Show all reports',
                              style: TextStyle(
                                color: Color(0xFF18181B),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _buildInboxTimeline(filtered),
      ),
    );
  }

  String _inboxDayLabel(DateTime? createdAt) {
    if (createdAt == null) return 'Earlier';
    final now = DateTime.now();
    final day = DateTime(createdAt.year, createdAt.month, createdAt.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return 'This week';
    if (diff < 30) return 'This month';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    if (createdAt.year == now.year) return '${months[createdAt.month - 1]} ${createdAt.day}';
    return '${months[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}';
  }

  Widget _buildInboxTimeline(List<Map<String, dynamic>> reports) {
    final entries = <Widget>[];
    String? lastLabel;

    for (final item in reports) {
      final label = _inboxDayLabel(item['createdAt'] as DateTime?);
      if (label != lastLabel) {
        if (entries.isNotEmpty) entries.add(const SizedBox(height: 18));
        entries.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 10),
            child: Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFA1A1AA),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(child: Divider(height: 1, thickness: 1, color: Color(0xFFF1F1F3))),
              ],
            ),
          ),
        );
        lastLabel = label;
      }
      entries.add(_buildLinearInboxItem(item));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
      children: entries,
    );
  }

  Widget _buildInboxFilterChip(String label, int count) {
    final isSelected = _selectedInboxFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedInboxFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF18181B) : const Color(0xFFF4F4F5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF71717A),
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Text(
                '$count',
                style: TextStyle(
                  color: isSelected ? const Color(0xFFA1A1AA) : const Color(0xFFA1A1AA),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLinearInboxItem(Map<String, dynamic> item) {
    final bool isUnread = item['unread'] as bool;
    final String status = item['status'] as String;
    final String priority = item['priority'] as String;
    final categoryStyle =
        kCategoryStyles[item['category']] ?? kCategoryStyles[IssueCategory.infrastructure]!;

    final bool hasImage = item['imageBytes'] != null ||
        (item['imagePath'] != null && (item['imagePath'] as String).isNotEmpty);

    Color accent;
    if (status.contains('Done')) {
      accent = const Color(0xFF10B981);
    } else if (status.contains('In Progress')) {
      accent = const Color(0xFFF59E0B);
    } else {
      accent = const Color(0xFF3B82F6);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showLinearIssueModal(item),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: isUnread ? accent : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item['title'] as String,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFF18181B),
                              fontSize: 14.5,
                              height: 1.3,
                              fontWeight: isUnread ? FontWeight.w700 : FontWeight.w500,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _buildInboxStatusPill(status, accent),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Padding(
                      padding: const EdgeInsets.only(left: 14),
                      child: Row(
                        children: [
                          Icon(
                            categoryStyle.icon,
                            size: 13,
                            color: const Color(0xFFA1A1AA),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              categoryStyle.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFFA1A1AA),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          Text(
                            '  ·  ${item['time']}',
                            style: const TextStyle(
                              color: Color(0xFFA1A1AA),
                              fontSize: 12.5,
                            ),
                          ),
                          if (priority != 'Normal') ...[
                            const SizedBox(width: 8),
                            _buildInboxPriorityPill(priority),
                          ],
                        ],
                      ),
                    ),
                    if (item['assignedOfficerName'] != null && (item['assignedOfficerName'] as String).isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 14),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.userCheck, size: 12, color: Color(0xFF059669)),
                            const SizedBox(width: 4),
                            Text(
                              'Handled by ${item['assignedOfficerName']}',
                              style: const TextStyle(
                                color: Color(0xFF059669),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (item['assignedOfficerPhone'] != null && (item['assignedOfficerPhone'] as String).isNotEmpty) ...[
                              Text(
                                ' · ${item['assignedOfficerPhone']}',
                                style: const TextStyle(
                                  color: Color(0xFF71717A),
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (hasImage) ...[
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 46,
                    height: 46,
                    child: item['imageBytes'] != null
                        ? Image.memory(item['imageBytes'] as Uint8List, fit: BoxFit.cover)
                        : (item['imagePath'] as String).startsWith('data:image')
                            ? Image.memory(base64Decode((item['imagePath'] as String).split(',').last), fit: BoxFit.cover)
                            : ((item['imagePath'] as String).startsWith('http')
                                ? Image.network(item['imagePath'] as String, fit: BoxFit.cover)
                                : _buildImagePlaceholder(categoryStyle)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInboxStatusPill(String status, Color accent) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 9, 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: accent,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Widget _buildInboxPriorityPill(String priority) {
    final color = priority == 'Urgent' ? const Color(0xFFDC2626) : const Color(0xFFB45309);
    return Container(
      padding: const EdgeInsets.fromLTRB(7, 3, 7, 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        priority,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  void _showLinearIssueModal(Map<String, dynamic> item) {
    final parentNavigator = Navigator.of(context);

    LatLng? targetCoord = item['targetCoord'] as LatLng?;
    if (targetCoord == null) {
      final locStr = item['location'] as String?;
      if (locStr != null && locStr.contains(',')) {
        final parts = locStr.split(',');
        if (parts.length == 2) {
          final lat = double.tryParse(parts[0].trim());
          final lng = double.tryParse(parts[1].trim());
          if (lat != null && lng != null) {
            targetCoord = LatLng(lat, lng);
          }
        }
      }
    }

    final bool hasImage = item['imageBytes'] != null ||
        (item['imagePath'] != null && (item['imagePath'] as String).isNotEmpty);
    final int upvotes = (item['upvoteCount'] as int?) ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(sheetContext).padding.bottom + 24),
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
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (item['status'] == 'Done')
                          ? const Color(0xFFDCFCE7)
                          : (item['status'] == 'In Progress' ? const Color(0xFFFEF3C7) : const Color(0xFFDBEAFE)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item['status'] as String,
                      style: TextStyle(
                        color: (item['status'] == 'Done')
                            ? const Color(0xFF15803D)
                            : (item['status'] == 'In Progress' ? const Color(0xFFB45309) : const Color(0xFF1D4ED8)),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(sheetContext),
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
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(LucideIcons.mapPin, color: Color(0xFF71717A), size: 15),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item['location'] as String,
                      style: const TextStyle(color: Color(0xFF71717A), fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (upvotes > 0) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.chevronUp, size: 13, color: Color(0xFF2563EB)),
                          const SizedBox(width: 3),
                          Text(
                            '$upvotes ${upvotes == 1 ? 'upvote' : 'upvotes'}',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF2563EB)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              if (hasImage) ...[
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: () {
                    _openFullScreenImage(
                      imagePath: item['imagePath'] as String?,
                      imageBytes: item['imageBytes'] as Uint8List?,
                      title: item['title'] as String?,
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 140,
                      width: double.infinity,
                      color: const Color(0xFFF4F4F5),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (item['imageBytes'] != null)
                            Image.memory(item['imageBytes'] as Uint8List, fit: BoxFit.cover)
                          else if (item['imagePath'] != null && (item['imagePath'] as String).startsWith('data:image'))
                            Image.memory(base64Decode((item['imagePath'] as String).split(',').last), fit: BoxFit.cover)
                          else if (item['imagePath'] != null && (item['imagePath'] as String).startsWith('http'))
                            Image.network(item['imagePath'] as String, fit: BoxFit.cover)
                          else
                            const Icon(LucideIcons.image, size: 36, color: Color(0xFFA1A1AA)),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.maximize2, size: 12, color: Colors.white),
                                  SizedBox(width: 4),
                                  Text('Tap to expand', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
              // Handling Officer Details (Name, Phone, Solved Score)
              if (item['assignedOfficerName'] != null && (item['assignedOfficerName'] as String).isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Officer Avatar / Photo
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE0E7FF),
                              borderRadius: BorderRadius.circular(13),
                              border: Border.all(color: const Color(0xFFC7D2FE)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: (item['assignedOfficerAvatar'] != null && (item['assignedOfficerAvatar'] as String).isNotEmpty)
                                ? Image.network(
                                    item['assignedOfficerAvatar'] as String,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Center(
                                      child: Text(
                                        (item['assignedOfficerName'] as String).isNotEmpty
                                            ? (item['assignedOfficerName'] as String).substring(0, math.min(2, (item['assignedOfficerName'] as String).length)).toUpperCase()
                                            : 'OF',
                                        style: const TextStyle(
                                          color: Color(0xFF4338CA),
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  )
                                : Center(
                                    child: Text(
                                      (item['assignedOfficerName'] as String).isNotEmpty
                                          ? (item['assignedOfficerName'] as String).substring(0, math.min(2, (item['assignedOfficerName'] as String).length)).toUpperCase()
                                          : 'OF',
                                      style: const TextStyle(
                                        color: Color(0xFF4338CA),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        item['assignedOfficerName'] as String,
                                        style: const TextStyle(
                                          color: Color(0xFF0F172A),
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDCFCE7),
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(color: const Color(0xFFBBF7D0)),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(LucideIcons.shieldCheck, size: 10, color: Color(0xFF15803D)),
                                          SizedBox(width: 3),
                                          Text(
                                            'Assigned',
                                            style: TextStyle(
                                              color: Color(0xFF15803D),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${item['assignedOfficerRole'] ?? 'Field Officer'} · ${item['assignedOfficerDepartment'] ?? 'BMC Operations'}',
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 11),
                      Row(
                        children: [
                          // Solved Cases & Score Badge
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFECFDF5),
                                borderRadius: BorderRadius.circular(9),
                                border: Border.all(color: const Color(0xFFA7F3D0)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(LucideIcons.checkCircle2, size: 15, color: Color(0xFF059669)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: '${item['assignedOfficerSolvedCount'] ?? 14} Cases Solved',
                                            style: const TextStyle(
                                              color: Color(0xFF047857),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const TextSpan(
                                            text: ' · 98% Score',
                                            style: TextStyle(
                                              color: Color(0xFF059669),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (item['assignedOfficerPhone'] != null && (item['assignedOfficerPhone'] as String).isNotEmpty) ...[
                            const SizedBox(width: 8),
                            // Quick Call Button
                            InkWell(
                              onTap: () async {
                                final phone = (item['assignedOfficerPhone'] as String).replaceAll(RegExp(r'[^\\d+]'), '');
                                final uri = Uri.parse('tel:$phone');
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                }
                              },
                              borderRadius: BorderRadius.circular(9),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(9),
                                  border: Border.all(color: const Color(0xFFBFDBFE)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(LucideIcons.phoneCall, size: 13, color: Color(0xFF2563EB)),
                                    const SizedBox(width: 5),
                                    Text(
                                      item['assignedOfficerPhone'] as String,
                                      style: const TextStyle(
                                        color: Color(0xFF1D4ED8),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final coord = targetCoord ?? const LatLng(12.9716, 77.5946);
                        StreetViewModal.show(
                          sheetContext,
                          latitude: coord.latitude,
                          longitude: coord.longitude,
                          title: item['title'] as String?,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF18181B),
                        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(LucideIcons.compass, size: 16),
                      label: const Text('Street View', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        parentNavigator.push(
                          MaterialPageRoute(
                            builder: (_) => InteractiveMapScreen(
                              initialCenter: targetCoord,
                              initialReportId: (item['realId'] ?? item['id']) as String?,
                            ),
                          ),
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
    final myReports = _ownedReports(ref.watch(interactiveReportProvider));
    final resolvedCount = myReports.where(_isResolvedReport).length;
    final openCount = myReports.length - resolvedCount;
    final resolutionRate = myReports.isEmpty ? 0.0 : resolvedCount / myReports.length;

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
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFF4F4F5), height: 1),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 130),
          children: [
            _buildAccountIdentityCard(),
            const SizedBox(height: 26),
            _buildAccountSectionLabel('YOUR SAFETY RECORD'),
            const SizedBox(height: 10),
            _buildAccountImpactCard(
              filed: myReports.length,
              resolved: resolvedCount,
              open: openCount,
              resolutionRate: resolutionRate,
            ),
            const SizedBox(height: 26),
            _buildAccountSectionLabel('PREFERENCES'),
            const SizedBox(height: 10),
            _buildAccountGroup([
              _buildAccountToggleRow(
                icon: LucideIcons.bell,
                title: 'Push notifications',
                subtitle: 'Alerts when a report you filed changes status',
                value: AccountPreferences.instance.pushNotificationsEnabled,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  AccountPreferences.instance.setPushNotifications(value);
                  setState(() {});
                },
              ),
            ]),
            const SizedBox(height: 26),
            _buildAccountSectionLabel('SAFETY NETWORK'),
            const SizedBox(height: 10),
            _buildAccountGroup([
              _buildAccountNavRow(
                icon: LucideIcons.phoneCall,
                title: 'Emergency contacts',
                subtitle: 'Guardians notified when you raise an SOS',
                onTap: () => _showAccountInfoSheet(
                  icon: LucideIcons.phoneCall,
                  title: 'Emergency contacts',
                  lines: const [
                    'No guardians are linked to this account yet.',
                    'Once a guardian is added, they receive your live location and the report attached to your SOS until you mark yourself safe.',
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 26),
            _buildAccountSectionLabel('LEGAL'),
            const SizedBox(height: 10),
            _buildAccountGroup([
              _buildAccountNavRow(
                icon: LucideIcons.shieldCheck,
                title: 'Terms & privacy',
                subtitle: 'What UniSafe stores, and why',
                onTap: () => _showAccountInfoSheet(
                  icon: LucideIcons.shieldCheck,
                  title: 'Terms & privacy',
                  lines: const [
                    'UniSafe stores the name and the email or phone number you signed up with, plus the reports you file.',
                    'Your location is read while the map is open so you and your reports can be placed on it.',
                    'Photos you attach stay on this device until you submit the report.',
                  ],
                  footnote:
                      'These notes summarise how the app handles your data. The full policy is issued by your campus safety office.',
                ),
              ),
            ]),
            const SizedBox(height: 26),
            _buildAccountSignOut(),
            const SizedBox(height: 16),
            const Text(
              'UniSafe · v1.0.0',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFFA1A1AA),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? get _memberSinceLabel {
    final raw = _citizenProfile?['created_at']?.toString();
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return 'Member since ${months[parsed.month - 1]} ${parsed.year}';
  }

  Widget _buildAccountSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFFA1A1AA),
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.9,
      ),
    );
  }

  Widget _buildAccountIdentityCard() {
    final verified = _isVerified;
    final memberSince = _memberSinceLabel;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E4E7), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAccountAvatar(verified),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF18181B),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _displayEmailOrPhone,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Color(0xFF71717A),
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _buildAccountStatusPill(verified),
                        InkWell(
                          onTap: _showDigiLockerSyncModal,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(9, 4, 10, 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.camera, size: 12, color: Color(0xFF2563EB)),
                                const SizedBox(width: 5),
                                Text(
                                  AccountPreferences.instance.citizenAadhaarPhoto != null
                                      ? 'Update Photo'
                                      : 'Sync Photo',
                                  style: const TextStyle(
                                    color: Color(0xFF1D4ED8),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (memberSince != null) ...[
            const SizedBox(height: 16),
            Container(height: 1, color: const Color(0xFFECECEE)),
            const SizedBox(height: 12),
            Text(
              memberSince,
              style: const TextStyle(
                color: Color(0xFFA1A1AA),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountAvatar(bool verified) {
    final photoBase64 = AccountPreferences.instance.citizenAadhaarPhoto;
    final hasValidPhoto = photoBase64 != null && photoBase64.isNotEmpty;

    return GestureDetector(
      onTap: _showDigiLockerSyncModal,
      child: Tooltip(
        message: hasValidPhoto ? 'Tap to update DigiLocker photo' : 'Tap to sync DigiLocker photo',
        child: SizedBox(
          width: 60,
          height: 60,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF18181B),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [
                    BoxShadow(color: Color(0x14000000), blurRadius: 14, offset: Offset(0, 6)),
                  ],
                ),
                child: ClipOval(
                  child: hasValidPhoto
                      ? Image.memory(
                          base64Decode(photoBase64.contains(',') ? photoBase64.split(',').last : photoBase64),
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Text(
                              _avatarInitials,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            _avatarInitials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                ),
              ),
              if (verified)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF10B981),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      LucideIcons.check,
                      size: 11,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountStatusPill(bool verified) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: verified ? const Color(0xFFECFDF5) : const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: verified ? const Color(0xFFA7F3D0) : const Color(0xFFE4E4E7),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            verified ? LucideIcons.badgeCheck : LucideIcons.userRound,
            size: 12,
            color: verified ? const Color(0xFF059669) : const Color(0xFF71717A),
          ),
          const SizedBox(width: 5),
          Text(
            verified ? 'VERIFIED CITIZEN' : 'REGISTERED CITIZEN',
            style: TextStyle(
              color: verified ? const Color(0xFF059669) : const Color(0xFF71717A),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDigiLockerSyncModal() async {
    final digiService = DigiLockerService();
    String statusMessage = 'Connecting to DigiLocker Sandbox...';
    bool isInitializing = true;
    bool isSuccess = false;
    String? errorMessage;
    String? sessionId;
    Timer? pollTimer;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void stopPolling() {
              pollTimer?.cancel();
              pollTimer = null;
            }

            Future<void> completeSync(String currentSessionId) async {
              stopPolling();
              setModalState(() {
                statusMessage = 'Fetching official Aadhaar photograph...';
              });
              try {
                final docRes = await digiService.fetchUserProfile(currentSessionId);
                if (docRes['success'] == true && docRes['profile'] is Map) {
                  final profile = docRes['profile'] as Map;
                  final photoBase64 = profile['photo']?.toString() ??
                      profile['image']?.toString() ??
                      profile['user_photo']?.toString();
                  if (photoBase64 != null && photoBase64.isNotEmpty) {
                    await AccountPreferences.instance.setCitizenAadhaarPhoto(photoBase64);
                    if (mounted) setState(() {});
                    setModalState(() {
                      isSuccess = true;
                      statusMessage = 'Official Aadhaar photo synced successfully!';
                    });
                    await Future.delayed(const Duration(milliseconds: 1400));
                    if (bottomSheetContext.mounted) {
                      Navigator.of(bottomSheetContext).pop();
                    }
                    return;
                  }
                }
                setModalState(() {
                  errorMessage = 'Could not find photo in DigiLocker profile payload.';
                });
              } catch (e) {
                setModalState(() {
                  errorMessage = 'Error retrieving document: $e';
                });
              }
            }

            void checkStatusManual() async {
              if (sessionId == null) return;
              setModalState(() {
                statusMessage = 'Checking verification status...';
              });
              try {
                final res = await digiService.checkStatus(sessionId!);
                final status = (res['status'] ?? '').toString().toLowerCase();
                if (status == 'completed' || status == 'success' || status == 'succeeded' || status == 'approved') {
                  await completeSync(sessionId!);
                } else if (status == 'failed' || status == 'denied') {
                  stopPolling();
                  setModalState(() {
                    errorMessage = 'Verification was cancelled or denied on DigiLocker.';
                  });
                } else {
                  setModalState(() {
                    statusMessage = 'Status: $status. Please finish login in browser tab.';
                  });
                }
              } catch (e) {
                setModalState(() {
                  errorMessage = 'Connection error: $e';
                });
              }
            }

            void startInit() async {
              try {
                final res = await digiService.initSession();
                if (res['success'] == true && res['authorization_url'] != null) {
                  sessionId = res['session_id'];
                  final authUrl = res['authorization_url'] as String;
                  openUrlInNewTab(authUrl);
                  setModalState(() {
                    isInitializing = false;
                    statusMessage = 'DigiLocker portal opened in a new tab.\nPlease complete authentication.';
                  });

                  pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
                    if (sessionId == null) {
                      timer.cancel();
                      return;
                    }
                    try {
                      final statusRes = await digiService.checkStatus(sessionId!);
                      final status = (statusRes['status'] ?? '').toString().toLowerCase();
                      if (status == 'completed' || status == 'success' || status == 'succeeded' || status == 'approved') {
                        timer.cancel();
                        await completeSync(sessionId!);
                      } else if (status == 'failed' || status == 'denied') {
                        timer.cancel();
                        setModalState(() {
                          errorMessage = 'Authorization was cancelled or denied.';
                        });
                      }
                    } catch (_) {}
                  });
                } else {
                  setModalState(() {
                    isInitializing = false;
                    errorMessage = res['message']?.toString() ?? 'Failed to initialize DigiLocker session.';
                  });
                }
              } catch (e) {
                setModalState(() {
                  isInitializing = false;
                  errorMessage = 'Could not reach DigiLocker Sandbox: $e';
                });
              }
            }

            if (isInitializing && sessionId == null && errorMessage == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) => startInit());
            }

            return PopScope(
              onPopInvokedWithResult: (didPop, result) => stopPolling(),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE4E4E7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (isSuccess) ...[
                      const Icon(LucideIcons.circleCheck, color: Color(0xFF10B981), size: 48),
                      const SizedBox(height: 14),
                      const Text(
                        'Photo Synced!',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF18181B)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF71717A)),
                      ),
                      const SizedBox(height: 16),
                    ] else if (errorMessage != null) ...[
                      const Icon(LucideIcons.triangleAlert, color: Color(0xFFEF4444), size: 48),
                      const SizedBox(height: 14),
                      const Text(
                        'Sync Failed',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF18181B)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        errorMessage!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: Color(0xFFEF4444)),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                stopPolling();
                                Navigator.of(bottomSheetContext).pop();
                              },
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Close'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                setModalState(() {
                                  errorMessage = null;
                                  isInitializing = true;
                                  sessionId = null;
                                  statusMessage = 'Connecting to DigiLocker...';
                                });
                                startInit();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('Retry', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(
                        width: 38,
                        height: 38,
                        child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF2563EB)),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Syncing DigiLocker Photo',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF18181B)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF71717A), height: 1.35),
                      ),
                      const SizedBox(height: 20),
                      if (!isInitializing) ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  stopPolling();
                                  Navigator.of(bottomSheetContext).pop();
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: checkStatusManual,
                                icon: const Icon(LucideIcons.refreshCw, size: 14, color: Colors.white),
                                label: const Text('Check Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    pollTimer?.cancel();
  }

  Widget _buildAccountImpactCard({
    required int filed,
    required int resolved,
    required int open,
    required double resolutionRate,
  }) {
    final hasReports = filed > 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E4E7), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Row(
              children: [
                _buildAccountStat('$filed', 'Filed'),
                _buildAccountStatRule(),
                _buildAccountStat('$resolved', 'Resolved'),
                _buildAccountStatRule(),
                _buildAccountStat('$open', 'Open'),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF4F4F5)),
          if (hasReports)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Resolution rate',
                          style: TextStyle(
                            color: Color(0xFF71717A),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '${(resolutionRate * 100).round()}%',
                        style: const TextStyle(
                          color: Color(0xFF059669),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: SizedBox(
                      height: 6,
                      child: Stack(
                        children: [
                          Container(color: const Color(0xFFF1F1F3)),
                          FractionallySizedBox(
                            widthFactor: resolutionRate.clamp(0.0, 1.0),
                            child: Container(color: const Color(0xFF10B981)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Nothing filed yet. Reports you submit are tracked here.',
                  style: const TextStyle(
                    color: Color(0xFFA1A1AA),
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          if (hasReports) ...[
            const Divider(height: 1, thickness: 1, color: Color(0xFFF4F4F5)),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _switchTab(1),
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(18, 14, 16, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'View all in Inbox',
                          style: TextStyle(
                            color: Color(0xFF18181B),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Icon(
                        LucideIcons.chevronRight,
                        size: 15,
                        color: Color(0xFFA1A1AA),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountStat(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF18181B),
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFA1A1AA),
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountStatRule() {
    return Container(width: 1, height: 28, color: const Color(0xFFEFEFF1));
  }

  Widget _buildAccountGroup(List<Widget> children) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE4E4E7), width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        clipBehavior: Clip.antiAlias,
        child: Column(children: children),
      ),
    );
  }

  Widget _buildAccountIconTile(IconData icon) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 16.5, color: const Color(0xFF3F3F46)),
    );
  }

  Widget _buildAccountToggleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
          child: Row(
            children: [
              _buildAccountIconTile(icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF18181B),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFFA1A1AA),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _buildAccountSwitch(value, onChanged),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountNavRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Row(
            children: [
              _buildAccountIconTile(icon),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF18181B),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFFA1A1AA),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: Color(0xFFA1A1AA),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountSwitch(bool value, ValueChanged<bool> onChanged) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: const Color(0xFF18181B),
      inactiveThumbColor: Colors.white,
      inactiveTrackColor: const Color(0xFFE4E4E7),
      trackOutlineColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? const Color(0xFF18181B)
            : const Color(0xFFD4D4D8);
      }),
      trackOutlineWidth: const WidgetStatePropertyAll(1.0),
    );
  }

  Widget _buildAccountSignOut() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _handleSignOut,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFDC2626),
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFE4E4E7), width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(LucideIcons.logOut, size: 15),
        label: const Text(
          'Sign out',
          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  void _showAccountInfoSheet({
    required IconData icon,
    required String title,
    required List<String> lines,
    String? footnote,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildAccountIconTile(icon),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF18181B),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                ...lines.map(
                  (line) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      line,
                      style: const TextStyle(
                        color: Color(0xFF3F3F46),
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
                if (footnote != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      footnote,
                      style: const TextStyle(
                        color: Color(0xFFA1A1AA),
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: FilledButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF18181B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Close',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
  static const int _itemCount = 4;

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
                            _buildDockItem(2, LucideIcons.images, 'Gallery'),
                            _buildDockItem(3, LucideIcons.user, 'Account'),
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

class _ReportWithDistance {
  final ReportModel report;
  final double distanceMeters;
  const _ReportWithDistance(this.report, this.distanceMeters);
}

class _KeepAliveWrapper extends StatefulWidget {
  final Widget child;
  const _KeepAliveWrapper({required this.child});

  @override
  State<_KeepAliveWrapper> createState() => _KeepAliveWrapperState();
}

class _KeepAliveWrapperState extends State<_KeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
