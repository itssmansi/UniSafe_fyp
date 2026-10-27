import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../services/instant_capture_service.dart';
import '../interactive_map/map_screen.dart';

class InstantGalleryScreen extends StatefulWidget {
  final bool isTab;
  final ValueChanged<bool>? onSelectionModeChanged;
  const InstantGalleryScreen({super.key, this.isTab = false, this.onSelectionModeChanged});

  @override
  State<InstantGalleryScreen> createState() => _InstantGalleryScreenState();
}

class _InstantGalleryScreenState extends State<InstantGalleryScreen> {
  List<InstantCaptureDraft> _drafts = [];
  bool _isLoading = true;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    setState(() => _isLoading = true);
    final list = await InstantCaptureService.instance.getDrafts();
    if (mounted) {
      setState(() {
        _drafts = list;
        _isLoading = false;
        _selectedIds.removeWhere((id) => !_drafts.any((d) => d.id == id));
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      });
    }
  }

  void _enterSelectionMode(String initialId) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSelectionMode = true;
      _selectedIds.clear();
      _selectedIds.add(initialId);
    });
    widget.onSelectionModeChanged?.call(true);
  }

  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
    widget.onSelectionModeChanged?.call(false);
  }

  void _toggleSelect(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
    widget.onSelectionModeChanged?.call(_isSelectionMode);
  }

  void _selectAll() {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.length == _drafts.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds.addAll(_drafts.map((d) => d.id));
      }
    });
    widget.onSelectionModeChanged?.call(_isSelectionMode);
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;
    final count = _selectedIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          count == 1 ? 'Delete Photo?' : 'Delete $count Photos?',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          count == 1
              ? 'This photo will be removed from your Safety Gallery.'
              : 'These $count photos will be removed from your Safety Gallery.',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await InstantCaptureService.instance.deleteDrafts(_selectedIds.toList());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(count == 1 ? 'Photo deleted' : '$count photos deleted'),
            backgroundColor: const Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        _exitSelectionMode();
        _loadDrafts();
      }
    }
  }

  void _reportSelected() {
    if (_selectedIds.length != 1) return;
    final selectedId = _selectedIds.first;
    final draft = _drafts.firstWhere((d) => d.id == selectedId);
    _openReportForDraft(draft);
  }

  void _openReportForDraft(InstantCaptureDraft draft) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InteractiveMapScreen(
          initialCenter: LatLng(draft.latitude, draft.longitude),
          initialReportImagePath: draft.imagePath,
          initialReportImageBytes: draft.imageBytes,
          openReportFormImmediately: true,
        ),
      ),
    );
  }

  void _openDetailViewer(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InstantGalleryDetailViewer(
          drafts: _drafts,
          initialIndex: initialIndex,
          onReport: (draft) => _openReportForDraft(draft),
          onDeleted: () => _loadDrafts(),
        ),
      ),
    ).then((_) => _loadDrafts());
  }

  Map<String, List<InstantCaptureDraft>> _groupDraftsByDate() {
    final Map<String, List<InstantCaptureDraft>> groups = {};
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final draft in _drafts) {
      final d = DateTime(draft.capturedAt.year, draft.capturedAt.month, draft.capturedAt.day);
      String key;
      if (d == today) {
        key = 'Today';
      } else if (d == yesterday) {
        key = 'Yesterday';
      } else {
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        key = '${months[d.month - 1]} ${d.day}, ${d.year}';
      }
      groups.putIfAbsent(key, () => []).add(draft);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedIds.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(selectedCount),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _drafts.isEmpty
              ? _buildEmptyState()
              : _buildGroupedPhotoGrid(),
      bottomNavigationBar: _isSelectionMode ? _buildBottomActionBar(selectedCount) : null,
    );
  }

  PreferredSizeWidget _buildAppBar(int selectedCount) {
    if (_isSelectionMode) {
      return AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(LucideIcons.x, color: Color(0xFF0F172A), size: 22),
          onPressed: _exitSelectionMode,
        ),
        title: Text(
          '$selectedCount Selected',
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _selectAll,
            child: Text(
              _selectedIds.length == _drafts.length ? 'Deselect All' : 'Select All',
              style: const TextStyle(
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      );
    }

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: !widget.isTab,
      leading: !widget.isTab
          ? IconButton(
              icon: const Icon(LucideIcons.arrowLeft, color: Color(0xFF0F172A), size: 22),
              onPressed: () => Navigator.of(context).pop(),
            )
          : null,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Safety Gallery',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          Text(
            _isLoading
                ? 'Loading photos...'
                : '${_drafts.length} ${_drafts.length == 1 ? 'photo' : 'photos'} geotagged',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
          ),
        ],
      ),
      actions: [
        if (_drafts.isNotEmpty)
          TextButton(
            onPressed: () {
              if (_drafts.isNotEmpty) {
                _enterSelectionMode(_drafts.first.id);
              }
            },
            child: const Text(
              'Select',
              style: TextStyle(
                color: Color(0xFF2563EB),
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(LucideIcons.images, size: 52, color: Color(0xFF2563EB)),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Safety Photos Yet',
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Photos taken with Instant Click & Go are geotagged with GPS and saved here so you can review or file a report anytime.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupedPhotoGrid() {
    final groups = _groupDraftsByDate();
    final keys = groups.keys.toList();

    return RefreshIndicator(
      onRefresh: _loadDrafts,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
        itemCount: keys.length,
        itemBuilder: (context, sectionIdx) {
          final title = keys[sectionIdx];
          final items = groups[title]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 16, 6, 8),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${items.length}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 5,
                  mainAxisSpacing: 5,
                  childAspectRatio: 1.0,
                ),
                itemCount: items.length,
                itemBuilder: (context, itemIdx) {
                  final draft = items[itemIdx];
                  final globalIdx = _drafts.indexOf(draft);
                  final isSelected = _selectedIds.contains(draft.id);

                  return GestureDetector(
                    onTap: () {
                      if (_isSelectionMode) {
                        _toggleSelect(draft.id);
                      } else {
                        _openDetailViewer(globalIdx);
                      }
                    },
                    onLongPress: () {
                      if (!_isSelectionMode) {
                        _enterSelectionMode(draft.id);
                      } else {
                        _toggleSelect(draft.id);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: _isSelectionMode && isSelected
                            ? Border.all(color: const Color(0xFF2563EB), width: 2.5)
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Image Thumbnail
                            if (draft.imageBytes != null)
                              Image.memory(draft.imageBytes!, fit: BoxFit.cover)
                            else if (draft.imagePath != null &&
                                (draft.imagePath!.startsWith('http') || draft.imagePath!.startsWith('blob:')))
                              Image.network(draft.imagePath!, fit: BoxFit.cover)
                            else
                              Container(
                                color: Colors.grey.shade200,
                                child: const Icon(LucideIcons.image, size: 28, color: Colors.grey),
                              ),

                            // Dimmed overlay when selected
                            if (_isSelectionMode && isSelected)
                              Container(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.22),
                              ),

                            // Selection Checkbox (Visible only in selection mode)
                            if (_isSelectionMode)
                              Positioned(
                                top: 5,
                                right: 5,
                                child: Container(
                                  width: 22,
                                  height: 22,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected
                                        ? const Color(0xFF2563EB)
                                        : Colors.black.withValues(alpha: 0.35),
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                  child: isSelected
                                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                                      : null,
                                ),
                              ),

                            // Mini GPS icon in bottom corner
                            Positioned(
                              bottom: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.all(2.5),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(LucideIcons.mapPin, size: 9, color: Color(0xFF38BDF8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomActionBar(int selectedCount) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset > 0 ? bottomInset + 8 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: selectedCount == 0
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.mousePointerClick, size: 16, color: Colors.grey.shade500),
                  const SizedBox(width: 8),
                  Text(
                    'Select photos to report or delete',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            : selectedCount == 1
                ? Row(
                    children: [
                      OutlinedButton.icon(
                        onPressed: _deleteSelected,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(LucideIcons.trash2, size: 16),
                        label: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _reportSelected,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          icon: const Icon(LucideIcons.arrowRight, size: 18),
                          label: const Text(
                            'Report Issue',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _deleteSelected,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          icon: const Icon(LucideIcons.trash2, size: 18),
                          label: Text(
                            'Delete Selected ($selectedCount)',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

// ==========================================
// FULL-SCREEN DETAIL VIEWER (Phone Gallery Lightbox with Left/Right Swipe, Pinch-Zoom & Details Sheet)
// ==========================================
class InstantGalleryDetailViewer extends StatefulWidget {
  final List<InstantCaptureDraft> drafts;
  final int initialIndex;
  final ValueChanged<InstantCaptureDraft> onReport;
  final VoidCallback onDeleted;

  const InstantGalleryDetailViewer({
    super.key,
    required this.drafts,
    required this.initialIndex,
    required this.onReport,
    required this.onDeleted,
  });

  @override
  State<InstantGalleryDetailViewer> createState() => _InstantGalleryDetailViewerState();
}

class _InstantGalleryDetailViewerState extends State<InstantGalleryDetailViewer> {
  late PageController _pageController;
  late int _currentIndex;
  late List<InstantCaptureDraft> _localDrafts;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _localDrafts = List.from(widget.drafts);
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
  }

  void _showDetailsSheet(InstantCaptureDraft draft) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEFF6FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.info, color: Color(0xFF2563EB), size: 20),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Photo Details',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildDetailRow(
              icon: LucideIcons.calendar,
              label: 'Captured On',
              value: _formatFullDateTime(draft.capturedAt),
            ),
            const Divider(height: 24, thickness: 0.5),
            _buildDetailRow(
              icon: LucideIcons.mapPin,
              label: 'GPS Coordinates',
              value: '${draft.latitude.toStringAsFixed(6)}°, ${draft.longitude.toStringAsFixed(6)}°',
            ),
            const Divider(height: 24, thickness: 0.5),
            _buildDetailRow(
              icon: LucideIcons.shieldCheck,
              label: 'Location Verification',
              value: 'Verified Hardware GPS Lock',
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  widget.onReport(draft);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: const Icon(LucideIcons.arrowRight, size: 18),
                label: const Text('File Report With This Photo', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({required IconData icon, required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
            ],
          ),
        ),
      ],
    );
  }

  String _formatFullDateTime(DateTime dt) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} at $hour:$minute $ampm';
  }

  Future<void> _deleteCurrentPhoto() async {
    if (_localDrafts.isEmpty) return;
    final currentDraft = _localDrafts[_currentIndex];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Photo?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        content: const Text(
          'This photo will be removed from your Safety Gallery.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await InstantCaptureService.instance.deleteDrafts([currentDraft.id]);
      widget.onDeleted();

      setState(() {
        _localDrafts.removeAt(_currentIndex);
        if (_localDrafts.isEmpty) {
          Navigator.of(context).pop();
        } else {
          if (_currentIndex >= _localDrafts.length) {
            _currentIndex = _localDrafts.length - 1;
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_localDrafts.isEmpty) {
      return const Scaffold(backgroundColor: Colors.black);
    }

    final currentDraft = _localDrafts[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Swipeable Full Screen Photo PageView
          GestureDetector(
            onTap: _toggleControls,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _localDrafts.length,
              onPageChanged: (idx) => setState(() => _currentIndex = idx),
              itemBuilder: (context, index) {
                final draft = _localDrafts[index];
                return InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Center(
                    child: draft.imageBytes != null
                        ? Image.memory(draft.imageBytes!, fit: BoxFit.contain)
                        : (draft.imagePath != null &&
                                (draft.imagePath!.startsWith('http') || draft.imagePath!.startsWith('blob:')))
                            ? Image.network(draft.imagePath!, fit: BoxFit.contain)
                            : const Icon(LucideIcons.image, size: 80, color: Colors.white54),
                  ),
                );
              },
            ),
          ),

          // Top App Bar
          if (_showControls)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      // Back Button
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 20),
                        ),
                      ),
                      const Spacer(),
                      // Index indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${_currentIndex + 1} of ${_localDrafts.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Three Dots Menu
                      PopupMenuButton<String>(
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.ellipsisVertical, color: Colors.white, size: 20),
                        ),
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        onSelected: (val) {
                          if (val == 'details') {
                            _showDetailsSheet(currentDraft);
                          } else if (val == 'delete') {
                            _deleteCurrentPhoto();
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'details',
                            child: Row(
                              children: [
                                Icon(LucideIcons.info, size: 16, color: Color(0xFF0F172A)),
                                SizedBox(width: 10),
                                Text('Details & GPS', style: TextStyle(fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(LucideIcons.trash2, size: 16, color: Color(0xFFEF4444)),
                                SizedBox(width: 10),
                                Text('Delete Photo', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFEF4444))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom Bar Actions
          if (_showControls)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Row(
                    children: [
                      // Delete icon button
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(LucideIcons.trash2, color: Colors.white, size: 20),
                          onPressed: _deleteCurrentPhoto,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Report Issue Button
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => widget.onReport(currentDraft),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            elevation: 0,
                          ),
                          icon: const Icon(LucideIcons.arrowRight, size: 18),
                          label: const Text(
                            'Report Issue',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                          ),
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
}
