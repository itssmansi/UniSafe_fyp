import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'report_model.dart';
import 'report_provider.dart';
/// Centralized visual identity for each issue category.
class CategoryStyle {
  final IconData icon;
  final Color color;
  final Color glowColor;
  final String label;
  const CategoryStyle(this.icon, this.color, this.glowColor, this.label);
}
const Map<IssueCategory, CategoryStyle> kCategoryStyles = {
  IssueCategory.infrastructure:
      CategoryStyle(LucideIcons.building, Color(0xFFFF6B6B), Color(0x66FF6B6B), 'Infrastructure'),
  IssueCategory.sanitation:
      CategoryStyle(LucideIcons.trash2, Color(0xFFF9A826), Color(0x66F9A826), 'Sanitation'),
  IssueCategory.safety:
      CategoryStyle(LucideIcons.shield, Color(0xFF4D96FF), Color(0x664D96FF), 'Safety'),
  IssueCategory.greenery:
      CategoryStyle(LucideIcons.leaf, Color(0xFF4CAF50), Color(0x664CAF50), 'Greenery'),
};
const Map<IssueCategory, List<String>> kSubcategories = {
  IssueCategory.infrastructure: ['Nonfunctional street lights', 'Potholes', 'Water logging', 'Prolonged road work', 'Drainage', 'Other'],
  IssueCategory.sanitation: ['Garbage scattered on the road', 'Public washrooms not clean', 'Garbage beach/river', 'Untimely garbage collection/overflowing', 'Other'],
  IssueCategory.safety: ['Open manholes', 'Non existent footpath', 'Women safety', 'Illegal parking', 'Theft / Robbery', 'Harassment / Eve-Teasing', 'Assault / Violence', 'Poor Street Lighting', 'Fire Hazard', 'Electrical Hazard', 'Exposed Wires', 'Child Safety Concern', 'Stray Animal Threat', 'Other'],
  IssueCategory.greenery: ['Waste Dumping in Green Area', 'Poor Landscape Maintenance', 'Watering Required for Plants', 'Encroachment on Green Spaces', 'Pest or Insect Infestation', 'Overgrown Vegetation', 'Need Tree Plantation', 'Illegal Tree Cutting', 'Public problems on greenery', 'Other'],
};
/// A highly customized, premium map pin.
class MapPinShape extends StatefulWidget {
  static const double headSize = 44;
  static const double boxWidth = 64;
  static const double boxHeight = 128; // Double height so the tip is in the exact center
  final IconData icon;
  final Color color;
  final Color glowColor;
  final bool isEditing;
  final bool isPending;
  const MapPinShape({
    super.key,
    required this.icon,
    required this.color,
    required this.glowColor,
    this.isEditing = false,
    this.isPending = false,
  });
  @override
  State<MapPinShape> createState() => _MapPinShapeState();
}
class _MapPinShapeState extends State<MapPinShape> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool get _isAnimated => widget.isPending || widget.isEditing;
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (_isAnimated) _pulseController.repeat(reverse: true);
  }
  @override
  void didUpdateWidget(covariant MapPinShape oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isAnimated && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!_isAnimated && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final ringColor = widget.isEditing ? const Color(0xFFF59E0B) : Colors.white;
    
    // Scale the pin down if zoomed out, so it doesn't cover massive areas
    final camera = MapCamera.maybeOf(context);
    final zoom = camera?.zoom ?? 15.0;
    final zoomScale = ((zoom - 8) / (15 - 8)).clamp(0.4, 1.0);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseScale = widget.isPending || widget.isEditing 
            ? 1.0 + (_pulseController.value * 0.1) 
            : 1.0;
        final finalScale = pulseScale * zoomScale;
        return Align(
          alignment: Alignment.center,
          child: Transform.scale(
            scale: finalScale,
            alignment: Alignment.bottomCenter, // Scales relative to the tip of the teardrop
            child: Transform.rotate(
              angle: 45 * 3.14159265359 / 180,
              child: Container(
                width: MapPinShape.headSize,
                height: MapPinShape.headSize,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(4),
                  ),
                  border: Border.all(color: ringColor, width: widget.isEditing ? 3 : 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: widget.glowColor,
                      blurRadius: (widget.isPending || widget.isEditing) ? 12 : 8,
                      spreadRadius: (widget.isPending || widget.isEditing) ? 4 : 1,
                      offset: const Offset(3, 3),
                    ),
                  ],
                ),
                child: Center(
                  child: Transform.rotate(
                    angle: -45 * 3.14159265359 / 180,
                    child: Icon(widget.icon, color: Colors.white, size: MapPinShape.headSize * 0.5),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});
  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}
class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final GlobalKey _mapKey = GlobalKey();
  final FocusNode _searchFocusNode = FocusNode();
  LatLng? _droppedLocation;
  IssueCategory? _selectedCategory;
  String? _editingReportId;
  LatLng? _draggedReportLocation; // Local state for throttling drag writes
  Set<IssueCategory> _hiddenCategories = {}; // For category filtering
  bool _isSearching = false;
  bool _isFetchingLocation = false;
  Timer? _debounce;
  List<dynamic> _suggestions = [];
  LatLng? _myLocation;
  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _goToMyLocation();
    });
  }
  @override
  void dispose() {
    _searchFocusNode.dispose();
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }
  int _searchRequestId = 0;
  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        if (mounted) setState(() => _suggestions = []);
        return;
      }
      final requestId = ++_searchRequestId;
      try {
        final response = await http.get(
          Uri.parse(
              'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5'),
          headers: {'User-Agent': 'com.unisafe.app (Unisafe community reporting app)'},
        );
        // A slower, older request can resolve after a newer one — ignore it
        // so stale results don't flash over what the user is now seeing.
        if (requestId != _searchRequestId) return;
        if (response.statusCode == 200) {
          if (mounted) {
            setState(() {
              _suggestions = json.decode(response.body) as List;
            });
          }
        }
      } catch (e) {
        debugPrint('Search error: $e');
      }
    });
  }
  void _selectSuggestion(dynamic suggestion) {
    FocusScope.of(context).unfocus();
    final lat = double.parse(suggestion['lat'].toString());
    final lon = double.parse(suggestion['lon'].toString());
    _searchController.text = suggestion['display_name'];
    setState(() {
      _suggestions = [];
    });
    _mapController.move(LatLng(lat, lon), 16.0);
  }
  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isSearching = true;
      _suggestions = [];
    });
    try {
      final response = await http.get(
        Uri.parse(
            'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1'),
        headers: {'User-Agent': 'com.unisafe.app (Unisafe community reporting app)'},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat'].toString());
          final lon = double.parse(data[0]['lon'].toString());
          _mapController.move(LatLng(lat, lon), 16.0);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location not found')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Search error: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }
  Future<void> _goToMyLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services are disabled.')));
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are denied')));
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions are permanently denied, we cannot request permissions.')));
      return;
    }
    // Start loading spinner ONLY after permissions are resolved,
    // to preserve the browser's user-gesture token for the native API.
    setState(() {
      _isFetchingLocation = true;
    });
    try {
      Position position = await Geolocator.getCurrentPosition();
      final latLng = LatLng(position.latitude, position.longitude);
      setState(() {
        _myLocation = latLng;
      });
      _mapController.move(latLng, 17.0);
    } catch (e) {
      debugPrint("Error fetching location: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to fetch location')));
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
      }
    }
  }
    void _onCategoryTapped(IssueCategory category) {
    setState(() {
      _selectedCategory = category;
      _droppedLocation = _mapController.camera.center;
      _editingReportId = null;
    });
  }
  void _onPinDropped(DragTargetDetails<IssueCategory> details) {
    final currentContext = _mapKey.currentContext;
    if (currentContext == null) return;
    final renderBox = currentContext.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    
    // Offset by approx half the feedback widget size (which is ~56x56) to get the center
    final globalCenter = details.offset + const Offset(28, 28);
    final localOffset = renderBox.globalToLocal(globalCenter);
    final latLng = _mapController.camera.screenOffsetToLatLng(localOffset);
    setState(() {
      _selectedCategory = details.data;
      _droppedLocation = latLng;
      _editingReportId = null;
    });
  }
  void _dragPin(LatLng currentLocation, Offset delta, void Function(LatLng) onUpdate) {
    try {
      final currentScreenOffset = _mapController.camera.latLngToScreenOffset(currentLocation);
      final newScreenOffset = Offset(
        currentScreenOffset.dx + delta.dx,
        currentScreenOffset.dy + delta.dy,
      );
      final newLatLng = _mapController.camera.screenOffsetToLatLng(newScreenOffset);
      onUpdate(newLatLng);
    } catch (e) {
      debugPrint("Error dragging pin: $e");
    }
  }
  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(reportProvider);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: DragTarget<IssueCategory>(
            onAcceptWithDetails: _onPinDropped,
            builder: (context, candidateData, rejectedData) {
              return Container(
                key: _mapKey,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
              initialCenter: const LatLng(28.6139, 77.2090),
              initialZoom: 14.0,
              onTap: (_, __) => FocusScope.of(context).unfocus(),
              interactionOptions: InteractionOptions(
                flags: (_editingReportId != null || _droppedLocation != null)
                    ? InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom
                    : InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.unisafe.app',
              ),
              MarkerClusterLayerWidget(
                options: MarkerClusterLayerOptions(
                  maxClusterRadius: 45,
                  size: const Size(40, 40),
                  alignment: Alignment.center,
                  maxZoom: 15,
                  markers: [
                    ...reports.where((r) => r.id != _editingReportId && !_hiddenCategories.contains(r.category)).map((r) {
                      final style = kCategoryStyles[r.category]!;
                      return Marker(
                        point: r.location,
                        width: MapPinShape.boxWidth,
                        height: MapPinShape.boxHeight,
                        alignment: Alignment.center,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _showReportOptions(r),
                          child: MapPinShape(
                            icon: style.icon, 
                            color: style.color, 
                            glowColor: style.glowColor,
                            isEditing: false,
                          ),
                        ),
                      );
                    }),
                  ],
                  builder: (context, markers) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                      ),
                      child: Center(
                        child: Text(
                          markers.length.toString(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  },
                ),
              ),
              MarkerLayer(
                markers: [
                  if (_myLocation != null)
                    Marker(
                      point: _myLocation!,
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade600,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3.5),
                            boxShadow: [
                              BoxShadow(color: Colors.blue.shade300.withOpacity(0.5), blurRadius: 12, spreadRadius: 4),
                            ],
                          ),
                        ),
                      ),
                    ),
                  // The currently edited report
                  if (_editingReportId != null)
                    ...reports.where((r) => r.id == _editingReportId).map((r) {
                      final style = kCategoryStyles[r.category]!;
                      return Marker(
                        point: _draggedReportLocation ?? r.location,
                        width: MapPinShape.boxWidth,
                        height: MapPinShape.boxHeight,
                        alignment: Alignment.center,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanUpdate: (details) {
                            _dragPin(
                              _draggedReportLocation ?? r.location, 
                              details.delta, 
                              (newLatLng) => setState(() => _draggedReportLocation = newLatLng)
                            );
                          },
                          onPanEnd: (_) {
                            if (_draggedReportLocation != null) {
                              ref.read(reportProvider.notifier).updateReport(r.copyWith(location: _draggedReportLocation));
                            }
                          },
                          child: MapPinShape(
                            icon: style.icon, 
                            color: style.color, 
                            glowColor: style.glowColor,
                            isEditing: true,
                          ),
                        ),
                      );
                    }),
                  // Currently dropping pin
                  if (_droppedLocation != null && _selectedCategory != null)
                    Marker(
                      point: _droppedLocation!,
                      width: MapPinShape.boxWidth,
                      height: MapPinShape.boxHeight,
                      alignment: Alignment.center,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanUpdate: (details) {
                          _dragPin(
                            _droppedLocation!, 
                            details.delta, 
                            (newLatLng) => setState(() => _droppedLocation = newLatLng)
                          );
                        },
                        child: MapPinShape(
                          icon: kCategoryStyles[_selectedCategory!]!.icon,
                          color: kCategoryStyles[_selectedCategory!]!.color,
                          glowColor: kCategoryStyles[_selectedCategory!]!.glowColor,
                          isPending: true,
                        ),
                      ),
                    ),
                    ], // closes MarkerLayer.markers
                  ),   // closes MarkerLayer
                ],     // closes FlutterMap.children
              ),       // closes FlutterMap
            );         // closes Container
          },           // closes builder
        ),             // closes DragTarget
      ),               // closes Positioned.fill
      
          // Top Search Bar
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search Bar
                    Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                          width: _searchFocusNode.hasFocus ? 0 : 64, // 52 width + 12 padding
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const NeverScrollableScrollPhysics(),
                            reverse: true, // Aligns to the right, creating a slide-out effect
                            child: SizedBox(
                              width: 64,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(28),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                    child: Container(
                                      width: 52,
                                      height: 52,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.75),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.0),
                                        boxShadow: [
                                          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 10)),
                                        ],
                                      ),
                                      child: IconButton(
                                        icon: Icon(LucideIcons.arrowLeft, color: Colors.grey.shade800),
                                        onPressed: () => Navigator.of(context).pop(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.65),
                                  borderRadius: BorderRadius.circular(50),
                                  border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 24, offset: const Offset(0, 8)),
                                  ],
                                ),
                                child: TextField(
                                  focusNode: _searchFocusNode,
                                  controller: _searchController,
                                  onChanged: _onSearchChanged,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A202C)),
                                  decoration: InputDecoration(
                                    hintText: 'Search anywhere...',
                                    hintStyle: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                    prefixIcon: Padding(
                                      padding: const EdgeInsets.only(left: 4.0),
                                      child: Icon(LucideIcons.search, color: Colors.grey.shade700, size: 22),
                                    ),
                                    suffixIcon: _isSearching
                                        ? const Padding(
                                            padding: EdgeInsets.all(14.0),
                                            child: SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(strokeWidth: 2.5),
                                            ),
                                          )
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (_searchController.text.isNotEmpty)
                                                IconButton(
                                                  icon: Icon(LucideIcons.x, size: 20, color: Colors.grey.shade600),
                                                  onPressed: () {
                                                    _searchController.clear();
                                                    setState(() => _suggestions = []);
                                                  },
                                                ),
                                            ],
                                          ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                  ),
                                  onSubmitted: _searchLocation,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    
                    // Suggestions List
                    if (_suggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 12),
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, 10)),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                            child: Container(
                              constraints: const BoxConstraints(maxHeight: 280),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.65),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                itemCount: _suggestions.length,
                                separatorBuilder: (context, index) => Divider(
                                  height: 1, 
                                  indent: 64, 
                                  endIndent: 16, 
                                  color: Colors.grey.withOpacity(0.25)
                                ),
                                itemBuilder: (context, index) {
                                  final suggestion = _suggestions[index];
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                    leading: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.0),
                                      ),
                                      child: Icon(LucideIcons.mapPin, color: Colors.blue.shade700, size: 20),
                                    ),
                                    title: Text(
                                      suggestion['display_name'],
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF2D3748), height: 1.3),
                                    ),
                                    onTap: () => _selectSuggestion(suggestion),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    
                    // Pin Categories Bar (When idle)
                    if (_droppedLocation == null && _editingReportId == null) ...[
                      const SizedBox(height: 12),
                      if (reports.isEmpty && _suggestions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.55),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Tap or drag a category below to report an issue',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(36),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(36),
                              border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.0),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 10)),
                              ],
                            ),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (var category in IssueCategory.values)
                                    _buildCategoryButton(category),
                                ],
                              ),
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
                    // Bottom Action Areas
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // My Location FAB
                  if (_droppedLocation == null && _editingReportId == null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 20.0, bottom: 20.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: _showFilterDialog,
                              child: Container(
                                width: 56,
                                height: 56,
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 8)),
                                  ],
                                ),
                                child: Center(
                                  child: Icon(LucideIcons.filter, color: _hiddenCategories.isNotEmpty ? Colors.blue.shade600 : Colors.grey.shade700, size: 26),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: _isFetchingLocation ? null : _goToMyLocation,
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 15, offset: const Offset(0, 8)),
                                  ],
                                ),
                                child: Center(
                                  child: _isFetchingLocation
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF2563EB)),
                                        )
                                      : const Icon(LucideIcons.locate, color: Color(0xFF2563EB), size: 26),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Confirm Pending Pin Area
                  if (_droppedLocation != null)
                    _buildPendingActionPanel(),
                  // Editing Pin Area
                  if (_editingReportId != null)
                    _buildEditingActionPanel(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildCategoryButton(IssueCategory category) {
    final style = kCategoryStyles[category]!;
    Widget buttonContent = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: style.color,
            shape: BoxShape.circle,
          ),
          child: Icon(style.icon, color: Colors.white, size: 22),
        ),
        const SizedBox(height: 4),
        Text(
          style.label,
          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
        ),
      ],
    );
    return Draggable<IssueCategory>(
      data: category,
      feedback: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: style.color,
            shape: BoxShape.circle,
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Icon(style.icon, color: Colors.white, size: 28),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: buttonContent,
        ),
      ),
      child: GestureDetector(
        onTap: () => _onCategoryTapped(category),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: buttonContent,
        ),
      ),
    );
  }
  Widget _buildPendingActionPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 40, offset: const Offset(0, 15)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Drag the pin to fine-tune location',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  icon: Icon(LucideIcons.x, color: Colors.red.shade600),
                  onPressed: () {
                    setState(() {
                      _droppedLocation = null;
                      _selectedCategory = null;
                    });
                  },

                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    _showReportForm(context, _droppedLocation!);
                  },
                  icon: const Icon(LucideIcons.check, size: 20),
                  label: const Text('Confirm Location', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shadowColor: const Color(0xFF10B981).withOpacity(0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildEditingActionPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 40, offset: const Offset(0, 15)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Drag the pin to reposition',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _editingReportId = null);
                  },
                  icon: const Icon(LucideIcons.check, size: 20),
                  label: const Text('Save Position', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    elevation: 8,
                    shadowColor: const Color(0xFFF59E0B).withOpacity(0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
    void _showReportForm(BuildContext context, LatLng location) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 24,
            right: 24,
            top: 16,
          ),
          child: ReportFormWidget(
            location: location,
            category: _selectedCategory!,
            onSubmit: (report) {
              ref.read(reportProvider.notifier).addReport(report);
              setState(() {
                _droppedLocation = null;
                _selectedCategory = null;
              });
              Navigator.pop(context);
            },
            onCancel: () {
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }
  void _showReportOptions(ReportModel report) {
    final style = kCategoryStyles[report.category]!;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: style.color.withOpacity(0.15), shape: BoxShape.circle),
                    child: Icon(style.icon, color: style.color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                        Text(style.label, style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
              if (report.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    report.description,
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade800, height: 1.4),
                  ),
                ),
              ],
              
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _mapController.move(report.location, _mapController.camera.zoom);
                        setState(() => _editingReportId = report.id);
                      },
                      icon: const Icon(LucideIcons.move, size: 20),
                      label: const Text('Reposition', style: TextStyle(fontSize: 15)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                        foregroundColor: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _confirmDelete(report);
                      },
                      icon: const Icon(LucideIcons.trash2, size: 20),
                      label: const Text('Delete', style: TextStyle(fontSize: 15)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.red.shade50,
                        foregroundColor: Colors.red.shade700,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }
  void _confirmDelete(ReportModel report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Delete this pin?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('"${report.title}" will be permanently removed from the map.', style: TextStyle(color: Colors.grey.shade700, fontSize: 15)),
        actionsPadding: const EdgeInsets.all(16),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600, fontSize: 15)),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(reportProvider.notifier).deleteReport(report.id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
    void _showFilterDialog() {

    Set<IssueCategory> tempHidden = Set.from(_hiddenCategories);
    showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              
              titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Filter Categories', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 22)),
                  
                  if (tempHidden.isNotEmpty)
                    TextButton(
                      onPressed: () {
                        setStateDialog(() {
                          tempHidden.clear();
                        });
                        
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text('Reset', style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w700, fontSize: 14)),
                    ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: IssueCategory.values.map((category) {
                  final style = kCategoryStyles[category]!;

                  final isVisible = !tempHidden.contains(category);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: GestureDetector(
                      onTap: () {
                        setStateDialog(() {
                          if (isVisible) {
                            tempHidden.add(category);
                          } else {
                            tempHidden.remove(category);
                          }
                        });
                        
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isVisible ? style.color.withOpacity(0.08) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isVisible ? style.color.withOpacity(0.3) : Colors.grey.shade200,
                            width: 1.5,
                          ),
                          boxShadow: isVisible ? [] : [
                            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isVisible ? style.color : Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(style.icon, color: isVisible ? Colors.white : Colors.grey.shade500, size: 20),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                style.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isVisible ? FontWeight.w700 : FontWeight.w500,
                                  color: isVisible ? Colors.black87 : Colors.grey.shade600,
                                ),
                              ),
                            ),
                            if (isVisible)
                              Icon(LucideIcons.checkCircle2, color: style.color, size: 24)
                            else
                              Icon(LucideIcons.circle, color: Colors.grey.shade300, size: 24),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              )),
              actionsPadding: const EdgeInsets.all(20),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black87,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  ),
                ),
              ],
            );
          },
        );
      },
    ).then((applied) {
      if (applied == true) {
        setState(() {
          _hiddenCategories = tempHidden;
        });
      }
    });
  }
}
class ReportFormWidget extends StatefulWidget {
  final LatLng location;
  final IssueCategory category;
  final Function(ReportModel) onSubmit;
  final VoidCallback onCancel;
  const ReportFormWidget({
    super.key,
    required this.location,
    required this.category,
    required this.onSubmit,
    required this.onCancel,
  });
  @override
  State<ReportFormWidget> createState() => _ReportFormWidgetState();
}
class _ReportFormWidgetState extends State<ReportFormWidget> {
  final _customTitleController = TextEditingController();
  final _descController = TextEditingController();
  String? _selectedSubcategory;
  static const _maxDescLength = 300;
  bool get _isValid {
    if (_selectedSubcategory == null) return false;
    if (_selectedSubcategory == 'Other' && _customTitleController.text.trim().isEmpty) return false;
    return _descController.text.trim().isNotEmpty;
  }
  @override
  void initState() {
    super.initState();
    _customTitleController.addListener(() => setState(() {}));
    _descController.addListener(() => setState(() {}));
  }
  @override
  void dispose() {
    _customTitleController.dispose();
    _descController.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final style = kCategoryStyles[widget.category]!;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 5,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: style.color.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(style.icon, color: style.color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report ${style.label} Issue',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${widget.location.latitude.toStringAsFixed(5)}, ${widget.location.longitude.toStringAsFixed(5)}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(LucideIcons.x, color: Colors.grey.shade600, size: 20),
                  onPressed: widget.onCancel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            value: _selectedSubcategory,
            hint: Text('Select a Subcategory', style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
            dropdownColor: Colors.white,
            borderRadius: BorderRadius.circular(20),
            elevation: 8,
            icon: Icon(LucideIcons.chevronDown, color: Colors.grey.shade600, size: 20),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            items: kSubcategories[widget.category]!.map((String value) {
              final isSelected = _selectedSubcategory == value;
              return DropdownMenuItem<String>(
                value: value,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.blue : Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          color: isSelected ? Colors.blue.shade700 : Colors.grey.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (newValue) {
              setState(() {
                _selectedSubcategory = newValue;
              });
            },
            isExpanded: true,
          ),
          if (_selectedSubcategory == 'Other') ...[
            const SizedBox(height: 16),
            TextField(
              controller: _customTitleController,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              decoration: InputDecoration(
                labelText: 'Custom Title',
                labelStyle: TextStyle(color: Colors.grey.shade600),
                hintText: 'Short summary of the issue',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _descController,
            maxLines: 4,
            maxLength: _maxDescLength,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Description',
              labelStyle: TextStyle(color: Colors.grey.shade600),
              hintText: 'What did you notice? Any details help.',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              alignLabelWithHint: true,
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Image upload mocked for prototype')),
              );
            },
            icon: const Icon(LucideIcons.camera, size: 20),
            label: const Text('Add Photo (Optional)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide(color: Colors.grey.shade300, width: 1.5),
              foregroundColor: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                    foregroundColor: Colors.grey.shade700,
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isValid
                      ? () {
                          final report = ReportModel(
                            location: widget.location,
                            category: widget.category,
                            title: _selectedSubcategory == 'Other' ? _customTitleController.text.trim() : _selectedSubcategory!,
                            description: _descController.text.trim(),
                          );
                          widget.onSubmit(report);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: const Color(0xFF2563EB),
                    disabledBackgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 6,
                    shadowColor: const Color(0xFF2563EB).withOpacity(0.5),
                  ),
                  child: const Text('Submit Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
