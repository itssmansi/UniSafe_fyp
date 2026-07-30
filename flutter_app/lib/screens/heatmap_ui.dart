import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/report_model.dart';
import '../providers/report_provider.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  LatLng? _droppedLocation;
  IssueCategory? _selectedCategory;
  bool _isSearching = false;
  
  Timer? _debounce;
  List<dynamic> _suggestions = [];
  LatLng? _myLocation;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.isEmpty) {
        if (mounted) setState(() => _suggestions = []);
        return;
      }
      try {
        final response = await http.get(Uri.parse(
            'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5'));
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
    // Zoomed in closer for better visibility
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
      final response = await http.get(Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1'));
          
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
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services are disabled.')));
      return;
    }

    permission = await Geolocator.checkPermission();
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

    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fetching location...')));
    
    try {
      // Use LocationAccuracy.high for better precision
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final latLng = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _myLocation = latLng;
      });
      
      // Move camera with a very close zoom level (17.0)
      _mapController.move(latLng, 17.0); 
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to get location')));
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
              onAcceptWithDetails: (details) {
                try {
                   final latLng = _mapController.camera.center;
                   setState(() {
                     _droppedLocation = latLng;
                     _selectedCategory = details.data;
                   });
                } catch (e) {
                   debugPrint("Error dropping pin: $e");
                }
              },
              builder: (context, candidateData, rejectedData) {
                return FlutterMap(
                  mapController: _mapController,
                  options: const MapOptions(
                    initialCenter: LatLng(28.6139, 77.2090),
                    initialZoom: 13.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.unisafe.app',
                    ),
                    MarkerLayer(
                      markers: [
                        // Display user's location
                        if (_myLocation != null)
                          Marker(
                            point: _myLocation!,
                            width: 24,
                            height: 24,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                            ),
                          ),
                        // Display submitted reports
                        ...reports.map((r) => Marker(
                              point: r.location,
                              width: 40,
                              height: 40,
                              child: _buildPinIcon(r.category),
                            )),
                        // Display currently dropped pin
                        if (_droppedLocation != null && _selectedCategory != null)
                          Marker(
                            point: _droppedLocation!,
                            width: 40,
                            height: 40,
                            child: _buildPinIcon(_selectedCategory!),
                          ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search Bar
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        decoration: InputDecoration(
                          hintText: 'Search location...',
                          prefixIcon: const Icon(LucideIcons.search),
                          suffixIcon: _isSearching 
                            ? const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : IconButton(
                                icon: const Icon(LucideIcons.arrowRight),
                                onPressed: () => _searchLocation(_searchController.text),
                              ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                        onSubmitted: _searchLocation,
                      ),
                    ),
                    
                    // Suggestions List
                    if (_suggestions.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        constraints: const BoxConstraints(maxHeight: 250),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: const [
                            BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)
                          ],
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _suggestions.length,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final suggestion = _suggestions[index];
                            return ListTile(
                              leading: const Icon(LucideIcons.mapPin, color: Colors.grey),
                              title: Text(
                                suggestion['display_name'],
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14),
                              ),
                              onTap: () => _selectSuggestion(suggestion),
                            );
                          },
                        ),
                      ),
                    
                    // Pin Categories
                    if (_suggestions.isEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildDraggablePin(IssueCategory.infrastructure, LucideIcons.building, Colors.orange),
                            const SizedBox(width: 16),
                            _buildDraggablePin(IssueCategory.flood, LucideIcons.waves, Colors.blue),
                            const SizedBox(width: 16),
                            _buildDraggablePin(IssueCategory.garbage, LucideIcons.trash2, Colors.brown),
                            const SizedBox(width: 16),
                            _buildDraggablePin(IssueCategory.other, LucideIcons.alertTriangle, Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          if (_droppedLocation != null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 32.0),
                child: ElevatedButton.icon(
                  onPressed: () => _showReportForm(context),
                  icon: const Icon(LucideIcons.check),
                  label: const Text('Confirm Location'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToMyLocation,
        backgroundColor: Colors.white,
        child: const Icon(LucideIcons.locate, color: Colors.blue),
      ),
    );
  }

  Widget _buildDraggablePin(IssueCategory category, IconData icon, Color color) {
    final pinWidget = CircleAvatar(
      backgroundColor: color,
      child: Icon(icon, color: Colors.white, size: 20),
    );

    return Draggable<IssueCategory>(
      data: category,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.8,
          child: pinWidget,
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: pinWidget,
      ),
      child: pinWidget,
    );
  }

  Widget _buildPinIcon(IssueCategory category) {
    IconData icon;
    Color color;
    switch (category) {
      case IssueCategory.infrastructure:
        icon = LucideIcons.building;
        color = Colors.orange;
        break;
      case IssueCategory.flood:
        icon = LucideIcons.waves;
        color = Colors.blue;
        break;
      case IssueCategory.garbage:
        icon = LucideIcons.trash2;
        color = Colors.brown;
        break;
      case IssueCategory.other:
        icon = LucideIcons.alertTriangle;
        color = Colors.grey;
    }
    return Icon(icon, color: color, size: 40);
  }

  void _showReportForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 24,
          ),
          child: ReportFormWidget(
            location: _droppedLocation!,
            category: _selectedCategory!,
            onSubmit: (report) {
              ref.read(reportProvider.notifier).addReport(report);
              setState(() {
                _droppedLocation = null;
                _selectedCategory = null;
              });
              Navigator.pop(context);
            },
          ),
        );
      },
    );
  }
}

class ReportFormWidget extends StatefulWidget {
  final LatLng location;
  final IssueCategory category;
  final Function(ReportModel) onSubmit;

  const ReportFormWidget({
    super.key,
    required this.location,
    required this.category,
    required this.onSubmit,
  });

  @override
  State<ReportFormWidget> createState() => _ReportFormWidgetState();
}

class _ReportFormWidgetState extends State<ReportFormWidget> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Report Issue',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(
            labelText: 'Title',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Description',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Image upload mocked for prototype')),
             );
          },
          icon: const Icon(LucideIcons.camera),
          label: const Text('Add Photo (Optional)'),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            if (_titleController.text.isNotEmpty && _descController.text.isNotEmpty) {
              final report = ReportModel(
                location: widget.location,
                category: widget.category,
                title: _titleController.text,
                description: _descController.text,
              );
              widget.onSubmit(report);
            }
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
          child: const Text('Submit Report'),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
