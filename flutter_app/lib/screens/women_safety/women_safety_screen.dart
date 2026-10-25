import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../models/journey_session.dart';
import '../../services/journey_service.dart';
import '../../services/location_service.dart';
import '../../services/route_service.dart';
import '../../services/saved_destination_service.dart';
import '../../services/sos_service.dart';
import '../../services/trusted_contacts_service.dart';
import 'trusted_contacts_screen.dart';

class WomenSafetyScreen extends StatefulWidget {
  const WomenSafetyScreen({super.key});

  @override
  State<WomenSafetyScreen> createState() => _WomenSafetyScreenState();
}

class _WomenSafetyScreenState extends State<WomenSafetyScreen> {
  // Services
  final JourneyService _journeyService = JourneyService();
  final LocationService _locationService = LocationService();
  final RouteService _routeService = RouteService();
  final SavedDestinationService _savedDestService = SavedDestinationService();
  final SosService _sosService = SosService();
  final TrustedContactsService _contactsService = TrustedContactsService();

  // Map Controller
  final MapController _mapController = MapController();

  // State
  String? _citizenId;
  String? _citizenName;
  LatLng? _currentPosition;
  String _sourceAddress = 'Current Location';
  bool _isUsingGps = true;

  LatLng? _destinationPosition;
  String _destinationName = 'Where are you going?';

  List<LatLng> _routePoints = [];
  double _routeDistanceKm = 2.9;
  int _routeDurationMin = 6;
  String _routeStreetName = 'Torstraße';
  bool _isRouteReady = false;
  bool _isLoadingRoute = false;

  bool _isJourneyActive = false;
  JourneySession? _activeSession;
  StreamSubscription<Position>? _positionSub;

  int _trustedContactsCount = 0;
  bool _isLoadingInitial = true;

  // Fallback coordinates (e.g. Mumbai center) if GPS permission not yet acquired
  static const LatLng _defaultCenter = LatLng(19.0760, 72.8777);

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  Future<void> _initializeScreen() async {
    setState(() => _isLoadingInitial = true);

    try {
      // 1. Fetch citizen profile
      final citizen = await _journeyService.getCurrentCitizen();
      _citizenId = citizen['id']?.toString();
      _citizenName = citizen['name']?.toString() ?? 'Citizen';

      // 2. Fetch trusted contacts count
      if (_citizenId != null) {
        final contacts = await _contactsService.getTrustedContacts(_citizenId!);
        _trustedContactsCount = contacts.length;
      }

      // 3. Acquire current location
      try {
        final position = await _locationService.getCurrentPosition();
        _currentPosition = LatLng(position.latitude, position.longitude);
      } catch (_) {
        _currentPosition = _defaultCenter;
      }

      // 4. Check for active journey
      if (_citizenId != null) {
        final active = await _journeyService.getActiveJourney(_citizenId!);
        if (active != null) {
          _activeSession = active;
          _isJourneyActive = true;
          _destinationName = active.destinationName;
          _destinationPosition = LatLng(
            active.destinationLatitude,
            active.destinationLongitude,
          );
          _startLocationTracking(active.id);
          _calculateRoute(silent: true);
        }
      }

      // Set default demo destination if not set yet so map preview renders nicely
      if (_destinationPosition == null && _currentPosition != null) {
        _destinationPosition = LatLng(
          _currentPosition!.latitude + 0.018,
          _currentPosition!.longitude + 0.015,
        );
        _destinationName = 'Central Plaza / Torstraße';
        _calculateRoute(silent: true);
      }
    } catch (_) {
      // Initial error handled
    } finally {
      if (mounted) {
        setState(() => _isLoadingInitial = false);
        if (_currentPosition != null) {
          _mapController.move(_currentPosition!, 14.5);
        }
      }
    }
  }

  // ============================================================
  // ROUTE CALCULATION (OSRM)
  // ============================================================

  Future<void> _calculateRoute({bool silent = false}) async {
    if (_currentPosition == null || _destinationPosition == null) {
      if (!silent) {
        _showToast('Please select both source and destination.', Colors.orange);
      }
      return;
    }

    if (!silent) setState(() => _isLoadingRoute = true);

    try {
      final result = await _routeService.getRoute(
        _currentPosition!,
        _destinationPosition!,
      );

      if (mounted) {
        setState(() {
          _routePoints = result.points;
          _routeDistanceKm = result.distanceKm;
          _routeDurationMin = result.durationMinutes;
          _routeStreetName = result.streetName;
          _isRouteReady = true;
          _isLoadingRoute = false;
        });

        // Center map to encompass route
        _fitRouteBounds();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _routePoints = [_currentPosition!, _destinationPosition!];
          _isRouteReady = true;
          _isLoadingRoute = false;
        });
      }
    }
  }

  void _fitRouteBounds() {
    if (_routePoints.length < 2) return;
    try {
      final bounds = LatLngBounds.fromPoints(_routePoints);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(40),
        ),
      );
    } catch (_) {}
  }

  void _zoomIn() {
    try {
      final currentZoom = _mapController.camera.zoom;
      if (currentZoom < 18.5) {
        _mapController.move(_mapController.camera.center, currentZoom + 1.0);
      }
    } catch (_) {}
  }

  void _zoomOut() {
    try {
      final currentZoom = _mapController.camera.zoom;
      if (currentZoom > 3.5) {
        _mapController.move(_mapController.camera.center, currentZoom - 1.0);
      }
    } catch (_) {}
  }

  void _centerOnMyLocation() {
    if (_currentPosition != null) {
      _mapController.move(_currentPosition!, 15.5);
      _showToast('Centered on your location.', Colors.teal);
    }
  }

  // ============================================================
  // START & END JOURNEY
  // ============================================================

  Future<void> _startJourney() async {
    if (_citizenId == null) {
      _showToast('Citizen profile not loaded.', Colors.red);
      return;
    }
    if (_destinationPosition == null) {
      _showToast('Please select a destination.', Colors.orange);
      return;
    }

    // Refresh GPS location
    try {
      final pos = await _locationService.getCurrentPosition();
      _currentPosition = LatLng(pos.latitude, pos.longitude);
    } catch (_) {}

    final startPos = _currentPosition ?? _defaultCenter;

    try {
      final session = await _journeyService.startJourney(
        citizenId: _citizenId!,
        startLatitude: startPos.latitude,
        startLongitude: startPos.longitude,
        destinationLatitude: _destinationPosition!.latitude,
        destinationLongitude: _destinationPosition!.longitude,
        destinationName: _destinationName,
      );

      setState(() {
        _activeSession = session;
        _isJourneyActive = true;
      });

      _startLocationTracking(session.id);

      // Dispatch SMS tracking link to trusted contacts
      final smsResult = await _journeyService.sendTrackingSms(
        journeyId: session.id,
      );

      final int sent = (smsResult['sent_count'] as int?) ?? 0;
      _showToast(
        sent > 0
            ? 'Journey started! Live tracking SMS sent to $sent contact(s).'
            : 'Journey started! Live tracking active.',
        Colors.green.shade700,
      );
    } catch (e) {
      _showToast('Failed to start journey: $e', Colors.red);
    }
  }

  void _startLocationTracking(String journeyId) {
    _positionSub?.cancel();
    _positionSub = _locationService
        .getPositionStream(
          distanceFilter: 10,
        )
        .listen(
          (pos) async {
            final latLng = LatLng(pos.latitude, pos.longitude);
            if (mounted) {
              setState(() {
                _currentPosition = latLng;
              });
            }

            try {
              await _journeyService.updateJourneyLocation(
                journeyId: journeyId,
                latitude: pos.latitude,
                longitude: pos.longitude,
                minDistanceMeters: 10,
                forceIntervalSeconds: 30,
              );
            } catch (_) {}
          },
          onError: (err) {
            debugPrint('Location stream error: $err');
          },
        );
  }

  Future<void> _endJourney() async {
    if (_activeSession == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Safe Journey'),
        content: const Text(
          'Have you reached your destination safely? This will complete live location sharing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
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

    try {
      await _positionSub?.cancel();
      _positionSub = null;

      await _journeyService.endJourney(_activeSession!.id);

      if (mounted) {
        setState(() {
          _isJourneyActive = false;
          _activeSession = null;
        });
        _showToast(
          'Journey completed safely! Tracking link deactivated.',
          Colors.teal,
        );
      }
    } catch (e) {
      _showToast('Failed to end journey: $e', Colors.red);
    }
  }

  // ============================================================
  // SOS EMERGENCY TRIGGER
  // ============================================================

  Future<void> _triggerSos() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Trigger Emergency SOS', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'This will send an immediate SOS distress alert with your live GPS location to all your registered trusted contacts.\n\nDo you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('TRIGGER SOS NOW'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final pos = _currentPosition ?? _defaultCenter;

    if (_citizenId == null) {
      _showToast('Citizen ID not found.', Colors.red);
      return;
    }

    _showToast('Transmitting Emergency SOS...', Colors.red.shade800);

    final result = await _sosService.triggerEmergencySos(
      citizenId: _citizenId!,
      latitude: pos.latitude,
      longitude: pos.longitude,
      journeyId: _activeSession?.id,
      citizenName: _citizenName,
    );

    if (result['success'] == true) {
      _showToast(
        result['message']?.toString() ?? 'SOS distress alert transmitted!',
        Colors.red.shade900,
      );
    } else {
      _showToast(
        result['message']?.toString() ?? 'Failed to send SOS alert.',
        Colors.red,
      );
    }
  }

  // ============================================================
  // SOURCE & DESTINATION PICKERS (WITH TYPE SEARCH & GPS)
  // ============================================================

  Future<void> _resetToCurrentGps() async {
    try {
      final pos = await _locationService.getCurrentPosition();
      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
        _sourceAddress = 'Current Location';
        _isUsingGps = true;
      });
      _mapController.move(_currentPosition!, 15.0);
      _calculateRoute();
      _showToast('Reset starting location to current GPS.', Colors.teal);
    } catch (e) {
      _showToast('GPS acquisition failed: $e', Colors.red);
    }
  }

  void _setCustomSource(String name, LatLng? coords) {
    final base = _currentPosition ?? _defaultCenter;
    final finalPos = coords ?? LatLng(base.latitude + 0.008, base.longitude + 0.006);

    setState(() {
      _sourceAddress = name;
      _currentPosition = finalPos;
      _isUsingGps = false;
    });

    _mapController.move(finalPos, 15.0);
    _calculateRoute();
    _showToast('Source location set to: $name', Colors.teal);
  }

  void _selectPresetSource(String name, double latOffset, double lngOffset) {
    final base = _currentPosition ?? _defaultCenter;
    final finalPos = LatLng(base.latitude + latOffset, base.longitude + lngOffset);

    setState(() {
      _sourceAddress = name;
      _currentPosition = finalPos;
      _isUsingGps = false;
    });

    _mapController.move(finalPos, 15.0);
    _calculateRoute();
    _showToast('Source set to: $name', Colors.teal);
  }

  void _openSourcePicker() {
    final controller = TextEditingController(
      text: _sourceAddress == 'Current Location' ? '' : _sourceAddress,
    );
    List<PlaceSearchResult> searchResults = [];
    bool isSearching = false;
    Timer? debounceTimer;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Starting Location',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Quick Option: Reset to device GPS
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.teal.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.my_location, color: Colors.teal, size: 20),
                  ),
                  title: const Text(
                    'Use Current GPS Location',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Acquire real-time coordinates from device sensors',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  trailing: const Icon(Icons.chevron_right, color: Colors.teal),
                  onTap: () {
                    Navigator.pop(ctx);
                    _resetToCurrentGps();
                  },
                ),

                const Divider(height: 20),

                // Search / type text field
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Type address, landmark, or street name...',
                    prefixIcon: const Icon(Icons.search, color: Colors.teal),
                    suffixIcon: controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              controller.clear();
                              setSheetState(() {
                                searchResults.clear();
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (val) {
                    debounceTimer?.cancel();
                    if (val.trim().length >= 2) {
                      setSheetState(() => isSearching = true);
                      debounceTimer = Timer(const Duration(milliseconds: 350), () async {
                        final res = await _routeService.searchPlaces(val, proximity: _currentPosition);
                        setSheetState(() {
                          searchResults = res;
                          isSearching = false;
                        });
                      });
                    } else {
                      setSheetState(() {
                        searchResults.clear();
                        isSearching = false;
                      });
                    }
                  },
                  onSubmitted: (val) {
                    final text = val.trim();
                    if (text.isNotEmpty) {
                      final coords = searchResults.isNotEmpty ? searchResults.first.coordinates : null;
                      _setCustomSource(text, coords);
                      Navigator.pop(ctx);
                    }
                  },
                ),

                if (isSearching)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.teal),
                      ),
                    ),
                  ),

                if (searchResults.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Matching Places',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: searchResults.length,
                      itemBuilder: (ctx, idx) {
                        final place = searchResults[idx];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 2),
                          leading: const Icon(Icons.location_on_outlined, color: Colors.teal, size: 20),
                          title: Text(
                            place.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          subtitle: place.subtitle.isNotEmpty
                              ? Text(
                                  place.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                )
                              : null,
                          onTap: () {
                            _setCustomSource(place.title, place.coordinates);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                const Text(
                  'Quick Selections',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.home, size: 16, color: Colors.teal),
                      label: const Text('Home'),
                      onPressed: () {
                        _selectPresetSource('Home', 0.015, 0.012);
                        Navigator.pop(ctx);
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.business, size: 16, color: Colors.purple),
                      label: const Text('Office'),
                      onPressed: () {
                        _selectPresetSource('Office (Tech Park)', 0.025, -0.018);
                        Navigator.pop(ctx);
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.school, size: 16, color: Colors.indigo),
                      label: const Text('University Campus'),
                      onPressed: () {
                        _selectPresetSource('University Campus', -0.019, 0.022);
                        Navigator.pop(ctx);
                      },
                    ),
                    ActionChip(
                      avatar: Icon(Icons.subway, size: 16, color: Colors.amber.shade900),
                      label: const Text('Metro Station'),
                      onPressed: () {
                        _selectPresetSource('Metro Station Central', 0.011, -0.009);
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),

                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Confirm Source Location'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final text = controller.text.trim();
                      if (text.isNotEmpty) {
                        final coords = searchResults.isNotEmpty ? searchResults.first.coordinates : null;
                        _setCustomSource(text, coords);
                      }
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openDestinationPicker() {
    final controller = TextEditingController(
      text: _destinationName == 'Where are you going?' ? '' : _destinationName,
    );
    List<PlaceSearchResult> searchResults = [];
    bool isSearching = false;
    Timer? debounceTimer;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Destination',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Enter address, landmark, or street name...',
                    prefixIcon: const Icon(Icons.search, color: Colors.purple),
                    suffixIcon: controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              controller.clear();
                              setSheetState(() {
                                searchResults.clear();
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (val) {
                    debounceTimer?.cancel();
                    if (val.trim().length >= 2) {
                      setSheetState(() => isSearching = true);
                      debounceTimer = Timer(const Duration(milliseconds: 350), () async {
                        final res = await _routeService.searchPlaces(val, proximity: _destinationPosition ?? _currentPosition);
                        setSheetState(() {
                          searchResults = res;
                          isSearching = false;
                        });
                      });
                    } else {
                      setSheetState(() {
                        searchResults.clear();
                        isSearching = false;
                      });
                    }
                  },
                  onSubmitted: (val) {
                    final text = val.trim();
                    if (text.isNotEmpty) {
                      final coords = searchResults.isNotEmpty ? searchResults.first.coordinates : null;
                      _setCustomDestination(text, coords);
                      Navigator.pop(ctx);
                    }
                  },
                ),

                if (isSearching)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purple),
                      ),
                    ),
                  ),

                if (searchResults.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Matching Places',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: searchResults.length,
                      itemBuilder: (ctx, idx) {
                        final place = searchResults[idx];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 2),
                          leading: const Icon(Icons.location_on_outlined, color: Colors.purple, size: 20),
                          title: Text(
                            place.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          subtitle: place.subtitle.isNotEmpty
                              ? Text(
                                  place.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11),
                                )
                              : null,
                          onTap: () {
                            _setCustomDestination(place.title, place.coordinates);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],

                const SizedBox(height: 14),
                const Text(
                  'Quick Selections',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.home, size: 16, color: Colors.teal),
                      label: const Text('Home'),
                      onPressed: () {
                        _selectPresetDestination('Home', 0.015, 0.012);
                        Navigator.pop(ctx);
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.business, size: 16, color: Colors.purple),
                      label: const Text('Office'),
                      onPressed: () {
                        _selectPresetDestination('Office (Tech Park)', 0.025, -0.018);
                        Navigator.pop(ctx);
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.school, size: 16, color: Colors.indigo),
                      label: const Text('College / University'),
                      onPressed: () {
                        _selectPresetDestination('University Campus', -0.019, 0.022);
                        Navigator.pop(ctx);
                      },
                    ),
                    ActionChip(
                      avatar: Icon(Icons.subway, size: 16, color: Colors.amber.shade900),
                      label: const Text('Metro Station'),
                      onPressed: () {
                        _selectPresetDestination('Metro Station Central', 0.011, -0.009);
                        Navigator.pop(ctx);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check),
                    label: const Text('Confirm Destination'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      final text = controller.text.trim();
                      if (text.isNotEmpty) {
                        final coords = searchResults.isNotEmpty ? searchResults.first.coordinates : null;
                        _setCustomDestination(text, coords);
                      }
                      Navigator.pop(ctx);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _setCustomDestination(String name, LatLng? coords) {
    final base = _currentPosition ?? _defaultCenter;
    final finalPos = coords ?? LatLng(base.latitude + 0.018, base.longitude + 0.015);

    setState(() {
      _destinationName = name;
      _destinationPosition = finalPos;
    });
    _mapController.move(finalPos, 14.5);
    _calculateRoute();
  }

  void _selectPresetDestination(String name, double latOffset, double lngOffset) {
    final base = _currentPosition ?? _defaultCenter;
    setState(() {
      _destinationName = name;
      _destinationPosition = LatLng(base.latitude + latOffset, base.longitude + lngOffset);
    });
    _calculateRoute();
  }

  // ============================================================
  // SAVE DESTINATION & SAVED DESTINATIONS SHEET
  // ============================================================

  Future<void> _handleSaveDestination() async {
    if (_citizenId == null) {
      _showToast('Citizen ID not loaded.', Colors.red);
      return;
    }

    final savedList = await _savedDestService.getSavedDestinations(_citizenId!);

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Saved Destinations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Save Current'),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      _showSaveCurrentDialog();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (savedList.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  alignment: Alignment.center,
                  child: const Text(
                    'No saved destinations yet.\nTap "Save Current" to add Home, College, or Office.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              else
                ...savedList.map((dest) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.purple.shade50,
                      child: Icon(
                        _getIconForDestination(dest.destinationName),
                        color: Colors.purple.shade700,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      dest.destinationName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      dest.address ??
                          '(${dest.latitude.toStringAsFixed(4)}, ${dest.longitude.toStringAsFixed(4)})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          onPressed: () async {
                            final destName = dest.destinationName;
                            Navigator.pop(ctx);
                            await _savedDestService.deleteDestination(dest.id);
                            if (mounted) {
                              _showToast('Deleted $destName', Colors.grey.shade800);
                            }
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      setState(() {
                        _destinationName = dest.destinationName;
                        _destinationPosition = LatLng(dest.latitude, dest.longitude);
                      });
                      _calculateRoute();
                      Navigator.pop(ctx);
                    },
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  void _showSaveCurrentDialog() {
    if (_destinationPosition == null) {
      _showToast('Please select a destination first to save it.', Colors.orange);
      return;
    }

    final nameController = TextEditingController(
      text: _destinationName == 'Where are you going?' ? '' : _destinationName,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Destination'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter a custom name for this destination (e.g. Home, College, Work):',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Destination Label',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.bookmark_border),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty && _citizenId != null) {
                Navigator.pop(ctx);
                await _savedDestService.saveDestination(
                  citizenId: _citizenId!,
                  name: name,
                  latitude: _destinationPosition!.latitude,
                  longitude: _destinationPosition!.longitude,
                  address: name,
                );
                if (mounted) {
                  _showToast('Destination "$name" saved!', Colors.purple);
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  IconData _getIconForDestination(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('home')) return Icons.home;
    if (lower.contains('office') || lower.contains('work')) return Icons.business;
    if (lower.contains('college') || lower.contains('school') || lower.contains('univ')) {
      return Icons.school;
    }
    if (lower.contains('metro') || lower.contains('station')) return Icons.subway;
    return Icons.place;
  }

  void _showToast(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ============================================================
  // UI BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final activeCenter = _currentPosition ?? _defaultCenter;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shield, color: Colors.red, size: 20),
            ),
            const SizedBox(width: 8),
            const Text(
              'UniSafe',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Safe Mode',
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoadingInitial
          ? const Center(child: CircularProgressIndicator(color: Colors.purple))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Title
                  const Text(
                    'Women Safety',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Plan your journey and stay connected with your trusted contacts.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),

                  const SizedBox(height: 16),

                  // 1. SOURCE CARD
                  _buildLocationCard(
                    isSource: true,
                    label: 'SOURCE',
                    title: _sourceAddress,
                    subtitle: _isUsingGps
                        ? 'Using current GPS • Tap to type address'
                        : 'Custom starting location • Tap to edit',
                    icon: Icons.near_me,
                    iconColor: Colors.teal,
                    trailingIcon: Icons.my_location,
                    extraActionIcon: Icons.search,
                    onTap: _openSourcePicker,
                    onExtraActionTap: _openSourcePicker,
                    onTrailingTap: _resetToCurrentGps,
                  ),

                  const SizedBox(height: 10),

                  // 2. DESTINATION CARD
                  _buildLocationCard(
                    isSource: false,
                    label: 'DESTINATION',
                    title: _destinationName,
                    subtitle: 'Search or enter destination',
                    icon: Icons.location_on,
                    iconColor: Colors.pink,
                    trailingIcon: Icons.search,
                    onTap: _openDestinationPicker,
                    onTrailingTap: _openDestinationPicker,
                  ),

                  const SizedBox(height: 12),

                  // 3. ACTION BUTTONS: [Save Destination] & [Recommend Route]
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.bookmark_border, size: 18),
                          label: const Text('Save Destination', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.purple.shade700,
                            side: BorderSide(color: Colors.purple.shade200),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          onPressed: _handleSaveDestination,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: _isLoadingRoute
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.alt_route, size: 18),
                          label: const Text('Recommend Route', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.blue.shade700,
                            side: BorderSide(color: Colors.blue.shade200),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                          ),
                          onPressed: () => _calculateRoute(),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 4. MAP & ROUTE PREVIEW CONTAINER
                  _buildMapPreviewCard(activeCenter),

                  const SizedBox(height: 16),

                  // 5. START / END JOURNEY BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      icon: Icon(
                        _isJourneyActive ? Icons.stop : Icons.arrow_drop_down,
                        size: 24,
                      ),
                      label: Text(
                        _isJourneyActive ? 'END JOURNEY' : 'START JOURNEY',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isJourneyActive
                            ? Colors.red.shade700
                            : const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _isJourneyActive ? _endJourney : _startJourney,
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 6. TRUSTED CONTACTS SECTION
                  _buildTrustedContactsCard(),

                  const SizedBox(height: 14),

                  // 7. SOS EMERGENCY BUTTON
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.emergency, size: 22, color: Colors.white),
                      label: const Text(
                        '🚨 SOS – EMERGENCY',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _triggerSos,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // SOS Subtitle
                  const Center(
                    child: Text(
                      'SOS remains accessible even when a journey has not started.',
                      style: TextStyle(fontSize: 11, color: Colors.black45),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  // ============================================================
  // WIDGET HELPERS
  // ============================================================

  Widget _buildLocationCard({
    required bool isSource,
    required String label,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required IconData trailingIcon,
    IconData? extraActionIcon,
    VoidCallback? onTap,
    VoidCallback? onTrailingTap,
    VoidCallback? onExtraActionTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.black45,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                ],
              ),
            ),
            if (extraActionIcon != null)
              IconButton(
                icon: Icon(extraActionIcon, color: iconColor, size: 20),
                tooltip: 'Search / Type',
                onPressed: onExtraActionTap,
              ),
            IconButton(
              icon: Icon(trailingIcon, color: iconColor, size: 20),
              tooltip: isSource ? 'Reset to GPS' : 'Search',
              onPressed: onTrailingTap,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapPreviewCard(LatLng center) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Map Box (Expanded to 340px with smooth gestures and dedicated zoom dock)
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: SizedBox(
              height: 340,
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 14.5,
                      minZoom: 3.0,
                      maxZoom: 19.0,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all,
                        pinchZoomThreshold: 0.5,
                      ),
                      onLongPress: (tapPosition, point) {
                        setState(() {
                          _destinationPosition = point;
                          _destinationName =
                              'Selected Pin (${point.latitude.toStringAsFixed(4)}, ${point.longitude.toStringAsFixed(4)})';
                        });
                        _calculateRoute();
                        _showToast('Destination pin set on map.', Colors.pink);
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.unisafe',
                        maxZoom: 19,
                        minZoom: 3,
                        keepBuffer: 3,
                        panBuffer: 1,
                      ),
                      if (_routePoints.length >= 2)
                        PolylineLayer(
                          polylines: [
                            Polyline(
                              points: _routePoints,
                              strokeWidth: 4.5,
                              color: const Color(0xFF1E5BB8),
                            ),
                          ],
                        ),
                      MarkerLayer(
                        markers: [
                          if (_currentPosition != null)
                            Marker(
                              point: _currentPosition!,
                              width: 36,
                              height: 36,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade700,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2.5),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          if (_destinationPosition != null)
                            Marker(
                              point: _destinationPosition!,
                              width: 36,
                              height: 36,
                              child: const Icon(
                                Icons.location_on,
                                color: Colors.red,
                                size: 36,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),

                  // TOP STREET BANNER
                  Positioned(
                    top: 10,
                    left: 85,
                    right: 85,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: Text(
                        _routeStreetName,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),

                  // LEFT HUD TURN DIRECTION BOX
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      width: 70,
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.turn_right, size: 28, color: Colors.black87),
                          const SizedBox(height: 2),
                          const Text(
                            '80 m',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const Divider(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.turn_left, size: 12, color: Colors.black54),
                              SizedBox(width: 2),
                              Text('740 m', style: TextStyle(fontSize: 9, color: Colors.black54)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // RIGHT HUD STATS COLUMN (flag, timer, speed, GPS)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildHudChip(Icons.flag, '${_routeDistanceKm.toStringAsFixed(1)} km'),
                        const SizedBox(height: 4),
                        _buildHudChip(Icons.timer_outlined, '$_routeDurationMin min'),
                        const SizedBox(height: 4),
                        _buildHudChip(Icons.speed, '15 km/h'),
                        const SizedBox(height: 4),
                        _buildHudChip(Icons.gps_fixed, 'GPS'),
                      ],
                    ),
                  ),

                  // FLOATING MAP ZOOM & NAVIGATION DOCK
                  Positioned(
                    bottom: 12,
                    right: 10,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add, size: 20, color: Colors.black87),
                            tooltip: 'Zoom In',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            onPressed: _zoomIn,
                          ),
                          const Divider(height: 1, indent: 4, endIndent: 4),
                          IconButton(
                            icon: const Icon(Icons.remove, size: 20, color: Colors.black87),
                            tooltip: 'Zoom Out',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            onPressed: _zoomOut,
                          ),
                          const Divider(height: 1, indent: 4, endIndent: 4),
                          IconButton(
                            icon: const Icon(Icons.crop_free, size: 18, color: Colors.indigo),
                            tooltip: 'Fit Entire Route',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            onPressed: _fitRouteBounds,
                          ),
                          const Divider(height: 1, indent: 4, endIndent: 4),
                          IconButton(
                            icon: const Icon(Icons.my_location, size: 18, color: Colors.teal),
                            tooltip: 'Center on My Location',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            onPressed: _centerOnMyLocation,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Route Preview Caption
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Route Preview',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _isRouteReady ? 'Ready' : 'Calculating',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.touch_app, size: 14, color: Colors.purple.shade400),
                    const SizedBox(width: 4),
                    const Expanded(
                      child: Text(
                        'Pinch or use + / − buttons to zoom. Long-press map to place destination pin.',
                        style: TextStyle(fontSize: 11, color: Colors.black54),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHudChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.black87),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustedContactsCard() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const TrustedContactsScreen()),
        ).then((_) => _initializeScreen());
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.group_outlined, size: 20, color: Colors.blue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Trusted Contacts',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _trustedContactsCount > 0 ? 'Enabled ($_trustedContactsCount)' : 'Enabled',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Share live location via SMS',
              style: TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            const Text(
              'Your trusted contacts will receive a secure tracking link through Pingram when you start your journey.',
              style: TextStyle(fontSize: 11, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }
}
