import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'report_model.dart';
import 'report_provider.dart';
import 'street_view_modal.dart';
import '../home_page.dart';

/// Centralized visual identity for each issue category.
class CategoryStyle {
  final IconData icon;
  final Color color;
  final Color glowColor;
  final String label;
  final List<Color> gradientColors;
  const CategoryStyle(
    this.icon,
    this.color,
    this.glowColor,
    this.label, {
    this.gradientColors = const [],
  });
}
const Map<IssueCategory, CategoryStyle> kCategoryStyles = {
  IssueCategory.infrastructure: CategoryStyle(
    LucideIcons.building,
    Color(0xFFFF6B6B),
    Color(0x66FF6B6B),
    'Infrastructure',
    gradientColors: [
      Color(0xFFFF7A7A), // Top specular highlight
      Color(0xFFFF5252), // Vibrant base coral red
      Color(0xFFDC2626), // Deep red bevel base
    ],
  ),
  IssueCategory.sanitation: CategoryStyle(
    LucideIcons.trash2,
    Color(0xFFF9A826),
    Color(0x66F9A826),
    'Sanitation',
    gradientColors: [
      Color(0xFFFFC043), // Top specular highlight
      Color(0xFFF59E0B), // Vibrant amber
      Color(0xFFD97706), // Deep golden orange base
    ],
  ),
  IssueCategory.safety: CategoryStyle(
    LucideIcons.shield,
    Color(0xFF4D96FF),
    Color(0x664D96FF),
    'Safety',
    gradientColors: [
      Color(0xFF60A5FA), // Top specular highlight
      Color(0xFF3B82F6), // Vibrant rich blue
      Color(0xFF1D4ED8), // Deep cobalt bevel base
    ],
  ),
  IssueCategory.greenery: CategoryStyle(
    LucideIcons.leaf,
    Color(0xFF4CAF50),
    Color(0x664CAF50),
    'Greenery',
    gradientColors: [
      Color(0xFF66BB6A), // Top specular highlight
      Color(0xFF43A047), // Vibrant emerald green
      Color(0xFF1B8A23), // Deep forest bevel base
    ],
  ),
};
const Map<IssueCategory, List<String>> kSubcategories = {
  IssueCategory.infrastructure: ['Nonfunctional street lights', 'Potholes', 'Water logging', 'Prolonged road work', 'Drainage', 'Other'],
  IssueCategory.sanitation: ['Garbage scattered on the road', 'Public washrooms not clean', 'Garbage beach/river', 'Untimely garbage collection/overflowing', 'Other'],
  IssueCategory.safety: ['Open manholes', 'Non existent footpath', 'Women safety', 'Illegal parking', 'Theft / Robbery', 'Harassment / Eve-Teasing', 'Assault / Violence', 'Poor Street Lighting', 'Fire Hazard', 'Electrical Hazard', 'Exposed Wires', 'Child Safety Concern', 'Stray Animal Threat', 'Other'],
  IssueCategory.greenery: ['Waste Dumping in Green Area', 'Poor Landscape Maintenance', 'Watering Required for Plants', 'Encroachment on Green Spaces', 'Pest or Insect Infestation', 'Overgrown Vegetation', 'Need Tree Plantation', 'Illegal Tree Cutting', 'Public problems on greenery', 'Other'],
};
enum MapStyle {
  streets,
  satellite,
  cleanLight,
  darkMode,
  outdoor,
}

class MapStyleOption {
  final MapStyle style;
  final String title;
  final String subtitle;
  final String urlTemplate;
  final IconData icon;
  final Color previewColor;
  final int maxNativeZoom;

  const MapStyleOption({
    required this.style,
    required this.title,
    required this.subtitle,
    required this.urlTemplate,
    required this.icon,
    required this.previewColor,
    this.maxNativeZoom = 19,
  });
}

const List<MapStyleOption> kMapStyles = [
  MapStyleOption(
    style: MapStyle.streets,
    title: 'Default',
    subtitle: 'Standard OpenStreetMap',
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    icon: LucideIcons.map,
    previewColor: Color(0xFFE2E8F0),
    maxNativeZoom: 19,
  ),
  MapStyleOption(
    style: MapStyle.satellite,
    title: 'Satellite',
    subtitle: 'Esri World Imagery',
    urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    icon: LucideIcons.satellite,
    previewColor: Color(0xFF1E3A5F),
    maxNativeZoom: 18,
  ),
  MapStyleOption(
    style: MapStyle.outdoor,
    title: 'Terrain',
    subtitle: 'OpenTopoMap',
    urlTemplate: 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
    icon: LucideIcons.mountain,
    previewColor: Color(0xFFD1FAE5),
    maxNativeZoom: 17,
  ),
];

enum MapOverlayType {
  transit,
  cycling,
  footpaths,
  hybridLabels,
}

class MapOverlayOption {
  final MapOverlayType type;
  final String title;
  final String subtitle;
  final String urlTemplate;
  final List<String>? subdomains;
  final IconData icon;
  final Color activeColor;

  const MapOverlayOption({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.urlTemplate,
    this.subdomains,
    required this.icon,
    required this.activeColor,
  });
}

const List<MapOverlayOption> kMapOverlays = [
  MapOverlayOption(
    type: MapOverlayType.transit,
    title: 'Public transport',
    subtitle: 'OpenRailwayMap train, tram & metro tracks',
    urlTemplate: 'https://{s}.tiles.openrailwaymap.org/standard/{z}/{x}/{y}.png',
    subdomains: ['a', 'b', 'c'],
    icon: LucideIcons.train,
    activeColor: Color(0xFF1A73E8),
  ),
  MapOverlayOption(
    type: MapOverlayType.cycling,
    title: 'Bicycling',
    subtitle: 'CyclOSM cycle paths & bike routes',
    urlTemplate: 'https://{s}.tile-cyclosm.openstreetmap.fr/cyclosm/{z}/{x}/{y}.png',
    subdomains: ['a', 'b', 'c'],
    icon: LucideIcons.bike,
    activeColor: Color(0xFF0F9D58),
  ),
  MapOverlayOption(
    type: MapOverlayType.footpaths,
    title: 'Walking trails',
    subtitle: 'Waymarked pedestrian routes and paths',
    urlTemplate: 'https://tile.waymarkedtrails.org/hiking/{z}/{x}/{y}.png',
    icon: LucideIcons.footprints,
    activeColor: Color(0xFFE37400),
  ),
  MapOverlayOption(
    type: MapOverlayType.hybridLabels,
    title: 'Street labels',
    subtitle: 'Overlays roads and labels on Satellite (Hybrid)',
    urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
    icon: LucideIcons.tags,
    activeColor: Color(0xFF1A73E8),
  ),
];

/// A highly customized, premium map pin without breathing animation.
class MapPinShape extends StatelessWidget {
  static const double headSize = 44;
  static const double boxWidth = 64;
  static const double boxHeight = 64; // Changed from 128 to 64 to avoid centering issues
  final IconData icon;
  final Color color;
  final Color glowColor;
  final List<Color> gradientColors;
  final bool isEditing;
  final bool isPending;

  const MapPinShape({
    super.key,
    required this.icon,
    required this.color,
    required this.glowColor,
    this.gradientColors = const [],
    this.isEditing = false,
    this.isPending = false,
  });

  @override
  Widget build(BuildContext context) {
    final ringColor = isEditing ? const Color(0xFFF59E0B) : Colors.white;
    
    // Scale the pin down if zoomed out, so it doesn't cover massive areas
    final camera = MapCamera.maybeOf(context);
    final zoom = camera?.zoom ?? 15.0;
    final zoomScale = ((zoom - 8) / (15 - 8)).clamp(0.4, 1.0);

    // 30% less emboss effect: gradient colors softened by 30% towards base color
    final effectiveGradients = gradientColors.isNotEmpty
        ? gradientColors.map((c) => Color.lerp(c, color, 0.3)!).toList()
        : [
            Color.lerp(Colors.white, color, 0.7)!,
            color,
            Color.lerp(Colors.black, color, 0.8)!,
          ];

    return Align(
      alignment: Alignment.center,
      child: Transform.scale(
        scale: zoomScale,
        alignment: Alignment.bottomCenter, // Anchored to the tip of the teardrop
        child: Transform.rotate(
          angle: 45 * 3.14159265359 / 180,
          child: Container(
            width: headSize,
            height: headSize,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: effectiveGradients,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(4),
              ),
              border: Border.all(color: ringColor, width: isEditing ? 3 : 2.5),
              boxShadow: [
                // Top specular highlight (directed straight up in screen space) - 30% softer
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.28),
                  offset: const Offset(-0.8, -0.8),
                  blurRadius: 1.2,
                  spreadRadius: 0,
                ),
                // Clean drop shadow (directed straight down in screen space)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  offset: const Offset(2.5, 2.5),
                  blurRadius: 6,
                  spreadRadius: 0,
                ),
                if (isPending || isEditing)
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(2, 2),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(4),
              ),
              child: Stack(
                children: [
                  // 30% softer glass shine on top dome (topLeft in rotated container = top dome of pin)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.18),
                            Colors.white.withValues(alpha: 0.0),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.center,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Transform.rotate(
                      angle: -45 * 3.14159265359 / 180,
                      child: Icon(
                        icon,
                        color: Colors.white,
                        size: headSize * 0.5,
                        shadows: const [
                          Shadow(
                            color: Color(0x30000000), // 30% softer engraved shadow
                            offset: Offset(0, 0.8),
                            blurRadius: 1.5,
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
      ),
    );
  }
}
class InteractiveMapScreen extends ConsumerStatefulWidget {
  final LatLng? initialCenter;
  final String? initialReportId;
  final double? initialZoom;

  const InteractiveMapScreen({
    super.key,
    this.initialCenter,
    this.initialReportId,
    this.initialZoom,
  });

  @override
  ConsumerState<InteractiveMapScreen> createState() => _InteractiveMapScreenState();
}

class _InteractiveMapScreenState extends ConsumerState<InteractiveMapScreen> {
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
  MapStyle _selectedMapStyle = MapStyle.streets;
  final Set<MapOverlayType> _activeOverlays = {MapOverlayType.hybridLabels};
  bool _showCategoryHint = true;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialCenter != null) {
        _mapController.move(widget.initialCenter!, widget.initialZoom ?? 16.5);
      } else {
        _goToMyLocation();
      }
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
      _showCategoryHint = false;
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
      _showCategoryHint = false;
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
  void _handleBackNavigation() {
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
    final reports = ref.watch(interactiveReportProvider);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_searchFocusNode.hasFocus) {
          _searchFocusNode.unfocus();
          setState(() {
            _searchController.clear();
            _suggestions = [];
          });
          return;
        }
        _handleBackNavigation();
      },
      child: Scaffold(
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
                    initialCenter: widget.initialCenter ?? const LatLng(28.6139, 77.2090),
                    initialZoom: widget.initialCenter != null ? (widget.initialZoom ?? 16.5) : 14.0,
              minZoom: 3.0,
              maxZoom: 22.0,
              onTap: (_, __) => FocusScope.of(context).unfocus(),
              interactionOptions: InteractionOptions(
                flags: (_editingReportId != null || _droppedLocation != null)
                    ? InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom
                    : InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                key: ValueKey(_selectedMapStyle),
                urlTemplate: kMapStyles.firstWhere((s) => s.style == _selectedMapStyle).urlTemplate,
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.unisafe.app',
                maxNativeZoom: kMapStyles.firstWhere((s) => s.style == _selectedMapStyle).maxNativeZoom,
                minNativeZoom: 0,
                keepBuffer: 6,
                panBuffer: 1,
                tileUpdateTransformer: TileUpdateTransformers.debounce(const Duration(milliseconds: 100)),
                tileDisplay: const TileDisplay.fadeIn(duration: Duration(milliseconds: 120)),
              ),
              // Optional transparent overlays (Hybrid labels, transit network, footpaths)
              for (final overlay in kMapOverlays)
                if (_activeOverlays.contains(overlay.type))
                  TileLayer(
                    key: ValueKey('overlay_${overlay.type}'),
                    urlTemplate: overlay.urlTemplate,
                    subdomains: overlay.subdomains ?? const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.unisafe.app',
                    maxNativeZoom: 18,
                    minNativeZoom: 0,
                    keepBuffer: 4,
                    panBuffer: 1,
                    tileUpdateTransformer: TileUpdateTransformers.debounce(const Duration(milliseconds: 100)),
                    tileDisplay: const TileDisplay.fadeIn(duration: Duration(milliseconds: 100)),
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
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _showReportOptions(r),
                          child: MapPinShape(
                            icon: style.icon, 
                            color: style.color, 
                            glowColor: style.glowColor,
                            gradientColors: style.gradientColors,
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
                        alignment: Alignment.topCenter,
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
                              ref.read(interactiveReportProvider.notifier).updateReport(r.copyWith(location: _draggedReportLocation));
                            }
                          },
                          child: MapPinShape(
                            icon: style.icon, 
                            color: style.color, 
                            glowColor: style.glowColor,
                            gradientColors: style.gradientColors,
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
                      alignment: Alignment.topCenter,
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
                          gradientColors: kCategoryStyles[_selectedCategory!]!.gradientColors,
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
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Fluid Merging & Splitting Search Bar Header
                    FluidMergeSearchBar(
                      focusNode: _searchFocusNode,
                      controller: _searchController,
                      isSearching: _isSearching,
                      onSearchChanged: _onSearchChanged,
                      onSearchSubmitted: _searchLocation,
                      onBack: _handleBackNavigation,
                      onCancelSearch: () {
                        _searchFocusNode.unfocus();
                        _searchController.clear();
                        setState(() => _suggestions = []);
                      },
                      onClearText: () {
                        _searchController.clear();
                        setState(() => _suggestions = []);
                      },
                    ),
                    
                    
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        // Pin Categories Bar (When idle)
                        if (_droppedLocation == null && _editingReportId == null)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(height: 10),
                              LiquidGlassContainer(
                                borderRadius: 36,
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                child: Row(
                                  children: [
                                    for (var category in IssueCategory.values)
                                      Expanded(
                                        child: _buildCategoryButton(category),
                                      ),
                                  ],
                                ),
                              ),
                              if (_showCategoryHint && _suggestions.isEmpty)
                                AnimatedOpacity(
                                  duration: const Duration(milliseconds: 250),
                                  opacity: _showCategoryHint ? 1.0 : 0.0,
                                  child: Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.60),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.15),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Text(
                                      'Tap or drag a category to report',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
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
                            constraints: const BoxConstraints(maxHeight: 280),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
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
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
                    // Bottom Action Areas
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              bottom: true,
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Bottom Action Buttons: Layers & Filter on right, Embossed Take Picture + Locate on bottom
                    if (_droppedLocation == null && _editingReportId == null)
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _MapLiquidGlassActionButton(
                                  icon: LucideIcons.layers,
                                  tooltip: 'Map Style',
                                  onTap: _showMapStyleDialog,
                                  size: 54,
                                ),
                                const SizedBox(height: 12),
                                _MapLiquidGlassActionButton(
                                  icon: LucideIcons.filter,
                                  tooltip: 'Filter Issues',
                                  onTap: _showFilterDialog,
                                  hasBadge: _hiddenCategories.isNotEmpty,
                                  size: 54,
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                          SizedBox(
                            height: 54,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 54,
                                    child: EmbossedTakePictureButton(
                                      height: 54,
                                      onTap: _takeInstantPictureAndReport,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                SizedBox(
                                  width: 54,
                                  height: 54,
                                  child: _MapActionButton(
                                    icon: LucideIcons.locate,
                                    tooltip: 'My Location',
                                    onTap: _isFetchingLocation ? null : _goToMyLocation,
                                    isLoading: _isFetchingLocation,
                                    size: 54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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
          ),
        ],
      ),
    ),
  );
}
  Widget _buildCategoryButton(IssueCategory category) {
    return EmbossedCategoryButton(
      category: category,
      onTap: () => _onCategoryTapped(category),
      onDragStarted: () {
        if (_showCategoryHint) {
          setState(() => _showCategoryHint = false);
        }
      },
    );
  }

  Widget _buildPendingActionPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(LucideIcons.mapPin, size: 14, color: Color(0xFF059669)),
              const SizedBox(width: 6),
              Text(
                'Drag pin to adjust position',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CircularCancelButton(
                onTap: () {
                  setState(() {
                    _droppedLocation = null;
                    _selectedCategory = null;
                  });
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: EmbossedActionButton(
                  onTap: () {
                    _showReportForm(context, _droppedLocation!);
                  },
                  label: 'Confirm Location',
                  icon: LucideIcons.check,
                  gradientColors: const [
                    Color(0xFF34D399), // Emerald highlight
                    Color(0xFF10B981), // Emerald base
                    Color(0xFF059669), // Deep emerald
                  ],
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.mapPin, size: 14, color: Color(0xFFD97706)),
                  const SizedBox(width: 6),
                  Text(
                    'Drag pin to reposition',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  CircularCancelButton(
                    onTap: () {
                      setState(() => _editingReportId = null);
                    },
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: EmbossedActionButton(
                      onTap: () {
                        setState(() => _editingReportId = null);
                      },
                      label: 'Save Position',
                      icon: LucideIcons.check,
                      gradientColors: const [
                        Color(0xFFFBBF24), // Amber highlight
                        Color(0xFFF59E0B), // Rich amber
                        Color(0xFFD97706), // Deep amber
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
    );
  }
  Future<void> _takeInstantPictureAndReport() async {
    try {
      final picker = ImagePicker();
      XFile? photo;
      try {
        photo = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );
      } catch (e) {
        // Fallback to gallery if direct camera capture fails or is unsupported
        photo = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );
      }

      if (photo == null) return;

      final bytes = await photo.readAsBytes();
      final reportLocation = _myLocation ?? _mapController.camera.center;

      // Animate map camera smoothly to the incident location
      _mapController.move(reportLocation, 16.5);

      if (mounted) {
        _showReportForm(
          context,
          reportLocation,
          initialImagePath: photo.path,
          initialImageBytes: bytes,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text('Could not capture picture: $e'),
          ),
        );
      }
    }
  }

  void _showReportForm(
    BuildContext context,
    LatLng location, {
    IssueCategory? initialCategory,
    String? initialImagePath,
    Uint8List? initialImageBytes,
  }) {
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
            initialCategory: initialCategory ?? _selectedCategory ?? IssueCategory.infrastructure,
            initialImagePath: initialImagePath,
            initialImageBytes: initialImageBytes,
            onSubmit: (report) {
              ref.read(interactiveReportProvider.notifier).addReport(report);
              setState(() {
                _droppedLocation = null;
                _selectedCategory = null;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF1E293B),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  content: Row(
                    children: [
                      const Icon(LucideIcons.circleCheck, color: Color(0xFF10B981), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Report "${report.title}" submitted successfully!',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            onCancel: () {
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }
  void _openFullScreenImage({Uint8List? imageBytes, String? imagePath, String? title}) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.92),
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
                              : const Icon(LucideIcons.image, size: 80, color: Colors.white54))),
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
                        )
                      else
                        const Spacer(),
                      const SizedBox(width: 12),
                      Material(
                        color: Colors.black54,
                        shape: const CircleBorder(),
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                          onPressed: () => Navigator.of(ctx).pop(),
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

  void _showReportOptions(ReportModel report) {
    final style = kCategoryStyles[report.category]!;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 20),
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
                            Row(
                              children: [
                                Text(style.label, style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                                if (report.citizenName != null && report.citizenName!.isNotEmpty) ...[
                                  Text(' • ', style: TextStyle(color: Colors.grey.shade400)),
                                  Icon(LucideIcons.user, size: 12, color: Colors.grey.shade600),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      report.citizenName!,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (report.description.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(14),
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
                  if (report.imageBytes != null || (report.imagePath != null && report.imagePath!.isNotEmpty)) ...[
                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () => _openFullScreenImage(
                        imageBytes: report.imageBytes,
                        imagePath: report.imagePath,
                        title: report.title,
                      ),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: 180,
                              width: double.infinity,
                              color: Colors.grey.shade100,
                              child: report.imageBytes != null
                                  ? Image.memory(report.imageBytes!, fit: BoxFit.cover)
                                  : (report.imagePath != null && report.imagePath!.startsWith('data:image')
                                      ? Image.memory(base64Decode(report.imagePath!.split(',').last), fit: BoxFit.cover)
                                      : (report.imagePath != null && report.imagePath!.startsWith('http')
                                          ? Image.network(report.imagePath!, fit: BoxFit.cover)
                                          : const Center(child: Icon(LucideIcons.image, size: 40, color: Colors.grey)))),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.65),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.maximize2, color: Colors.white, size: 13),
                                  SizedBox(width: 4),
                                  Text(
                                    'Full Screen',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        StreetViewModal.show(
                          context,
                          latitude: report.location.latitude,
                          longitude: report.location.longitude,
                          title: report.title,
                        );
                      },
                      icon: const Icon(LucideIcons.compass, size: 18, color: Color(0xFF059669)),
                      label: const Text(
                        'Open 360° Street View',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF059669),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: const Color(0xFF059669).withValues(alpha: 0.08),
                        side: BorderSide(
                          color: const Color(0xFF059669).withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                            padding: const EdgeInsets.symmetric(vertical: 14),
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
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            backgroundColor: Colors.red.shade50,
                            foregroundColor: Colors.red.shade700,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
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
              ref.read(interactiveReportProvider.notifier).deleteReport(report.id);
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      elevation: 8,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top drag pill
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDADCE0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Header row: "Filter categories" + Reset + Close
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Filter categories',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF202124),
                            letterSpacing: -0.2,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (tempHidden.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: TextButton(
                                  onPressed: () {
                                    setSheetState(() {
                                      tempHidden.clear();
                                    });
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Reset',
                                    style: TextStyle(
                                      color: Color(0xFF1A73E8),
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            IconButton(
                              icon: const Icon(LucideIcons.x, size: 20, color: Color(0xFF5F6368)),
                              splashRadius: 20,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Toggle visible issues on map',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5F6368),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Row of 4 Category Filters: Infrastructure, Sanitation, Safety, Greenery
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: IssueCategory.values.map((category) {
                        final isVisible = !tempHidden.contains(category);
                        return _CategoryFilterCard(
                          category: category,
                          isSelected: isVisible,
                          onTap: () {
                            setSheetState(() {
                              if (isVisible) {
                                tempHidden.add(category);
                              } else {
                                tempHidden.remove(category);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    // Blue Save Filters Button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _hiddenCategories = tempHidden;
                          });
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A73E8),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(LucideIcons.check, size: 18, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Save Filters',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showMapStyleDialog() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      elevation: 8,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top drag pill
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDADCE0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Header row: "Map type" + close button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Map type',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF202124),
                            letterSpacing: -0.2,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(LucideIcons.x, size: 20, color: Color(0xFF5F6368)),
                          splashRadius: 20,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Row of 3 Map Types: Default, Satellite, Terrain
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: kMapStyles.map((styleOption) {
                        final isSelected = _selectedMapStyle == styleOption.style;
                        return _MapTypeCard(
                          title: styleOption.title,
                          isSelected: isSelected,
                          thumbnail: _buildMapThumbnail(styleOption.style),
                          onTap: () {
                            setSheetState(() {
                              _selectedMapStyle = styleOption.style;
                            });
                            setState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFF1F3F4)),
                    const SizedBox(height: 18),
                    // "Map details" header
                    const Text(
                      'Map details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF202124),
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Details Grid (OSM supported details)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: kMapOverlays.map((overlay) {
                        final isOverlayActive = _activeOverlays.contains(overlay.type);
                        return _MapDetailButton(
                          title: overlay.title,
                          isSelected: isOverlayActive,
                          iconWidget: _buildOverlayIcon(overlay.type, isOverlayActive),
                          onTap: () {
                            setSheetState(() {
                              if (isOverlayActive) {
                                _activeOverlays.remove(overlay.type);
                              } else {
                                _activeOverlays.add(overlay.type);
                              }
                            });
                            setState(() {});
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}



class _MapTypeCard extends StatefulWidget {
  final String title;
  final bool isSelected;
  final Widget thumbnail;
  final VoidCallback onTap;

  const _MapTypeCard({
    required this.title,
    required this.isSelected,
    required this.thumbnail,
    required this.onTap,
  });

  @override
  State<_MapTypeCard> createState() => _MapTypeCardState();
}

class _MapTypeCardState extends State<_MapTypeCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _isPressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: widget.isSelected ? const Color(0xFF1A73E8) : const Color(0xFFDADCE0),
                  width: widget.isSelected ? 2.5 : 1.0,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.isSelected ? 15.5 : 17),
                child: widget.thumbnail,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.title,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                color: widget.isSelected ? const Color(0xFF1A73E8) : const Color(0xFF3C4043),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DefaultMapThumbnail extends StatelessWidget {
  const _DefaultMapThumbnail();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFD4E4FA),
      child: Stack(
        children: [
          // Green park patch
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFCEEAD6),
                borderRadius: BorderRadius.only(topLeft: Radius.circular(16)),
              ),
            ),
          ),
          // Yellow main road
          Positioned(
            left: -10,
            bottom: 14,
            right: -10,
            child: Transform.rotate(
              angle: -0.38,
              child: Container(
                height: 9,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEEFC3),
                  border: Border.symmetric(
                    horizontal: BorderSide(color: const Color(0xFFF9AB00).withValues(alpha: 0.6), width: 0.8),
                  ),
                ),
              ),
            ),
          ),
          // White crossing street
          Positioned(
            top: -10,
            left: 24,
            bottom: -10,
            child: Transform.rotate(
              angle: 0.32,
              child: Container(
                width: 8,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border.symmetric(
                    vertical: BorderSide(color: Color(0xFFDADCE0), width: 0.8),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SatelliteMapThumbnail extends StatelessWidget {
  const _SatelliteMapThumbnail();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF263238), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: CustomPaint(
        painter: _SatelliteRoadPainter(),
        size: const Size(74, 74),
      ),
    );
  }
}

class _SatelliteRoadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Dark vegetation patch
    final darkPatch = Paint()..color = const Color(0xFF1C2D27);
    canvas.drawCircle(Offset(size.width * 0.75, size.height * 0.3), 20, darkPatch);

    // Curved white road across satellite
    final roadPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height * 0.42)
      ..cubicTo(
        size.width * 0.4, size.height * 0.48,
        size.width * 0.55, size.height * 0.72,
        size.width, size.height * 0.68,
      );
    canvas.drawPath(path, roadPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TerrainMapThumbnail extends StatelessWidget {
  const _TerrainMapThumbnail();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8EEF5),
      child: CustomPaint(
        painter: _TerrainContourPainter(),
        size: const Size(74, 74),
      ),
    );
  }
}

class _TerrainContourPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final contourPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    // 3 smooth contour lines spanning across the card
    for (int i = 1; i <= 3; i++) {
      final yOffset = size.height * (0.24 * i);
      final path = Path()
        ..moveTo(0, yOffset + 4)
        ..quadraticBezierTo(
          size.width * 0.5,
          yOffset - 10,
          size.width,
          yOffset + 6,
        );
      canvas.drawPath(path, contourPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapDetailButton extends StatefulWidget {
  final String title;
  final bool isSelected;
  final Widget iconWidget;
  final VoidCallback onTap;

  const _MapDetailButton({
    required this.title,
    required this.isSelected,
    required this.iconWidget,
    required this.onTap,
  });

  @override
  State<_MapDetailButton> createState() => _MapDetailButtonState();
}

class _MapDetailButtonState extends State<_MapDetailButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _isPressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 100),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? const Color(0xFFE8F0FE)
                      : const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: widget.isSelected
                        ? const Color(0xFF1A73E8)
                        : const Color(0xFFE8EAED),
                    width: widget.isSelected ? 2.4 : 1.0,
                  ),
                  boxShadow: widget.isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF1A73E8).withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(child: widget.iconWidget),
              ),
              const SizedBox(height: 6),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.15,
                    fontWeight: widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: widget.isSelected
                        ? const Color(0xFF1A73E8)
                        : const Color(0xFF3C4043),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryFilterCard extends StatefulWidget {
  final IssueCategory category;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryFilterCard({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_CategoryFilterCard> createState() => _CategoryFilterCardState();
}

class _CategoryFilterCardState extends State<_CategoryFilterCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final style = kCategoryStyles[widget.category]!;
    final isSelected = widget.isSelected;
    final categoryColor = style.color;

    return SizedBox(
      width: 74,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedScale(
          scale: _isPressed ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 100),
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: isSelected
                      ? categoryColor.withValues(alpha: 0.12)
                      : const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? categoryColor : const Color(0xFFE2E8F0),
                    width: isSelected ? 2.2 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: categoryColor.withValues(alpha: 0.22),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Icon(
                    style.icon,
                    color: isSelected ? categoryColor : const Color(0xFF94A3B8),
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 7),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  style.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? categoryColor : const Color(0xFF64748B),
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildOverlayIcon(MapOverlayType type, bool isSelected) {
  switch (type) {
    case MapOverlayType.transit:
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: const Color(0xFF1A73E8),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Icon(LucideIcons.train, color: Colors.white, size: 19),
        ),
      );
    case MapOverlayType.cycling:
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF0F9D58), width: 2.2),
        ),
        child: const Center(
          child: Icon(LucideIcons.bike, color: Color(0xFF0F9D58), size: 17),
        ),
      );
    case MapOverlayType.footpaths:
      return const Icon(
        LucideIcons.footprints,
        color: Color(0xFFE37400),
        size: 24,
      );
    case MapOverlayType.hybridLabels:
      return const Icon(
        LucideIcons.tags,
        color: Color(0xFF1A73E8),
        size: 24,
      );
  }
}


Widget _buildMapThumbnail(MapStyle style) {
  switch (style) {
    case MapStyle.streets:
      return const _DefaultMapThumbnail();
    case MapStyle.satellite:
      return const _SatelliteMapThumbnail();
    case MapStyle.outdoor:
    default:
      return const _TerrainMapThumbnail();
  }
}
class EmbossedTakePictureButton extends StatefulWidget {
  final VoidCallback onTap;
  final double height;
  const EmbossedTakePictureButton({
    super.key,
    required this.onTap,
    this.height = 52.0,
  });

  @override
  State<EmbossedTakePictureButton> createState() => _EmbossedTakePictureButtonState();
}

class _EmbossedTakePictureButtonState extends State<EmbossedTakePictureButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _depthAnimation;
  late final Animation<double> _shadowBlurAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutQuad,
        reverseCurve: Curves.easeOutBack,
      ),
    );
    _depthAnimation = Tween<double>(begin: 0.0, end: 2.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutQuad,
        reverseCurve: Curves.easeOutBack,
      ),
    );
    _shadowBlurAnimation = Tween<double>(begin: 10.0, end: 3.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutQuad,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    Future.delayed(const Duration(milliseconds: 70), () {
      if (mounted) _controller.reverse();
    });
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final double scale = _scaleAnimation.value;
          final double depth = _depthAnimation.value;
          final double shadowBlur = _shadowBlurAnimation.value;
          final double pressFraction = _controller.value;

          return Transform.scale(
            scale: scale,
            child: Transform.translate(
              offset: Offset(0, depth),
              child: Container(
                height: widget.height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.height / 2),
                  gradient: LinearGradient(
                    colors: [
                      Color.lerp(const Color(0xFF3B82F6), const Color(0xFF2563EB), pressFraction)!,
                      const Color(0xFF2563EB),
                      Color.lerp(const Color(0xFF1D4ED8), const Color(0xFF1E40AF), pressFraction)!,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.45 - (pressFraction * 0.2)),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15 - (pressFraction * 0.05)),
                      offset: Offset(0, 4.0 - (pressFraction * 2.0)),
                      blurRadius: shadowBlur,
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.35 - (pressFraction * 0.2)),
                      offset: const Offset(0, -1),
                      blurRadius: 1.5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.height / 2),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: widget.height * 0.4,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.20 - (pressFraction * 0.12)),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      const Center(
                        child: Text(
                          'Take Picture',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                            shadows: [
                              Shadow(
                                color: Color(0x44000000),
                                offset: Offset(0, 1),
                                blurRadius: 2,
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
          );
        },
      ),
    );
  }
}

class CircularCancelButton extends StatefulWidget {
  final VoidCallback onTap;
  final double size;

  const CircularCancelButton({
    super.key,
    required this.onTap,
    this.size = 48.0,
  });

  @override
  State<CircularCancelButton> createState() => _CircularCancelButtonState();
}

class _CircularCancelButtonState extends State<CircularCancelButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _depthAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutQuad,
        reverseCurve: Curves.easeOutBack,
      ),
    );
    _depthAnimation = Tween<double>(begin: 0.0, end: 1.8).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutQuad,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    Future.delayed(const Duration(milliseconds: 70), () {
      if (mounted) _controller.reverse();
    });
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final double scale = _scaleAnimation.value;
          final double depth = _depthAnimation.value;

          return Transform.scale(
            scale: scale,
            child: Transform.translate(
              offset: Offset(0, depth),
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: Color.lerp(Colors.white, const Color(0xFFF1F5F9), _controller.value),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12 - (_controller.value * 0.04)),
                      offset: Offset(0, 4.0 - (_controller.value * 2.5)),
                      blurRadius: 10.0 - (_controller.value * 6.0),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    LucideIcons.x,
                    color: Colors.red.shade600,
                    size: 22,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MapActionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final bool isLoading;
  final double size;

  const _MapActionButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.isLoading = false,
    this.size = 54.0,
  });

  @override
  State<_MapActionButton> createState() => _MapActionButtonState();
}

class _MapActionButtonState extends State<_MapActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _depthAnimation;
  late final Animation<double> _discDepthAnimation;
  late final Animation<double> _shadowBlurAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutQuad,
        reverseCurve: Curves.easeOutBack,
      ),
    );
    _depthAnimation = Tween<double>(begin: 0.0, end: 1.4).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutQuad,
        reverseCurve: Curves.easeOutBack,
      ),
    );
    _discDepthAnimation = Tween<double>(begin: 0.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutQuad,
        reverseCurve: Curves.easeOutBack,
      ),
    );
    _shadowBlurAnimation = Tween<double>(begin: 10.0, end: 3.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutQuad,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    Future.delayed(const Duration(milliseconds: 70), () {
      if (mounted) _controller.reverse();
    });
    if (!widget.isLoading) {
      widget.onTap?.call();
    }
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final double size = widget.size;
    final double trenchSize = size * 0.83;
    final double discSize = size * 0.70;
    final double iconSize = size * 0.40;

    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final double scale = _scaleAnimation.value;
            final double depth = _depthAnimation.value;
            final double discDepth = _discDepthAnimation.value;
            final double shadowBlur = _shadowBlurAnimation.value;
            final double pressFraction = _controller.value;

            return Transform.scale(
              scale: scale,
              child: Transform.translate(
                offset: Offset(0, depth),
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14 - (pressFraction * 0.04)),
                        offset: Offset(0, 4.0 - (pressFraction * 2.2)),
                        blurRadius: shadowBlur,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        offset: Offset(0, 1.0 - (pressFraction * 0.5)),
                        blurRadius: 3.0 - (pressFraction * 1.5),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 1. Outer Bezel Collar (Raised chamfered rim)
                      Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Color.lerp(const Color(0xFFFFFFFF), const Color(0xFFF1F5F9), pressFraction)!,
                              const Color(0xFFF8FAFC),
                              Color.lerp(const Color(0xFFE2E8F0), const Color(0xFFCBD5E1), pressFraction)!,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 1.0 - (pressFraction * 0.2)),
                            width: 1.2,
                          ),
                        ),
                      ),

                      // 2. Recessed Sunken Trench / Channel
                      Container(
                        width: trenchSize,
                        height: trenchSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFCBD5E1), // Slate 300 deep inner shadow at top
                              Color(0xFFE2E8F0), // Slate 200
                              Color(0xFFF1F5F9), // Slate 100 bottom light
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          border: Border.all(
                            color: const Color(0xFFCBD5E1).withValues(alpha: 0.7),
                            width: 0.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.16 + (pressFraction * 0.08)),
                              blurRadius: 3.0 + (pressFraction * 1.5),
                              offset: const Offset(0, 1.5),
                            ),
                          ],
                        ),
                      ),

                      // 3. Inner Raised Disc (Interactive center button)
                      Transform.translate(
                        offset: Offset(0, discDepth),
                        child: Container(
                          width: discSize,
                          height: discSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Color.lerp(const Color(0xFFFFFFFF), const Color(0xFFE2E8F0), pressFraction)!,
                                Color.lerp(const Color(0xFFF8FAFC), const Color(0xFFF1F5F9), pressFraction)!,
                                Color.lerp(const Color(0xFFE8ECEF), const Color(0xFFFFFFFF), pressFraction)!,
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                            border: Border.all(
                              color: Colors.white,
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.18 - (pressFraction * 0.08)),
                                offset: Offset(0, 2.0 - (pressFraction * 1.0)),
                                blurRadius: 3.5 - (pressFraction * 1.5),
                                spreadRadius: 0,
                              ),
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.9 - (pressFraction * 0.6)),
                                offset: const Offset(0, -0.8),
                                blurRadius: 1,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Center(
                            child: widget.isLoading
                                ? SizedBox(
                                    width: iconSize * 0.85,
                                    height: iconSize * 0.85,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E293B)),
                                    ),
                                  )
                                : Icon(
                                    widget.icon,
                                    color: const Color(0xFF1E293B),
                                    size: iconSize,
                                  ),
                          ),
                        ),
                      ),

                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Solid white container with refined border and soft ambient shadows.
class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final double borderRadius;
  final bool isCircle;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double frostBlur;
  final Color tintColor;
  final List<BoxShadow>? shadows;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.borderRadius = 25.0,
    this.isCircle = false,
    this.padding,
    this.margin,
    this.onTap,
    this.frostBlur = 24.0,
    this.tintColor = Colors.white,
    this.shadows,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorderRadius = isCircle ? null : BorderRadius.circular(borderRadius);

    final defaultShadows = shadows ?? [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        blurRadius: 16,
        offset: const Offset(0, 4),
        spreadRadius: 0,
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.03),
        blurRadius: 4,
        offset: const Offset(0, 1),
        spreadRadius: 0,
      ),
    ];

    Widget content = child;
    if (padding != null) {
      content = Padding(padding: padding!, child: content);
    }

    Widget container = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: effectiveBorderRadius,
        border: Border.all(
          color: const Color(0xFFE2E8F0),
          width: 1.0,
        ),
        boxShadow: defaultShadows,
      ),
      child: isCircle
          ? ClipOval(child: content)
          : ClipRRect(
              borderRadius: effectiveBorderRadius ?? BorderRadius.circular(borderRadius),
              child: content,
            ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: container,
      );
    }

    return container;
  }
}

class _MapLiquidGlassActionButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final bool hasBadge;
  final double size;

  const _MapLiquidGlassActionButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.hasBadge = false,
    this.size = 54.0,
  });

  @override
  State<_MapLiquidGlassActionButton> createState() => _MapLiquidGlassActionButtonState();
}

class _MapLiquidGlassActionButtonState extends State<_MapLiquidGlassActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap?.call();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.93 : 1.0,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              LiquidGlassContainer(
                isCircle: true,
                width: widget.size,
                height: widget.size,
                frostBlur: 20.0,
                child: Center(
                  child: Icon(
                    widget.icon,
                    color: const Color(0xFF1E293B),
                    size: widget.size * 0.42,
                  ),
                ),
              ),
              if (widget.hasBadge)
                Positioned(
                  top: 2,
                  right: 2,
                  child: IgnorePointer(
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.20),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmbossedActionButton extends StatefulWidget {
  final VoidCallback onTap;
  final String label;
  final IconData icon;
  final List<Color> gradientColors;
  final double height;

  const EmbossedActionButton({
    super.key,
    required this.onTap,
    required this.label,
    required this.icon,
    required this.gradientColors,
    this.height = 48.0,
  });

  @override
  State<EmbossedActionButton> createState() => _EmbossedActionButtonState();
}

class _EmbossedActionButtonState extends State<EmbossedActionButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _depthAnimation;
  late final Animation<double> _shadowBlurAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutQuad,
        reverseCurve: Curves.easeOutBack,
      ),
    );
    _depthAnimation = Tween<double>(begin: 0.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutQuad,
        reverseCurve: Curves.easeOutBack,
      ),
    );
    _shadowBlurAnimation = Tween<double>(begin: 10.0, end: 3.5).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutQuad,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    Future.delayed(const Duration(milliseconds: 70), () {
      if (mounted) _controller.reverse();
    });
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      behavior: HitTestBehavior.opaque,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final double scale = _scaleAnimation.value;
          final double depth = _depthAnimation.value;
          final double shadowBlur = _shadowBlurAnimation.value;
          final double pressFraction = _controller.value;

          return Transform.scale(
            scale: scale,
            child: Transform.translate(
              offset: Offset(0, depth),
              child: Container(
                height: widget.height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.height / 2),
                  gradient: LinearGradient(
                    colors: widget.gradientColors,
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.5 - (pressFraction * 0.25)),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15 - (pressFraction * 0.05)),
                      offset: Offset(0, 4.0 - (pressFraction * 2.0)),
                      blurRadius: shadowBlur,
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.35 - (pressFraction * 0.2)),
                      offset: const Offset(0, -1),
                      blurRadius: 1.5,
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.height / 2),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: widget.height * 0.4,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.22 - (pressFraction * 0.14)),
                                Colors.white.withValues(alpha: 0.0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              widget.icon,
                              color: Colors.white,
                              size: 20,
                              shadows: const [
                                Shadow(
                                  color: Color(0x55000000),
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                shadows: [
                                  Shadow(
                                    color: Color(0x55000000),
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
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
        },
      ),
    );
  }
}

class EmbossedCategoryIcon extends StatelessWidget {
  final IssueCategory category;
  final double size;
  final double iconSize;
  final bool isPressed;

  const EmbossedCategoryIcon({
    super.key,
    required this.category,
    this.size = 46.0,
    this.iconSize = 22.0,
    this.isPressed = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = kCategoryStyles[category]!;
    final gradient = style.gradientColors.isNotEmpty
        ? style.gradientColors
        : [style.color, style.color];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 100),
      width: size,
      height: size,
      transform: Matrix4.translationValues(0, isPressed ? 1.5 : 0.0, 0),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border.all(
          color: isPressed
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.48),
          width: 1.5,
        ),
        boxShadow: isPressed
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  offset: const Offset(0, 1.5),
                  blurRadius: 3,
                ),
              ]
            : [
                // Clean drop shadow matching Take Picture style
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  offset: const Offset(0, 4),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
                // Top specular rim highlight for 3D bevel depth
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.4),
                  offset: const Offset(0, -1),
                  blurRadius: 1.5,
                  spreadRadius: 0,
                ),
              ],
      ),
      child: ClipOval(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Top glass bevel shine
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: size * 0.44,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: isPressed ? 0.08 : 0.25),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            // Centered icon with engraved bevel shadow
            Icon(
              style.icon,
              color: Colors.white,
              size: iconSize,
              shadows: const [
                Shadow(
                  color: Color(0x44000000),
                  offset: Offset(0, 1),
                  blurRadius: 2,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class EmbossedCategoryButton extends StatefulWidget {
  final IssueCategory category;
  final VoidCallback onTap;
  final VoidCallback? onDragStarted;

  const EmbossedCategoryButton({
    super.key,
    required this.category,
    required this.onTap,
    this.onDragStarted,
  });

  @override
  State<EmbossedCategoryButton> createState() => _EmbossedCategoryButtonState();
}

class _EmbossedCategoryButtonState extends State<EmbossedCategoryButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 240),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutQuad,
        reverseCurve: Curves.easeOutBack,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    Future.delayed(const Duration(milliseconds: 70), () {
      if (mounted) _controller.reverse();
    });
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final style = kCategoryStyles[widget.category]!;

    return Draggable<IssueCategory>(
      data: widget.category,
      onDragStarted: widget.onDragStarted,
      feedback: Material(
        color: Colors.transparent,
        child: EmbossedCategoryIcon(
          category: widget.category,
          size: 54,
          iconSize: 26,
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EmbossedCategoryIcon(
                category: widget.category,
                size: 46,
                iconSize: 22,
                isPressed: false,
              ),
              const SizedBox(height: 5),
              Text(
                style.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      ),
      child: GestureDetector(
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EmbossedCategoryIcon(
                      category: widget.category,
                      size: 46,
                      iconSize: 22,
                      isPressed: _controller.value > 0.4,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      style.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class ReportFormWidget extends StatefulWidget {
  final LatLng location;
  final IssueCategory initialCategory;
  final String? initialImagePath;
  final Uint8List? initialImageBytes;
  final Function(ReportModel) onSubmit;
  final VoidCallback onCancel;

  const ReportFormWidget({
    super.key,
    required this.location,
    this.initialCategory = IssueCategory.infrastructure,
    this.initialImagePath,
    this.initialImageBytes,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<ReportFormWidget> createState() => _ReportFormWidgetState();
}

class _ReportFormWidgetState extends State<ReportFormWidget> {
  final _customTitleController = TextEditingController();
  final _descController = TextEditingController();
  late IssueCategory _category;
  String? _selectedSubcategory;
  String? _imagePath;
  Uint8List? _imageBytes;
  bool _isProcessingImage = false;
  static const _maxDescLength = 300;

  bool get _isValid {
    if (_selectedSubcategory == null) return false;
    if (_selectedSubcategory == 'Other' && _customTitleController.text.trim().isEmpty) return false;
    return _descController.text.trim().isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _imagePath = widget.initialImagePath;
    _imageBytes = widget.initialImageBytes;
    _customTitleController.addListener(() => setState(() {}));
    _descController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _customTitleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    setState(() => _isProcessingImage = true);
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _imagePath = photo.path;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingImage = false);
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(4)),
            ),
            const Text('Add Incident Photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                child: const Icon(LucideIcons.camera, color: Color(0xFF2563EB)),
              ),
              title: const Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Capture live issue with camera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.purple.shade50, shape: BoxShape.circle),
                child: const Icon(LucideIcons.image, color: Colors.purple),
              ),
              title: const Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Select existing photo from files'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final style = kCategoryStyles[_category]!;
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
              EmbossedCategoryIcon(
                category: _category,
                size: 48,
                iconSize: 24,
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
          const SizedBox(height: 20),
          // Category selector chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: IssueCategory.values.map((cat) {
                final catStyle = kCategoryStyles[cat]!;
                final isSelected = _category == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _category = cat;
                        _selectedSubcategory = null;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: catStyle.gradientColors.isNotEmpty
                                    ? catStyle.gradientColors
                                    : [catStyle.color, catStyle.color],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              )
                            : null,
                        color: isSelected ? null : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected ? Colors.white.withValues(alpha: 0.45) : Colors.grey.shade300,
                          width: 1.5,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.35),
                                  offset: const Offset(0, -1),
                                  blurRadius: 1.5,
                                ),
                              ]
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            catStyle.icon,
                            size: 16,
                            color: isSelected ? Colors.white : Colors.grey.shade700,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            catStyle.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected ? Colors.white : Colors.grey.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),
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
            items: kSubcategories[_category]!.map((String value) {
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
          // Attached photo preview or Add photo button
          if (_imageBytes != null || (_imagePath != null && _imagePath!.isNotEmpty))
            Container(
              height: 160,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.grey.shade100,
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: _imageBytes != null
                        ? Image.memory(_imageBytes!, fit: BoxFit.cover)
                        : (_imagePath!.startsWith('http') || _imagePath!.startsWith('blob:')
                            ? Image.network(_imagePath!, fit: BoxFit.cover)
                            : const Center(child: Icon(LucideIcons.image, size: 40, color: Colors.grey))),
                  ),
                  // Top gradient shadow
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 50,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        gradient: LinearGradient(
                          colors: [Colors.black.withOpacity(0.55), Colors.transparent],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ),
                  // "Photo Attached" badge
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.camera, color: Colors.white, size: 13),
                          SizedBox(width: 5),
                          Text('Photo Attached', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                  // Action buttons: Retake & Remove
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: _showImageSourceDialog,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 4)],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.refreshCw, size: 12, color: Color(0xFF2563EB)),
                                SizedBox(width: 4),
                                Text('Retake', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF2563EB))),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => setState(() {
                            _imageBytes = null;
                            _imagePath = null;
                          }),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
                            ),
                            child: const Icon(LucideIcons.trash2, size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: _isProcessingImage ? null : _showImageSourceDialog,
              icon: _isProcessingImage
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(LucideIcons.camera, size: 20, color: Color(0xFF2563EB)),
              label: const Text('Add Photo (Optional)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF2563EB))),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                side: BorderSide(color: Colors.blue.shade200, width: 1.5),
                backgroundColor: Colors.blue.shade50.withOpacity(0.5),
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
                            category: _category,
                            title: _selectedSubcategory == 'Other' ? _customTitleController.text.trim() : _selectedSubcategory!,
                            description: _descController.text.trim(),
                            imagePath: _imagePath,
                            imageBytes: _imageBytes,
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

/// Fluid search bar header that organically merges the circular back button with the search pill
/// when focused, and splits them apart with fluid spring physics when search is exited.
class FluidMergeSearchBar extends StatefulWidget {
  final FocusNode focusNode;
  final TextEditingController controller;
  final bool isSearching;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onBack;
  final VoidCallback onCancelSearch;
  final VoidCallback onClearText;

  const FluidMergeSearchBar({
    super.key,
    required this.focusNode,
    required this.controller,
    required this.isSearching,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onBack,
    required this.onCancelSearch,
    required this.onClearText,
  });

  @override
  State<FluidMergeSearchBar> createState() => _FluidMergeSearchBarState();
}

class _FluidMergeSearchBarState extends State<FluidMergeSearchBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _focusAnimController;
  late final Animation<double> _focusCurve;
  bool _isBackPressed = false;

  @override
  void initState() {
    super.initState();
    _focusAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      reverseDuration: const Duration(milliseconds: 220),
    );

    _focusCurve = CurvedAnimation(
      parent: _focusAnimController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    if (widget.focusNode.hasFocus) {
      _focusAnimController.value = 1.0;
    }

    widget.controller.addListener(_onTextChange);
    widget.focusNode.addListener(_onFocusChange);
  }

  void _onTextChange() {
    if (mounted) setState(() {});
  }

  void _onFocusChange() {
    if (widget.focusNode.hasFocus) {
      _focusAnimController.forward();
    } else {
      _focusAnimController.reverse();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusAnimController.dispose();
    widget.controller.removeListener(_onTextChange);
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const totalHeight = 50.0;

    final defaultShadows = [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        blurRadius: 16,
        offset: const Offset(0, 4),
      ),
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.03),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ];

    return SizedBox(
      height: totalHeight,
      child: Row(
        children: [
          // 1. Clean Circular Back Button with tactile spring feedback
          GestureDetector(
            onTapDown: (_) => setState(() => _isBackPressed = true),
            onTapUp: (_) => setState(() => _isBackPressed = false),
            onTapCancel: () => setState(() => _isBackPressed = false),
            onTap: () {
              if (widget.focusNode.hasFocus) {
                widget.onCancelSearch();
              } else {
                widget.onBack();
              }
            },
            child: AnimatedScale(
              scale: _isBackPressed ? 0.92 : 1.0,
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.0,
                  ),
                  boxShadow: defaultShadows,
                ),
                child: Center(
                  child: Icon(
                    LucideIcons.arrowLeft,
                    color: Colors.grey.shade800,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // 2. Animated Search Pill with Fluid Blue Bloom Glow & Micro-Lift
          Expanded(
            child: AnimatedBuilder(
              animation: _focusCurve,
              builder: (context, _) {
                final t = _focusCurve.value;
                final borderColor = Color.lerp(
                  const Color(0xFFE2E8F0),
                  const Color(0xFF2563EB),
                  t,
                )!;
                final borderWidth = lerpDouble(1.0, 1.8, t)!;
                final iconColor = Color.lerp(
                  const Color(0xFF64748B),
                  const Color(0xFF2563EB),
                  t,
                )!;
                final iconScale = lerpDouble(1.0, 1.10, t)!;
                final iconRotation = lerpDouble(0.0, -0.06, t)!;
                final translateY = lerpDouble(0.0, -1.0, t)!;

                final searchShadows = <BoxShadow>[
                  // Blooming luminous electric blue aura
                  if (t > 0.005)
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.24 * t),
                      blurRadius: lerpDouble(4, 16, t)!,
                      spreadRadius: lerpDouble(0, 2.5, t)!,
                      offset: Offset.zero,
                    ),
                  if (t > 0.005)
                    BoxShadow(
                      color: const Color(0xFF60A5FA).withValues(alpha: 0.12 * t),
                      blurRadius: lerpDouble(2, 6, t)!,
                      spreadRadius: lerpDouble(0, 1.0, t)!,
                      offset: Offset.zero,
                    ),
                  // Ambient baseline drop shadow
                  BoxShadow(
                    color: Colors.black.withValues(alpha: lerpDouble(0.06, 0.09, t)!),
                    blurRadius: lerpDouble(14, 20, t)!,
                    offset: Offset(0, lerpDouble(3, 5, t)!),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ];

                return Transform.translate(
                  offset: Offset(0, translateY),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25.0),
                      border: Border.all(
                        color: borderColor,
                        width: borderWidth,
                      ),
                      boxShadow: searchShadows,
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        Transform.rotate(
                          angle: iconRotation,
                          child: Transform.scale(
                            scale: iconScale,
                            child: Icon(
                              LucideIcons.search,
                              color: iconColor,
                              size: 19,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            focusNode: widget.focusNode,
                            controller: widget.controller,
                            onChanged: widget.onSearchChanged,
                            onSubmitted: widget.onSearchSubmitted,
                            textAlign: TextAlign.left,
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                              letterSpacing: 0.2,
                            ),
                            decoration: const InputDecoration(
                              isDense: true,
                              hintText: 'Search location...',
                              hintStyle: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 14.5,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        if (widget.isSearching)
                          const Padding(
                            padding: EdgeInsets.only(right: 14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2.0),
                            ),
                          )
                        else
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            transitionBuilder: (child, anim) => ScaleTransition(
                              scale: anim,
                              child: FadeTransition(opacity: anim, child: child),
                            ),
                            child: widget.controller.text.isNotEmpty
                                ? IconButton(
                                    key: const ValueKey('clear_btn'),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 40, minHeight: 50),
                                    icon: Icon(LucideIcons.x, size: 18, color: Colors.grey.shade600),
                                    onPressed: widget.onClearText,
                                  )
                                : const SizedBox(
                                    key: ValueKey('empty_suffix'),
                                    width: 14,
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
    );
  }
}

