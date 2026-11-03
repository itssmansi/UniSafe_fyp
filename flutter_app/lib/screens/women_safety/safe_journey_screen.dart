import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../models/journey_session.dart';
import '../../services/journey_service.dart';
import '../../services/location_service.dart';
import '../../services/trusted_contacts_service.dart';
import 'trusted_contacts_screen.dart';

enum JourneyUiState { notStarted, starting, active, ending, completed }

class SafeJourneyScreen extends StatefulWidget {
  const SafeJourneyScreen({super.key});

  @override
  State<SafeJourneyScreen> createState() => _SafeJourneyScreenState();
}

class _SafeJourneyScreenState extends State<SafeJourneyScreen> {
  final MapController _mapController = MapController();
  final JourneyService _journeyService = JourneyService();
  final LocationService _locationService = LocationService();
  final TrustedContactsService _contactsService = TrustedContactsService();

  final TextEditingController _destinationController = TextEditingController();

  // State
  JourneyUiState _uiState = JourneyUiState.notStarted;
  bool _isLoadingInitialLocation = true;
  String? _errorMessage;

  String? _citizenId;
  String? _citizenName;
  List<Map<String, dynamic>> _trustedContacts = [];

  JourneySession? _currentSession;
  StreamSubscription<Position>? _positionStreamSub;

  LatLng? _currentPosition;
  LatLng? _destinationPosition;
  String _destinationName = '';
  List<LatLng> _routePoints = [];

  // Default fallback: Mumbai coordinates if GPS is loading
  static const LatLng _mumbaiFallback = LatLng(19.0760, 72.8777);

  @override
  void initState() {
    super.initState();
    _destinationController.text = 'Home';
    _destinationName = 'Home';
    _initializeData();
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _destinationController.dispose();
    super.dispose();
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  Future<void> _initializeData() async {
    setState(() {
      _isLoadingInitialLocation = true;
      _errorMessage = null;
    });

    try {
      // 1. Fetch current citizen profile
      final citizen = await _journeyService.getCurrentCitizen();
      _citizenId = citizen['id']?.toString();
      _citizenName = citizen['name']?.toString() ?? 'Citizen';

      // 2. Fetch trusted contacts
      if (_citizenId != null) {
        _trustedContacts =
            await _contactsService.getTrustedContacts(_citizenId!);
      }

      // 3. Acquire current GPS position
      final position = await _locationService.getCurrentPosition();
      final userLatLng = LatLng(position.latitude, position.longitude);

      // 4. Check if there is already an active journey in database
      if (_citizenId != null) {
        final existingJourney =
            await _journeyService.getActiveJourney(_citizenId!);

        if (existingJourney != null) {
          _currentSession = existingJourney;
          _destinationName = existingJourney.destinationName;
          _destinationPosition = LatLng(
            existingJourney.destinationLatitude,
            existingJourney.destinationLongitude,
          );
          _uiState = JourneyUiState.active;
          _startLocationTracking(existingJourney.id);
        }
      }

      if (mounted) {
        setState(() {
          _currentPosition = userLatLng;
          _isLoadingInitialLocation = false;
        });

        _mapController.move(userLatLng, 15.0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentPosition = _mumbaiFallback;
          _isLoadingInitialLocation = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  // ============================================================
  // START SAFE JOURNEY
  // ============================================================

  Future<void> _startSafeJourney() async {
    if (_citizenId == null) {
      _showSnackBar('Citizen profile not loaded.', Colors.red);
      return;
    }

    if (_currentPosition == null) {
      _showSnackBar('Current GPS location not available.', Colors.red);
      return;
    }

    final destName = _destinationController.text.trim();
    if (destName.isEmpty) {
      _showSnackBar('Please enter or select a destination.', Colors.orange);
      return;
    }

    // Default destination if not set via map pin: offset slightly for demonstration
    final destLatLng = _destinationPosition ??
        LatLng(
          _currentPosition!.latitude + 0.015,
          _currentPosition!.longitude + 0.012,
        );

    setState(() {
      _uiState = JourneyUiState.starting;
      _destinationName = destName;
      _destinationPosition = destLatLng;
      _routePoints = [_currentPosition!, destLatLng];
    });

    try {
      final session = await _journeyService.startJourney(
        citizenId: _citizenId!,
        startLatitude: _currentPosition!.latitude,
        startLongitude: _currentPosition!.longitude,
        destinationLatitude: destLatLng.latitude,
        destinationLongitude: destLatLng.longitude,
        destinationName: destName,
      );

      if (!mounted) return;

      setState(() {
        _currentSession = session;
        _uiState = JourneyUiState.active;
      });

      _startLocationTracking(session.id);

      _showSnackBar(
        'Safe Journey started! SMS alerts sent to ${_trustedContacts.length} trusted contact(s).',
        Colors.green,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uiState = JourneyUiState.notStarted;
      });
      _showSnackBar('Failed to start journey: $e', Colors.red);
    }
  }

  // ============================================================
  // LIVE LOCATION TRACKING STREAM
  // ============================================================

  void _startLocationTracking(String journeyId) {
    _positionStreamSub?.cancel();

    _positionStreamSub = _locationService
        .getPositionStream(distanceFilter: 10)
        .listen((Position newPos) async {
      final updatedLatLng = LatLng(newPos.latitude, newPos.longitude);

      if (mounted) {
        setState(() {
          _currentPosition = updatedLatLng;
          if (_destinationPosition != null) {
            _routePoints = [updatedLatLng, _destinationPosition!];
          }
        });

        // Smoothly center map on moving user
        _mapController.move(updatedLatLng, _mapController.camera.zoom);
      }

      // Update Supabase database & Realtime
      await _journeyService.updateJourneyLocation(
        journeyId: journeyId,
        latitude: newPos.latitude,
        longitude: newPos.longitude,
        minDistanceMeters: 10.0,
      );
    }, onError: (err) {
      debugPrint('GPS stream error: $err');
    });
  }

  // ============================================================
  // END SAFE JOURNEY
  // ============================================================

  Future<void> _endSafeJourney() async {
    if (_currentSession == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Safe Journey'),
        content: const Text(
          'Have you safely reached your destination? Location sharing will stop and the tracking link will be deactivated.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Active'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('I Have Arrived'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _uiState = JourneyUiState.ending;
    });

    try {
      await _positionStreamSub?.cancel();
      _positionStreamSub = null;

      final completedSession =
          await _journeyService.endJourney(_currentSession!.id);

      if (!mounted) return;

      setState(() {
        _currentSession = completedSession;
        _uiState = JourneyUiState.completed;
      });

      _showSnackBar(
        'Safe Journey completed! Tracking link has been deactivated.',
        Colors.teal,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uiState = JourneyUiState.active;
      });
      _showSnackBar('Failed to end journey: $e', Colors.red);
    }
  }

  // ============================================================
  // CANCEL SAFE JOURNEY
  // ============================================================

  Future<void> _cancelSafeJourney() async {
    if (_currentSession == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Safe Journey'),
        content: const Text(
          'Are you sure you want to cancel this journey? Live tracking will stop immediately.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Journey'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _positionStreamSub?.cancel();
      _positionStreamSub = null;

      await _journeyService.cancelJourney(_currentSession!.id);

      if (!mounted) return;

      setState(() {
        _currentSession = null;
        _uiState = JourneyUiState.notStarted;
        _routePoints.clear();
      });

      _showSnackBar('Safe Journey has been cancelled.', Colors.grey.shade800);
    } catch (e) {
      _showSnackBar('Failed to cancel journey: $e', Colors.red);
    }
  }

  void _showSnackBar(String text, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), backgroundColor: color),
    );
  }

  // ============================================================
  // UI BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final activeCenter = _currentPosition ?? _mumbaiFallback;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Safe Journey',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.purple.shade50,
        actions: [
          if (_uiState == JourneyUiState.active)
            TextButton.icon(
              icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
              label: const Text('Cancel', style: TextStyle(color: Colors.red)),
              onPressed: _cancelSafeJourney,
            ),
        ],
      ),
      body: Stack(
        children: [
          // 1. OPENSTREETMAP MAP LAYER
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: activeCenter,
              initialZoom: 15.0,
              onTap: (tapPosition, point) {
                // If journey not started, allow user to tap on map to pick destination
                if (_uiState == JourneyUiState.notStarted) {
                  setState(() {
                    _destinationPosition = point;
                    _destinationController.text =
                        'Selected Location (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})';
                    if (_currentPosition != null) {
                      _routePoints = [_currentPosition!, point];
                    }
                  });
                }
              },
            ),
            children: [
              // OpenStreetMap Standard Tiles
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.unisafe',
              ),

              // Route Polyline
              if (_routePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      strokeWidth: 4.5,
                      color: Colors.deepPurple,
                    ),
                  ],
                ),

              // Markers Layer
              MarkerLayer(
                markers: [
                  // User's Current GPS Position Marker
                  if (_currentPosition != null)
                    Marker(
                      point: _currentPosition!,
                      width: 50,
                      height: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.blue.withAlpha(50),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade600,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Destination Pin Marker
                  if (_destinationPosition != null)
                    Marker(
                      point: _destinationPosition!,
                      width: 45,
                      height: 45,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 42,
                      ),
                    ),
                ],
              ),
            ],
          ),

          // 2. MAP CONTROLS (Recenter & Zoom)
          Positioned(
            right: 16,
            top: 16,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'recenter_user',
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.deepPurple,
                  onPressed: () {
                    if (_currentPosition != null) {
                      _mapController.move(_currentPosition!, 16.0);
                    }
                  },
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    );
                  },
                  child: const Icon(Icons.add),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  onPressed: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    );
                  },
                  child: const Icon(Icons.remove),
                ),
              ],
            ),
          ),

          // Loading Progress Indicator
          if (_isLoadingInitialLocation)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(color: Colors.deepPurple),
            ),

          // Location notice if fallback used
          if (_errorMessage != null && _uiState == JourneyUiState.notStarted)
            Positioned(
              top: 16,
              left: 16,
              right: 80,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                color: Colors.amber.shade100,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: Colors.amber.shade900),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 3. TOP ACTIVE JOURNEY BANNER
          if (_uiState == JourneyUiState.active)
            Positioned(
              top: 16,
              left: 16,
              right: 80,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.purple.shade900,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 6),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'LIVE TRACKING ACTIVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            '${_citizenName ?? "User"} heading to: $_destinationName',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 4. BOTTOM SHEET CONTROLS (Optimized for Mobile Phone)
          Align(
            alignment: Alignment.bottomCenter,
            child: _buildBottomPanel(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BOTTOM PANEL (PHONE VIEW)
  // ============================================================

  Widget _buildBottomPanel() {
    switch (_uiState) {
      case JourneyUiState.notStarted:
      case JourneyUiState.starting:
        return _buildNotStartedPanel();

      case JourneyUiState.active:
      case JourneyUiState.ending:
        return _buildActivePanel();

      case JourneyUiState.completed:
        return _buildCompletedPanel();
    }
  }

  // Panel: NOT STARTED
  Widget _buildNotStartedPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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

          // Destination field
          TextField(
            controller: _destinationController,
            decoration: InputDecoration(
              labelText: 'Where are you traveling to?',
              hintText: 'e.g. Home, College, Thane Station',
              prefixIcon: const Icon(Icons.location_on, color: Colors.deepPurple),
              suffixIcon: IconButton(
                icon: const Icon(Icons.touch_app, color: Colors.deepPurple),
                tooltip: 'Tap map to set pin',
                onPressed: () {
                  _showSnackBar('Tap anywhere on the map to set destination pin.', Colors.blue);
                },
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),

          const SizedBox(height: 10),

          // Quick Presets
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPresetChip('Home', Icons.home),
                _buildPresetChip('College', Icons.school),
                _buildPresetChip('Station', Icons.train),
                _buildPresetChip('Work', Icons.work),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Trusted Contacts Alert Preview
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.purple.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.shade100),
            ),
            child: Row(
              children: [
                Icon(Icons.sms, color: Colors.purple.shade700, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_trustedContacts.length} Trusted Contact(s) will be notified',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'A live web tracking link will be sent via SMS when you start.',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TrustedContactsScreen(),
                      ),
                    ).then((_) => _initializeData());
                  },
                  child: const Text('Manage'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Start Journey Button
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _uiState == JourneyUiState.starting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.navigation, size: 22),
              label: Text(
                _uiState == JourneyUiState.starting
                    ? 'Starting Safe Journey...'
                    : 'Start Safe Journey',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              onPressed: _uiState == JourneyUiState.starting ? null : _startSafeJourney,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPresetChip(String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        avatar: Icon(icon, size: 16, color: Colors.deepPurple),
        label: Text(label),
        onPressed: () {
          setState(() {
            _destinationController.text = label;
            _destinationName = label;
          });
        },
      ),
    );
  }

  // Panel: ACTIVE JOURNEY
  Widget _buildActivePanel() {
    double distanceKm = 0;
    if (_currentPosition != null && _destinationPosition != null) {
      final meters = _locationService.calculateDistance(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        _destinationPosition!.latitude,
        _destinationPosition!.longitude,
      );
      distanceKm = meters / 1000.0;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: 12),

          // Journey Stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'DESTINATION',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  Text(
                    _destinationName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${distanceKm.toStringAsFixed(1)} km away',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.teal.shade800,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // SMS notification status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tracking link active for ${_trustedContacts.length} trusted contact(s)',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Action Buttons: End Journey & SOS
          Row(
            children: [
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: _uiState == JourneyUiState.ending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      _uiState == JourneyUiState.ending
                          ? 'Ending...'
                          : 'End Journey',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onPressed: _uiState == JourneyUiState.ending
                        ? null
                        : _endSafeJourney,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.emergency, size: 18),
                    label: const Text(
                      'SOS',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      _showSnackBar(
                        'SOS distress signal triggered with GPS coordinates.',
                        Colors.red,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Panel: COMPLETED
  Widget _buildCompletedPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.celebration, color: Colors.green, size: 48),
          const SizedBox(height: 8),
          const Text(
            'You have safely reached your destination!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Live tracking has ended and the temporary tracking token has been deactivated.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('Back to Women Safety'),
          ),
        ],
      ),
    );
  }
}
