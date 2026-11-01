import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'kanban_board_screen.dart';

/// Citizen Resolution Verification Screen
///
/// World-class civic audit interface matching Apple & Linear craft standards.
/// Pure client-side UI simulation (Zero backend modifications per AGENTS.md).
class CitizenVerificationScreen extends StatefulWidget {
  final CivicReport report;

  const CitizenVerificationScreen({
    super.key,
    required this.report,
  });

  @override
  State<CitizenVerificationScreen> createState() =>
      _CitizenVerificationScreenState();
}

class _CitizenVerificationScreenState extends State<CitizenVerificationScreen> {
  final ImagePicker _picker = ImagePicker();

  // Active view: 0 = After (Fixed), 1 = Before (Reported)
  int _activeViewIndex = 0;

  // Curated high-res civic inspection photos
  static const String _defaultAfterPhotoUrl =
      'https://images.unsplash.com/photo-1545459720-aac8509eb02c?auto=format&fit=crop&w=1200&q=80';
  static const String _defaultBeforePhotoUrl =
      'https://images.unsplash.com/photo-1515162816999-a0c47dc192f7?auto=format&fit=crop&w=1200&q=80';
  static const String _demoCitizenPhotoUrl =
      'https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?auto=format&fit=crop&w=1200&q=80';

  // Citizen on-site proof state
  Uint8List? _citizenPhotoBytes;
  String? _citizenPhotoUrl;
  bool _isUsingDemoSnapshot = false;

  // Dispute feedback controllers
  final TextEditingController _feedbackController = TextEditingController();
  final FocusNode _feedbackFocusNode = FocusNode();

  final List<String> _quickDisputeTags = [
    'Patch is uneven / sinking',
    'Debris & gravel left behind',
    'Water still ponding after rain',
    'Barricades not cleared',
    'Repaired wrong lane / spot',
  ];

  @override
  void dispose() {
    _feedbackController.dispose();
    _feedbackFocusNode.dispose();
    super.dispose();
  }

  // --- Photo Actions ---

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _citizenPhotoBytes = bytes;
          _citizenPhotoUrl = null;
          _isUsingDemoSnapshot = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera/Gallery selection unavailable: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _useDemoSnapshot() {
    setState(() {
      _isUsingDemoSnapshot = true;
      _citizenPhotoBytes = null;
      _citizenPhotoUrl = _demoCitizenPhotoUrl;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(LucideIcons.sparkles, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Demo on-site verification photo attached.'),
          ],
        ),
        backgroundColor: const Color(0xFF0D9488),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // --- Resolution Actions ---

  void _onConfirmVerification() {
    final hasProof = _citizenPhotoBytes != null ||
        _citizenPhotoUrl != null ||
        _isUsingDemoSnapshot;
    if (!hasProof) {
      _showProofRequiredSheet();
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildSuccessBottomSheet(ctx),
    );
  }

  void _openDisputeSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _buildDisputeBottomSheet(ctx),
    );
  }

  void _showProofRequiredSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.camera, color: Color(0xFFDC2626), size: 28),
            ),
            const SizedBox(height: 14),
            const Text(
              'On-Site Photo Required',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'To ensure civic accountability, please attach a real-time photo of the repair site or use the demo snapshot before final sign-off.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _pickPhoto(ImageSource.camera);
                    },
                    icon: const Icon(LucideIcons.camera, size: 16),
                    label: const Text('Open Camera'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _useDemoSnapshot();
                    },
                    icon: const Icon(LucideIcons.sparkles, size: 16),
                    label: const Text('Demo Photo'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D9488),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openFullScreenPhoto(String imageUrl, {Uint8List? memoryBytes, String title = 'Site Photo'}) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 3.5,
                child: memoryBytes != null
                    ? Image.memory(memoryBytes, fit: BoxFit.contain)
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: CircularProgressIndicator(color: Colors.white70),
                          );
                        },
                      ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(LucideIcons.x, color: Colors.white, size: 26),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Build Method ---

  @override
  Widget build(BuildContext context) {
    final rep = widget.report;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildCustomAppBar(),
      body: Stack(
        children: [
          // Scrollable Content
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Ticket Overview Card
                _buildHeaderCard(rep),

                const SizedBox(height: 16),

                // 2. Clean, Spacious Before & After Visual Inspection
                _buildInspectionSwitcherSection(rep),

                const SizedBox(height: 16),

                // 3. Citizen Ground-Truth Proof Card (Zero-overflow layout)
                _buildCitizenProofSection(),

                const SizedBox(height: 20),
              ],
            ),
          ),

          // Pinned Floating Frosted Bottom Dock
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildFloatingActionDock(),
          ),
        ],
      ),
    );
  }

  // --- Header / App Bar ---

  PreferredSizeWidget _buildCustomAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leadingWidth: 56,
      leading: Padding(
        padding: const EdgeInsets.only(left: 14),
        child: Center(
          child: InkWell(
            onTap: () => Navigator.of(context).pop(),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(LucideIcons.arrowLeft, size: 18, color: Color(0xFF1E293B)),
            ),
          ),
        ),
      ),
      title: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resolution Verification',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: 2),
          Text(
            'Citizen Ground-Truth Sign-Off',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFBFDBFE)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Color(0xFF2563EB),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'In Review',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1D4ED8),
                ),
              ),
            ],
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: const Color(0xFFE2E8F0), height: 1),
      ),
    );
  }

  // --- 1. Ticket Overview Card ---

  Widget _buildHeaderCard(CivicReport rep) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Tag row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: rep.categoryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(rep.categoryIcon, size: 12, color: rep.categoryColor),
                    const SizedBox(width: 5),
                    Text(
                      rep.category,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: rep.categoryColor,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '#${rep.id.substring(0, rep.id.length > 8 ? 8 : rep.id.length).toUpperCase()}',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
              const Spacer(),
              const Icon(LucideIcons.calendar, size: 12, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              Text(
                rep.date,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Title
          Text(
            rep.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF0F172A),
              letterSpacing: -0.4,
              height: 1.25,
            ),
          ),

          const SizedBox(height: 10),

          // Location badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.mapPin, size: 14, color: Color(0xFF0284C7)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rep.location,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Department badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.building, size: 14, color: Color(0xFF6366F1)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Assigned to ${rep.department}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Unit 402',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF059669),
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

  // --- 2. Clean, Spacious Before & After Visual Inspection ---

  Widget _buildInspectionSwitcherSection(CivicReport rep) {
    final String currentImageUrl = _activeViewIndex == 0
        ? ((rep.model.imagePath != null && rep.model.imagePath!.isNotEmpty)
            ? rep.model.imagePath!
            : _defaultAfterPhotoUrl)
        : _defaultBeforePhotoUrl;

    final Uint8List? memoryBytes = _activeViewIndex == 0 ? rep.model.imageBytes : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title & Subtitle
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.image, size: 16, color: Color(0xFF059669)),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Site Inspection Photo',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Tap photo to zoom into road details',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Spacious, Uncluttered Switcher Tabs
          Container(
            height: 40,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // After (Fixed) Tab
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeViewIndex = 0),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _activeViewIndex == 0 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _activeViewIndex == 0
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.badgeCheck,
                            size: 14,
                            color: _activeViewIndex == 0
                                ? const Color(0xFF059669)
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'After (Fixed)',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: _activeViewIndex == 0
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _activeViewIndex == 0
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Before (Reported) Tab
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _activeViewIndex = 1),
                    borderRadius: BorderRadius.circular(10),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _activeViewIndex == 1 ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _activeViewIndex == 1
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            LucideIcons.alertTriangle,
                            size: 14,
                            color: _activeViewIndex == 1
                                ? const Color(0xFFE11D48)
                                : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Before (Reported)',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: _activeViewIndex == 1
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: _activeViewIndex == 1
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFF64748B),
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

          const SizedBox(height: 12),

          // Pure, Clean Image Canvas (Zero Clutter)
          GestureDetector(
            onTap: () => _openFullScreenPhoto(
              currentImageUrl,
              memoryBytes: memoryBytes,
              title: _activeViewIndex == 0 ? 'Repaired Road (Fixed Site)' : 'Reported Hazard (Before)',
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                height: 210,
                width: double.infinity,
                color: const Color(0xFFF1F5F9),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (memoryBytes != null)
                      Image.memory(
                        memoryBytes,
                        fit: BoxFit.cover,
                      )
                    else
                      Image.network(
                        currentImageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF0D9488),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(LucideIcons.imageOff, size: 28, color: Color(0xFF94A3B8)),
                              SizedBox(height: 6),
                              Text(
                                'Photo unavailable',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Tap to zoom hint (subtle corner icon)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(LucideIcons.maximize2, color: Colors.white, size: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. Citizen Ground-Truth Proof Section (Responsive & No-Overflow) ---

  Widget _buildCitizenProofSection() {
    final hasProof = _citizenPhotoBytes != null ||
        _citizenPhotoUrl != null ||
        _isUsingDemoSnapshot;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasProof ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
          width: hasProof ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: hasProof
                ? const Color(0xFF10B981).withValues(alpha: 0.08)
                : const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: hasProof
                      ? const Color(0xFF10B981).withValues(alpha: 0.1)
                      : const Color(0xFF0284C7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  hasProof ? LucideIcons.badgeCheck : LucideIcons.camera,
                  size: 16,
                  color: hasProof ? const Color(0xFF059669) : const Color(0xFF0284C7),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'Your On-Site Verification',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: hasProof
                                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasProof) ...[
                                const Icon(LucideIcons.check, size: 10, color: Color(0xFF059669)),
                                const SizedBox(width: 3),
                              ],
                              Text(
                                hasProof ? 'Attached' : 'Required',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: hasProof ? const Color(0xFF059669) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Attach a photo of the road today to approve resolution',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Ground truth content
          if (hasProof) ...[
            // Attached Photo View (Pure Clean Image with Full Screen & Delete)
            GestureDetector(
              onTap: () => _openFullScreenPhoto(
                _citizenPhotoUrl ?? _demoCitizenPhotoUrl,
                memoryBytes: _citizenPhotoBytes,
                title: 'Your On-Site Verification Photo',
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  children: [
                    Container(
                      height: 180,
                      width: double.infinity,
                      color: const Color(0xFFF1F5F9),
                      child: _citizenPhotoBytes != null
                          ? Image.memory(
                              _citizenPhotoBytes!,
                              fit: BoxFit.cover,
                            )
                          : Image.network(
                              _citizenPhotoUrl ?? _demoCitizenPhotoUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (_, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Color(0xFF0D9488),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),

                    // Full Screen Button (Bottom Right)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: InkWell(
                        onTap: () => _openFullScreenPhoto(
                          _citizenPhotoUrl ?? _demoCitizenPhotoUrl,
                          memoryBytes: _citizenPhotoBytes,
                          title: 'Your On-Site Verification Photo',
                        ),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.maximize2, color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'Full Screen',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Geotag Chip (Bottom Left)
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.mapPin, color: Color(0xFF34D399), size: 11),
                            SizedBox(width: 4),
                            Text(
                              'On-Site Verified (8m)',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Remove / Delete Button (Top Right)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: InkWell(
                        onTap: () => setState(() {
                          _citizenPhotoBytes = null;
                          _citizenPhotoUrl = null;
                          _isUsingDemoSnapshot = false;
                        }),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.x, color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.camera),
                    icon: const Icon(LucideIcons.camera, size: 13),
                    label: const Text('Retake Photo', style: TextStyle(fontSize: 11.5)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickPhoto(ImageSource.gallery),
                    icon: const Icon(LucideIcons.image, size: 13),
                    label: const Text('From Gallery', style: TextStyle(fontSize: 11.5)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Empty State Prompt with Responsive 1-Tap Demo Button
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildUploadChoiceButton(
                        icon: LucideIcons.camera,
                        label: 'Take Photo',
                        color: const Color(0xFF0284C7),
                        onTap: () => _pickPhoto(ImageSource.camera),
                      ),
                      const SizedBox(width: 10),
                      _buildUploadChoiceButton(
                        icon: LucideIcons.image,
                        label: 'Gallery',
                        color: const Color(0xFF475569),
                        onTap: () => _pickPhoto(ImageSource.gallery),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFFE2E8F0), height: 1),
                  const SizedBox(height: 10),

                  // 1-Tap Quick Test Simulator (Overflow Free)
                  InkWell(
                    onTap: _useDemoSnapshot,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(LucideIcons.sparkles, size: 14, color: Color(0xFF059669)),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Attach Demo Verified Photo (1-Tap)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUploadChoiceButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFCBD5E1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- Floating Frosted Bottom Action Dock ---

  Widget _buildFloatingActionDock() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            border: const Border(
              top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // Dispute / Not Fixed Button
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _openDisputeSheet,
                      icon: const Icon(LucideIcons.alertTriangle, size: 16),
                      label: const Text(
                        'Not Fixed',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE11D48),
                        side: const BorderSide(color: Color(0xFFFDA4AF), width: 1.2),
                        backgroundColor: const Color(0xFFFFF1F2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Verify & Close Ticket Button
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D9488), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF059669).withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _onConfirmVerification,
                      icon: const Icon(LucideIcons.badgeCheck, size: 18),
                      label: const Text(
                        'Verify & Close',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
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

  // --- Bottom Sheet: Dispute / Rejection Modal ---

  Widget _buildDisputeBottomSheet(BuildContext ctx) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(ctx).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.alertCircle, color: Color(0xFFE11D48), size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Flag Issue as Incomplete',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      'Your notes will send this ticket back to In Progress',
                      style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          const Text(
            'Quick Reasons:',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
          ),
          const SizedBox(height: 8),

          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _quickDisputeTags.map((tag) {
              return InkWell(
                onTap: () {
                  final cur = _feedbackController.text.trim();
                  if (cur.isEmpty) {
                    _feedbackController.text = tag;
                  } else if (!cur.contains(tag)) {
                    _feedbackController.text = '$cur. $tag';
                  }
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECDD3)),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFBE123C),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          TextField(
            controller: _feedbackController,
            focusNode: _feedbackFocusNode,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Describe what needs further work so the authority can fix it properly...',
              hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.all(12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE11D48), width: 1.5),
              ),
            ),
            style: const TextStyle(fontSize: 13),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton.icon(
              onPressed: () {
                final notes = _feedbackController.text.trim();
                Navigator.pop(ctx);
                Navigator.of(context).pop(false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      notes.isNotEmpty
                          ? 'Ticket returned to In Progress with your feedback.'
                          : 'Ticket flagged for municipal recheck.',
                    ),
                    backgroundColor: const Color(0xFFE11D48),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              icon: const Icon(LucideIcons.send, size: 16),
              label: const Text(
                'Submit Feedback & Send Back',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Bottom Sheet: Celebration / Verification Success ---

  Widget _buildSuccessBottomSheet(BuildContext ctx) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFD1FAE5),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(LucideIcons.checkCheck, color: Color(0xFF059669), size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'Resolution Verified!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 8),
          Text(
            'Your ground-truth sign-off for "${widget.report.title}" has been recorded. This civic ticket is now officially marked as Done.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B), height: 1.45),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                'Done & Back to Kanban',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
