import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../models/heatmap_zone.dart';
import '../../services/heatmap_service.dart';
import '../interactive_map/map_screen.dart';

class HeatmapScreen extends StatefulWidget {
  final Map<String, dynamic>? citizenProfile;

  const HeatmapScreen({super.key, this.citizenProfile});

  @override
  State<HeatmapScreen> createState() => _HeatmapScreenState();
}

class _HeatmapScreenState extends State<HeatmapScreen> {
  final HeatmapService _heatmapService = HeatmapService();
  final MapController _mapController = MapController();

  static const LatLng _defaultCenter = LatLng(19.0760, 72.8777); // Mumbai
  LatLng _mapCenter = _defaultCenter;

  List<HeatmapZone> _allZones = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Filters
  String _selectedCategoryGroup = 'all'; // 'all', 'civic', 'safety', 'missing'
  String _selectedSeverity = 'ALL'; // 'ALL', 'HIGH', 'MEDIUM', 'LOW'
  String _selectedTimeRange = 'all'; // 'all', '30d', '7d'

  HeatmapZone? _selectedZone;

  @override
  void initState() {
    super.initState();
    _loadHeatmapData();
  }

  Future<void> _loadHeatmapData({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final zones = await _heatmapService.fetchCitizenHeatmap(
        timeRange: _selectedTimeRange,
        forceRefresh: forceRefresh,
      );

      if (!mounted) return;
      setState(() {
        _allZones = zones;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load heatmap: $e';
        _isLoading = false;
      });
    }
  }

  // Filtered zones based on active selections
  List<HeatmapZone> get _filteredZones {
    return _allZones.where((zone) {
      // Category group filter
      if (_selectedCategoryGroup != 'all') {
        if (_selectedCategoryGroup == 'civic' &&
            zone.categoryGroup != HotspotCategoryGroup.civic) {
          return false;
        }
        if (_selectedCategoryGroup == 'safety' &&
            zone.categoryGroup != HotspotCategoryGroup.safety) {
          return false;
        }
        if (_selectedCategoryGroup == 'missing' &&
            zone.categoryGroup != HotspotCategoryGroup.missingPerson) {
          return false;
        }
      }

      // Severity filter
      if (_selectedSeverity != 'ALL' && zone.severityLabel != _selectedSeverity) {
        return false;
      }

      return true;
    }).toList();
  }

  Color _getHotspotColor(HeatmapZone zone) {
    if (zone.categoryGroup == HotspotCategoryGroup.missingPerson) {
      return const Color(0xFF7C3AED); // Purple for Missing Persons
    }
    switch (zone.severity) {
      case HotspotSeverity.low:
        return const Color(0xFF10B981); // Emerald
      case HotspotSeverity.medium:
        return const Color(0xFFD97706); // Amber
      case HotspotSeverity.high:
        return const Color(0xFFDC2626); // Crimson
    }
  }

  Future<void> _centerOnMyLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      final myPos = LatLng(position.latitude, position.longitude);
      _mapController.move(myPos, 14.0);
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not determine current GPS position.')),
      );
    }
  }

  void _onZoneTapped(HeatmapZone zone) {
    setState(() => _selectedZone = zone);
    _mapController.move(zone.center, 14.5);
    _showHotspotDetailsModal(zone);
  }

  void _showHotspotDetailsModal(HeatmapZone zone) {
    final color = _getHotspotColor(zone);
    final isMissing = zone.categoryGroup == HotspotCategoryGroup.missingPerson;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, -4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Title & Severity Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withAlpha(30),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isMissing
                              ? Icons.person_search_rounded
                              : zone.categoryGroup == HotspotCategoryGroup.safety
                                  ? Icons.shield_rounded
                                  : Icons.location_city_rounded,
                          color: color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isMissing ? 'Missing Person Area' : '${zone.zoneType.toUpperCase()} HOTSPOT',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            Text(
                              zone.categoryGroupLabel,
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    zone.severityLabel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // Hotspot Metrics Grid
            Row(
              children: [
                _buildModalStat(
                  icon: Icons.pie_chart_rounded,
                  label: 'Risk Score',
                  value: '${zone.riskScore.toStringAsFixed(0)} / 100',
                  color: color,
                ),
                _buildModalStat(
                  icon: Icons.report_problem_rounded,
                  label: isMissing ? 'Active Case' : 'Reports',
                  value: '${zone.complaintCount} ${zone.complaintCount == 1 ? 'incident' : 'incidents'}',
                  color: Colors.blueGrey.shade800,
                ),
                _buildModalStat(
                  icon: Icons.radar_rounded,
                  label: 'Radius',
                  value: '${zone.radiusMeters.toStringAsFixed(0)} m',
                  color: Colors.blueGrey.shade800,
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Privacy and Information Notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueGrey.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blueGrey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.privacy_tip_outlined, size: 20, color: Colors.blueGrey.shade700),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isMissing
                          ? 'Public assistance zone for missing person verification. Citizen identities are protected.'
                          : 'Civic & hazard aggregate cluster. Exact reporter contact details are anonymized.',
                      style: TextStyle(fontSize: 11, color: Colors.blueGrey.shade800),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action: Report Issue in this Area
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_location_alt_outlined, size: 20),
                label: const Text(
                  'Report Incident in this Area',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const InteractiveMapScreen(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildModalStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showLegendDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.layers_outlined, color: Colors.deepPurple),
            SizedBox(width: 8),
            Text('Heatmap Guide & Legend', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLegendRow(const Color(0xFF10B981), 'LOW SEVERITY', 'Minor issues, mostly resolved or low activity.'),
            const SizedBox(height: 8),
            _buildLegendRow(const Color(0xFFD97706), 'MEDIUM SEVERITY', 'Moderate density of pending reports.'),
            const SizedBox(height: 8),
            _buildLegendRow(const Color(0xFFDC2626), 'HIGH RISK', 'Critical report density requiring urgent civic response.'),
            const SizedBox(height: 8),
            _buildLegendRow(const Color(0xFF7C3AED), 'MISSING PERSON', 'Active public search report area.'),
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 6),
            const Text(
              'Concentric Circles: The 4 concentric gradient layers visualize radial complaint density from the core to the perimeter.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendRow(Color color, String label, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
              Text(desc, style: const TextStyle(fontSize: 11, color: Colors.black87)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredZones;
    final totalReports = filtered.fold<int>(0, (sum, z) => sum + z.complaintCount);
    final highRiskCount = filtered.where((z) => z.severity == HotspotSeverity.high).length;

    // Build Concentric Circles for each zone (Outer 100%, Mid-Outer 72%, Mid-Inner 45%, Core 20%)
    final List<CircleMarker> circleMarkers = [];

    for (final zone in filtered) {
      final color = _getHotspotColor(zone);
      final isSelected = _selectedZone?.id == zone.id;
      final baseRadius = zone.radiusMeters;

      // Layer 1: Outer Fading Ring (100% radius)
      circleMarkers.add(
        CircleMarker(
          point: zone.center,
          radius: baseRadius,
          useRadiusInMeter: true,
          color: color.withAlpha(isSelected ? 65 : 35),
          borderColor: isSelected ? const Color(0xFF0B192C) : color,
          borderStrokeWidth: isSelected ? 2.5 : 1.0,
        ),
      );

      // Layer 2: Mid-Outer Ring (72% radius)
      circleMarkers.add(
        CircleMarker(
          point: zone.center,
          radius: baseRadius * 0.72,
          useRadiusInMeter: true,
          color: color.withAlpha(isSelected ? 100 : 60),
          borderColor: Colors.transparent,
          borderStrokeWidth: 0,
        ),
      );

      // Layer 3: Mid-Inner Ring (45% radius)
      circleMarkers.add(
        CircleMarker(
          point: zone.center,
          radius: baseRadius * 0.45,
          useRadiusInMeter: true,
          color: color.withAlpha(isSelected ? 150 : 100),
          borderColor: Colors.transparent,
          borderStrokeWidth: 0,
        ),
      );

      // Layer 4: Concentrated Core Ring (20% radius)
      circleMarkers.add(
        CircleMarker(
          point: zone.center,
          radius: baseRadius * 0.20,
          useRadiusInMeter: true,
          color: color.withAlpha(isSelected ? 230 : 180),
          borderColor: Colors.transparent,
          borderStrokeWidth: 0,
        ),
      );
    }

    // Build clickable center markers
    final List<Marker> centerMarkers = filtered.map((zone) {
      final color = _getHotspotColor(zone);
      final isMissing = zone.categoryGroup == HotspotCategoryGroup.missingPerson;

      return Marker(
        point: zone.center,
        width: 38,
        height: 38,
        child: GestureDetector(
          onTap: () => _onZoneTapped(zone),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withAlpha(120), blurRadius: 6, spreadRadius: 2),
              ],
              border: Border.all(color: color, width: 2.5),
            ),
            child: Center(
              child: isMissing
                  ? const Icon(Icons.person, size: 18, color: Color(0xFF7C3AED))
                  : Text(
                      '${zone.complaintCount}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
            ),
          ),
        ),
      );
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.whatshot, color: Colors.deepOrange),
            SizedBox(width: 8),
            Text(
              'Safety & Civic Heatmap',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            tooltip: 'Heatmap Legend',
            onPressed: _showLegendDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => _loadHeatmapData(forceRefresh: true),
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. OpenStreetMap Tile Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 12.0,
              minZoom: 4.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.unisafe.app',
              ),
              CircleLayer(circles: circleMarkers),
              MarkerLayer(markers: centerMarkers),
            ],
          ),

          // 2. Top Filter Controls Overlay
          Positioned(
            top: 10,
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Category Pills
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All Issues', 'all', _selectedCategoryGroup, (v) {
                        setState(() => _selectedCategoryGroup = v);
                      }),
                      const SizedBox(width: 6),
                      _buildFilterChip('Civic', 'civic', _selectedCategoryGroup, (v) {
                        setState(() => _selectedCategoryGroup = v);
                      }),
                      const SizedBox(width: 6),
                      _buildFilterChip('Public Safety', 'safety', _selectedCategoryGroup, (v) {
                        setState(() => _selectedCategoryGroup = v);
                      }),
                      const SizedBox(width: 6),
                      _buildFilterChip('Missing Persons', 'missing', _selectedCategoryGroup, (v) {
                        setState(() => _selectedCategoryGroup = v);
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 6),

                // Secondary Severity and Time Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(240),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Severity Pills
                      Row(
                        children: [
                          const Text('Severity: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          _buildSeverityChip('All', 'ALL'),
                          _buildSeverityChip('High', 'HIGH'),
                          _buildSeverityChip('Med', 'MEDIUM'),
                          _buildSeverityChip('Low', 'LOW'),
                        ],
                      ),

                      // Time range
                      DropdownButton<String>(
                        value: _selectedTimeRange,
                        isDense: true,
                        underline: const SizedBox(),
                        style: const TextStyle(fontSize: 11, color: Colors.black87, fontWeight: FontWeight.bold),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Time')),
                          DropdownMenuItem(value: '30d', child: Text('Past 30d')),
                          DropdownMenuItem(value: '7d', child: Text('Past 7d')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedTimeRange = val);
                            _loadHeatmapData(forceRefresh: true);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // 3. Bottom Stats Summary Bar
          Positioned(
            bottom: 24,
            left: 14,
            right: 76, // leave room for floating buttons
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withAlpha(235),
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem('Hotspots', '${filtered.length}', Colors.amber),
                  _buildSummaryItem('High Risk', '$highRiskCount', Colors.redAccent),
                  _buildSummaryItem('Reports', '$totalReports', Colors.lightBlueAccent),
                ],
              ),
            ),
          ),

          // 4. Floating Map Buttons (GPS & Report)
          Positioned(
            bottom: 24,
            right: 14,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'heatmap_gps',
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.teal.shade800,
                  tooltip: 'My Location',
                  onPressed: _centerOnMyLocation,
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'heatmap_report',
                  backgroundColor: const Color(0xFFE11D48),
                  foregroundColor: Colors.white,
                  tooltip: 'Report Issue',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const InteractiveMapScreen(),
                      ),
                    );
                  },
                  child: const Icon(Icons.add_alert_rounded),
                ),
              ],
            ),
          ),

          // Loading indicator
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black26,
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),

          // Error display
          if (_errorMessage != null)
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    String value,
    String current,
    ValueChanged<String> onSelected,
  ) {
    final isSelected = current == value;
    return GestureDetector(
      onTap: () => onSelected(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0F172A) : Colors.white.withAlpha(240),
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }

  Widget _buildSeverityChip(String label, String value) {
    final isSelected = _selectedSeverity == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedSeverity = value),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E293B) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.white70)),
      ],
    );
  }
}
