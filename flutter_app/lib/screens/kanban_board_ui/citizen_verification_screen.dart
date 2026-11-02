import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../instant_capture/instant_camera_screen.dart';
import '../instant_capture/instant_gallery_screen.dart';
import '../../services/instant_capture_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../interactive_map/report_model.dart';

/// Citizen Resolution Verification Screen
///
/// World-class civic audit interface matching Apple & Linear craft standards.
/// Verified ground-truth resolution handshake with Supabase.
class CitizenVerificationScreen extends StatefulWidget {
  final ReportModel report;

  const CitizenVerificationScreen({
    super.key,
    required this.report,
  });

  @override
  State<CitizenVerificationScreen> createState() =>
      _CitizenVerificationScreenState();
}

class _CitizenVerificationScreenState extends State<CitizenVerificationScreen> {
  bool _isSubmitting = false;

  IconData _getCategoryIcon(IssueCategory category) {
    switch (category) {
      case IssueCategory.infrastructure:
        return LucideIcons.hammer;
      case IssueCategory.sanitation:
        return LucideIcons.trash2;
      case IssueCategory.safety:
        return LucideIcons.shieldAlert;
      case IssueCategory.greenery:
        return LucideIcons.trees;
    }
  }

  Color _getCategoryColor(IssueCategory category) {
    switch (category) {
      case IssueCategory.infrastructure:
        return const Color(0xFF2563EB);
      case IssueCategory.sanitation:
        return const Color(0xFFD97706);
      case IssueCategory.safety:
        return const Color(0xFFDC2626);
      case IssueCategory.greenery:
        return const Color(0xFF059669);
    }
  }

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
  double? _photoLatitude;
  double? _photoLongitude;
  double? _verificationDistanceMeters;

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

  Future<void> _pickPhotoFromInAppCamera() async {
    try {
      final draft = await Navigator.push<InstantCaptureDraft>(
        context,
        MaterialPageRoute(builder: (_) => const InstantCameraScreen(isPicker: true)),
      );
      if (draft != null && mounted) {
        final dist = Geolocator.distanceBetween(
          widget.report.location.latitude,
          widget.report.location.longitude,
          draft.latitude,
          draft.longitude,
        );
        setState(() {
          _citizenPhotoBytes = draft.imageBytes;
          _citizenPhotoUrl = null;
          _photoLatitude = draft.latitude;
          _photoLongitude = draft.longitude;
          _verificationDistanceMeters = dist;
        });

        if (dist > 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Warning: Photo taken ${dist.toStringAsFixed(0)}m from report location. Must be within 200m to verify.'),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('In-app camera unavailable: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickPhotoFromInAppGallery() async {
    try {
      final draft = await Navigator.push<InstantCaptureDraft>(
        context,
        MaterialPageRoute(builder: (_) => const InstantGalleryScreen(isPicker: true)),
      );
      if (draft != null && mounted) {
        final dist = Geolocator.distanceBetween(
          widget.report.location.latitude,
          widget.report.location.longitude,
          draft.latitude,
          draft.longitude,
        );
        setState(() {
          _citizenPhotoBytes = draft.imageBytes;
          _citizenPhotoUrl = null;
          _photoLatitude = draft.latitude;
          _photoLongitude = draft.longitude;
          _verificationDistanceMeters = dist;
        });

        if (dist > 200) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Warning: Selected photo is ${dist.toStringAsFixed(0)}m from report location. Must be within 200m to verify.'),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('In-app gallery unavailable: $e'),
            backgroundColor: const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- Resolution Actions ---

  Future<String?> _resolveCitizenId() async {
    final authUser = SupabaseConfig.client.auth.currentUser;
    if (authUser != null) {
      try {
        var query = SupabaseConfig.client.from('citizens').select('id');
        if (authUser.email != null && authUser.email!.isNotEmpty) {
          query = query.or('auth_user_id.eq.${authUser.id},email.eq.${authUser.email}');
        } else if (authUser.phone != null && authUser.phone!.isNotEmpty) {
          query = query.or('auth_user_id.eq.${authUser.id},phone.eq.${authUser.phone}');
        } else {
          query = query.eq('auth_user_id', authUser.id);
        }
        final citizenRecord = await query.maybeSingle();
        if (citizenRecord != null && citizenRecord['id'] != null) {
          return citizenRecord['id'].toString();
        }
      } catch (e) {
        debugPrint('[CitizenVerificationScreen] Error resolving citizen profile by auth: $e');
      }
    }

    // Fallback: check if widget.report.citizenId exists in public.citizens
    if (widget.report.citizenId != null && widget.report.citizenId!.trim().isNotEmpty) {
      try {
        final existing = await SupabaseConfig.client
            .from('citizens')
            .select('id')
            .eq('id', widget.report.citizenId!.trim())
            .maybeSingle();
        if (existing != null && existing['id'] != null) {
          return existing['id'].toString();
        }
      } catch (_) {}
    }

    return null;
  }

  Future<String?> _uploadCitizenProof(String complaintId) async {
    if (_citizenPhotoBytes == null) {
      if (_citizenPhotoUrl != null) return _citizenPhotoUrl;
      return null;
    }
    try {
      final fileName = 'citizen_verifications/${complaintId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await SupabaseConfig.client.storage
          .from('complaint_images')
          .uploadBinary(
            fileName,
            _citizenPhotoBytes!,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
      final publicUrl = SupabaseConfig.client.storage
          .from('complaint_images')
          .getPublicUrl(fileName);
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading citizen proof: $e');
      return null;
    }
  }

  Future<void> _onConfirmVerification() async {
    final hasProof = _citizenPhotoBytes != null || _citizenPhotoUrl != null;
    if (!hasProof) {
      _showProofRequiredSheet();
      return;
    }

    if (_verificationDistanceMeters != null && _verificationDistanceMeters! > 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot verify: You are ${_verificationDistanceMeters!.toStringAsFixed(0)}m away. On-site verification must be within 200m of the issue location.'),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final citizenId = await _resolveCitizenId();
      final uploadedUrl = await _uploadCitizenProof(widget.report.id);

      // 1. Upsert into complaint_verifications (Triggers auto-update of complaint status)
      final verificationPayload = <String, dynamic>{
        'complaint_id': widget.report.id,
        'image_url': uploadedUrl,
        'is_verified': true,
      };
      if (citizenId != null) {
        verificationPayload['citizen_id'] = citizenId;
        await SupabaseConfig.client
            .from('complaint_verifications')
            .upsert(verificationPayload, onConflict: 'complaint_id,citizen_id');
      } else {
        await SupabaseConfig.client
            .from('complaint_verifications')
            .insert(verificationPayload);
      }

      // 2. Update complaints status to resolved (backed by DB trigger)
      try {
        await SupabaseConfig.client.from('complaints').update({
          'status': 'resolved',
        }).eq('id', widget.report.id);
      } catch (_) {}

      // 3. Log to complaint_logs
      try {
        await SupabaseConfig.client.from('complaint_logs').insert({
          'complaint_id': widget.report.id,
          'action': 'citizen_verified',
          'message': 'Citizen verified the resolution and marked complaint as Done.',
        });
      } catch (_) {}

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _buildSuccessBottomSheet(ctx),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to record verification: $e'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
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
              'To ensure civic accountability, please capture or choose a GPS-verified photo within 200m of the site using the In-App Camera or Safety Gallery.',
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
                      _pickPhotoFromInAppCamera();
                    },
                    icon: const Icon(LucideIcons.camera, size: 16),
                    label: const Text('In-App Camera'),
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
                      _pickPhotoFromInAppGallery();
                    },
                    icon: const Icon(LucideIcons.images, size: 16),
                    label: const Text('Safety Gallery'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
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

  Widget _buildHeaderCard(ReportModel rep) {

    final catColor = _getCategoryColor(rep.category);

    final catIcon = _getCategoryIcon(rep.category);

    final dateStr = rep.createdAt != null

        ? '${rep.createdAt!.day}/${rep.createdAt!.month}/${rep.createdAt!.year}'

        : 'Recent';

    final locStr = (rep.address != null && rep.address!.trim().isNotEmpty)

        ? rep.address!

        : '${rep.location.latitude.toStringAsFixed(3)}, ${rep.location.longitude.toStringAsFixed(3)}';

    final deptStr = (rep.assignedOfficerDepartment != null && rep.assignedOfficerDepartment!.trim().isNotEmpty)

        ? rep.assignedOfficerDepartment!

        : 'Municipal Authority';
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
                  color: catColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(catIcon, size: 12, color: catColor),
                    const SizedBox(width: 5),
                    Text(
                      rep.category.name.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: catColor,
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
                dateStr,
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
                    locStr,
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
                    'Assigned to $deptStr',
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

  Widget _buildInspectionSwitcherSection(ReportModel rep) {
    final String? authorityImg = rep.authorityImageUrl;
    final String? citizenImg = rep.imagePath;

    final String currentImageUrl = _activeViewIndex == 0
        ? (authorityImg != null && authorityImg.isNotEmpty
            ? authorityImg
            : _defaultAfterPhotoUrl)
        : (citizenImg != null && citizenImg.isNotEmpty
            ? citizenImg
            : _defaultBeforePhotoUrl);

    final Uint8List? memoryBytes = _activeViewIndex == 1 ? rep.imageBytes : null;

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
                        errorBuilder: (_, _, _) => Center(
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
    final hasProof = _citizenPhotoBytes != null || _citizenPhotoUrl != null;

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
                _citizenPhotoUrl ?? '',
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
                          : (_citizenPhotoUrl != null
                              ? Image.network(
                                  _citizenPhotoUrl!,
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
                                )
                              : const SizedBox.shrink()),
                    ),

                    // Full Screen Button (Bottom Right)
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: InkWell(
                        onTap: () => _openFullScreenPhoto(
                          _citizenPhotoUrl ?? '',
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: (_verificationDistanceMeters != null && _verificationDistanceMeters! > 200)
                              ? const Color(0xFFDC2626).withValues(alpha: 0.85)
                              : Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: (_verificationDistanceMeters != null && _verificationDistanceMeters! > 200)
                                ? const Color(0xFFFCA5A5)
                                : Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              (_verificationDistanceMeters != null && _verificationDistanceMeters! > 200)
                                  ? LucideIcons.alertTriangle
                                  : LucideIcons.mapPin,
                              color: (_verificationDistanceMeters != null && _verificationDistanceMeters! > 200)
                                  ? Colors.white
                                  : const Color(0xFF34D399),
                              size: 11,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _verificationDistanceMeters != null
                                  ? (_verificationDistanceMeters! <= 200
                                      ? 'On-Site Verified (${_verificationDistanceMeters!.toStringAsFixed(0)}m)'
                                      : 'Too Far (${_verificationDistanceMeters!.toStringAsFixed(0)}m > 200m)')
                                  : 'GPS Geotagged',
                              style: const TextStyle(
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
                          _photoLatitude = null;
                          _photoLongitude = null;
                          _verificationDistanceMeters = null;
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
                    onPressed: _pickPhotoFromInAppCamera,
                    icon: const Icon(LucideIcons.camera, size: 13),
                    label: const Text('In-App Camera', style: TextStyle(fontSize: 11.5)),
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
                    onPressed: _pickPhotoFromInAppGallery,
                    icon: const Icon(LucideIcons.images, size: 13),
                    label: const Text('Safety Gallery', style: TextStyle(fontSize: 11.5)),
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
            // Empty State Prompt with In-App Options Only
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
                        label: 'In-App Camera',
                        color: const Color(0xFF0284C7),
                        onTap: _pickPhotoFromInAppCamera,
                      ),
                      const SizedBox(width: 10),
                      _buildUploadChoiceButton(
                        icon: LucideIcons.images,
                        label: 'Safety Gallery',
                        color: const Color(0xFF475569),
                        onTap: _pickPhotoFromInAppGallery,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Verification requires a GPS-geotagged photo taken within 200m of the complaint location.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600, height: 1.3),
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
                      onPressed: _isSubmitting ? null : _onConfirmVerification,
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
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      final notes = _feedbackController.text.trim();
                      if (notes.length < 10) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please describe what remains incomplete (at least 10 characters).'),
                            backgroundColor: Color(0xFFDC2626),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }

                      Navigator.pop(ctx);
                      setState(() => _isSubmitting = true);

                      try {
                        final citizenId = await _resolveCitizenId();
                        final uploadedUrl = await _uploadCitizenProof(widget.report.id);

                        // 1. Upsert into complaint_verifications (Triggers auto-update of complaint status)
                        final disputePayload = <String, dynamic>{
                          'complaint_id': widget.report.id,
                          'image_url': uploadedUrl,
                          'is_verified': false,
                          'feedback': notes,
                        };
                        if (citizenId != null) {
                          disputePayload['citizen_id'] = citizenId;
                          await SupabaseConfig.client
                              .from('complaint_verifications')
                              .upsert(disputePayload, onConflict: 'complaint_id,citizen_id');
                        } else {
                          await SupabaseConfig.client
                              .from('complaint_verifications')
                              .insert(disputePayload);
                        }

                        // 2. Revert complaints to in-progress with citizen_feedback (backed by DB trigger)
                        try {
                          await SupabaseConfig.client.from('complaints').update({
                            'status': 'in-progress',
                            'citizen_feedback': notes,
                          }).eq('id', widget.report.id);
                        } catch (_) {}

                        // 3. Log to complaint_logs
                        try {
                          await SupabaseConfig.client.from('complaint_logs').insert({
                            'complaint_id': widget.report.id,
                            'action': 'citizen_rejected',
                            'message': 'Citizen rejected resolution: $notes',
                          });
                        } catch (_) {}

                        if (!mounted) return;
                        setState(() => _isSubmitting = false);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Ticket returned to In Progress with your feedback for re-inspection.'),
                            backgroundColor: Color(0xFFE11D48),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        Navigator.of(context).pop(false);
                      } catch (e) {
                        if (!mounted) return;
                        setState(() => _isSubmitting = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to submit dispute: $e'),
                            backgroundColor: const Color(0xFFDC2626),
                          ),
                        );
                      }
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
                'Done & Back to Inbox',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
