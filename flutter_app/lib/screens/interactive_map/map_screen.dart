import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
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
    title: 'Streets',
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
    style: MapStyle.cleanLight,
    title: 'Humanitarian',
    subtitle: 'High-contrast OSM (Clean & Keyless)',
    urlTemplate: 'https://a.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
    icon: LucideIcons.heartHandshake,
    previewColor: Color(0xFFF4F4F5),
    maxNativeZoom: 19,
  ),
  MapStyleOption(
    style: MapStyle.outdoor,
    title: 'Outdoor / Topo',
    subtitle: 'OpenTopoMap',
    urlTemplate: 'https://tile.opentopomap.org/{z}/{x}/{y}.png',
    icon: LucideIcons.mountain,
    previewColor: Color(0xFFD1FAE5),
    maxNativeZoom: 17,
  ),
];

enum MapOverlayType {
  hybridLabels,
  transit,
  footpaths,
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
    type: MapOverlayType.hybridLabels,
    title: 'Street Names & Places',
    subtitle: 'Overlays roads and labels on Satellite (Hybrid)',
    urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
    icon: LucideIcons.tags,
    activeColor: Color(0xFF2563EB),
  ),
  MapOverlayOption(
    type: MapOverlayType.transit,
    title: 'Metro & Railway Lines',
    subtitle: 'OpenRailwayMap train, tram & metro tracks',
    urlTemplate: 'https://{s}.tiles.openrailwaymap.org/standard/{z}/{x}/{y}.png',
    subdomains: ['a', 'b', 'c'],
    icon: LucideIcons.train,
    activeColor: Color(0xFFEA580C),
  ),
  MapOverlayOption(
    type: MapOverlayType.footpaths,
    title: 'Walking Trails & Footpaths',
    subtitle: 'Waymarked pedestrian routes and paths',
    urlTemplate: 'https://tile.waymarkedtrails.org/hiking/{z}/{x}/{y}.png',
    icon: LucideIcons.footprints,
    activeColor: Color(0xFF16A34A),
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
  const InteractiveMapScreen({super.key});
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
              initialCenter: const LatLng(28.6139, 77.2090),
              initialZoom: 14.0,
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
                    // Search Bar
                    Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 350),
                          curve: Curves.easeOutCubic,
                          width: _searchFocusNode.hasFocus ? 0 : 52, // 44 width + 8 padding
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const NeverScrollableScrollPhysics(),
                            reverse: true, // Aligns to the right, creating a slide-out effect
                            child: SizedBox(
                              width: 52,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 8.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(22),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                    child: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.8),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.0),
                                        boxShadow: [
                                          BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 6)),
                                        ],
                                      ),
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                                        icon: Icon(LucideIcons.arrowLeft, color: Colors.grey.shade800, size: 21),
                                        onPressed: _handleBackNavigation,
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
                            borderRadius: BorderRadius.circular(44),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.75),
                                  borderRadius: BorderRadius.circular(44),
                                  border: Border.all(color: Colors.white.withOpacity(0.85), width: 1.2),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 20, offset: const Offset(0, 6)),
                                  ],
                                ),
                                child: TextField(
                                  focusNode: _searchFocusNode,
                                  controller: _searchController,
                                  onChanged: _onSearchChanged,
                                  textAlignVertical: TextAlignVertical.center,
                                  style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1A202C),
                                    height: 1.2,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    hintText: 'Search anywhere...',
                                    hintStyle: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w500,
                                      height: 1.2,
                                    ),
                                    prefixIcon: const Padding(
                                      padding: EdgeInsets.only(left: 14.0, right: 8.0),
                                      child: Icon(LucideIcons.search, color: Color(0xFF64748B), size: 20),
                                    ),
                                    prefixIconConstraints: const BoxConstraints(minWidth: 42, minHeight: 44),
                                    suffixIcon: _isSearching
                                        ? const Padding(
                                            padding: EdgeInsets.all(12.0),
                                            child: SizedBox(
                                              width: 18,
                                              height: 18,
                                              child: CircularProgressIndicator(strokeWidth: 2.0),
                                            ),
                                          )
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (_searchController.text.isNotEmpty)
                                                IconButton(
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(minWidth: 34, minHeight: 44),
                                                  icon: Icon(LucideIcons.x, size: 18, color: Colors.grey.shade600),
                                                  onPressed: () {
                                                    _searchController.clear();
                                                    setState(() => _suggestions = []);
                                                  },
                                                ),
                                            ],
                                          ),
                                    suffixIconConstraints: const BoxConstraints(minWidth: 38, minHeight: 44),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                                  ),
                                  onSubmitted: _searchLocation,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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
                              if (reports.isEmpty && _suggestions.isEmpty)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4.5),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.55),
                                    borderRadius: BorderRadius.circular(14),
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
                              ClipRRect(
                                borderRadius: BorderRadius.circular(36),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.88),
                                      borderRadius: BorderRadius.circular(36),
                                      border: Border.all(color: Colors.white.withOpacity(0.6), width: 1.0),
                                      boxShadow: [
                                        BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 30, offset: const Offset(0, 10)),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        for (var category in IssueCategory.values)
                                          Expanded(
                                            child: _buildCategoryButton(category),
                                          ),
                                      ],
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
                                _MapActionButton(
                                  icon: LucideIcons.layers,
                                  tooltip: 'Map Style',
                                  onTap: _showMapStyleDialog,
                                  size: 54,
                                ),
                                const SizedBox(height: 12),
                                _MapActionButton(
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
    );
  }

  Widget _buildPendingActionPanel() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 30,
                offset: const Offset(0, 10),
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
        ),
      ),
    );
  }

  Widget _buildEditingActionPanel() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 30,
                offset: const Offset(0, 10),
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
        ),
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
                      : (imagePath != null && (imagePath.startsWith('http') || imagePath.startsWith('blob:'))
                          ? Image.network(imagePath, fit: BoxFit.contain)
                          : const Icon(LucideIcons.image, size: 80, color: Colors.white54)),
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
                            Text(style.label, style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
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
                                  : (report.imagePath!.startsWith('http') || report.imagePath!.startsWith('blob:')
                                      ? Image.network(report.imagePath!, fit: BoxFit.cover)
                                      : const Center(child: Icon(LucideIcons.image, size: 40, color: Colors.grey))),
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
                  
                  const SizedBox(height: 20),
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

  void _showMapStyleDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(LucideIcons.layers, color: Colors.indigo.shade600, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Layers & Overlays', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A))),
                        Text('Choose base style and active overlays', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420, maxHeight: 480),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section 1: Base Map
                      Row(
                        children: [
                          Icon(LucideIcons.map, size: 14, color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            'BASE MAP',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Select 1',
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade400, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...kMapStyles.map((option) {
                        final isSelected = _selectedMapStyle == option.style;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: InkWell(
                            onTap: () {
                              setDialogState(() {
                                _selectedMapStyle = option.style;
                              });
                              setState(() {});
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.indigo.shade50.withValues(alpha: 0.7) : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? Colors.indigo.shade600 : Colors.grey.shade200,
                                  width: isSelected ? 1.8 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: option.previewColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
                                    ),
                                    child: Icon(
                                      option.icon,
                                      color: option.style == MapStyle.darkMode || option.style == MapStyle.satellite
                                          ? Colors.white
                                          : Colors.grey.shade800,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          option.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13.5,
                                            color: isSelected ? Colors.indigo.shade900 : const Color(0xFF1E293B),
                                          ),
                                        ),
                                        Text(
                                          option.subtitle,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                                    color: isSelected ? Colors.indigo.shade600 : Colors.grey.shade400,
                                    size: 19,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(height: 10),
                      Divider(color: Colors.grey.shade200, height: 1),
                      const SizedBox(height: 10),
                      // Section 2: Overlays
                      Row(
                        children: [
                          Icon(LucideIcons.layers, size: 14, color: Colors.blue.shade600),
                          const SizedBox(width: 6),
                          Text(
                            'MAP OVERLAYS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              color: Colors.blue.shade800,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: _activeOverlays.isNotEmpty ? Colors.blue.shade50 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${_activeOverlays.length} active',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: _activeOverlays.isNotEmpty ? Colors.blue.shade700 : Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Stacked transparently on top of any base map',
                        style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 8),
                      ...kMapOverlays.map((overlay) {
                        final isOverlayActive = _activeOverlays.contains(overlay.type);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: InkWell(
                            onTap: () {
                              setDialogState(() {
                                if (isOverlayActive) {
                                  _activeOverlays.remove(overlay.type);
                                } else {
                                  _activeOverlays.add(overlay.type);
                                }
                              });
                              setState(() {});
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isOverlayActive ? overlay.activeColor.withValues(alpha: 0.08) : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isOverlayActive ? overlay.activeColor : Colors.grey.shade200,
                                  width: isOverlayActive ? 1.8 : 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: isOverlayActive ? overlay.activeColor : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      overlay.icon,
                                      color: isOverlayActive ? Colors.white : Colors.grey.shade600,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          overlay.title,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                            color: isOverlayActive ? Colors.grey.shade900 : Colors.grey.shade700,
                                          ),
                                        ),
                                        Text(
                                          overlay.subtitle,
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: Colors.grey.shade500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Transform.scale(
                                    scale: 0.82,
                                    child: Switch(
                                      value: isOverlayActive,
                                      activeColor: overlay.activeColor,
                                      onChanged: (val) {
                                        setDialogState(() {
                                          if (val) {
                                            _activeOverlays.add(overlay.type);
                                          } else {
                                            _activeOverlays.remove(overlay.type);
                                          }
                                        });
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(20, 6, 20, 16),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Done', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
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
          final double p = _controller.value;

          return Transform.scale(
            scale: scale,
            child: Transform.translate(
              offset: Offset(0, depth),
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  color: Color.lerp(Colors.white, const Color(0xFFF1F5F9), p),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12 - (p * 0.04)),
                      offset: Offset(0, 4.0 - (p * 2.5)),
                      blurRadius: 10.0 - (p * 6.0),
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
  final bool hasBadge;
  final bool isLoading;
  final double size;

  const _MapActionButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.hasBadge = false,
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

                      // 4. Active Notification Badge (for Filter button)
                      if (widget.hasBadge)
                        Positioned(
                          top: 3,
                          right: 3,
                          child: Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
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

  const EmbossedCategoryButton({
    super.key,
    required this.category,
    required this.onTap,
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
