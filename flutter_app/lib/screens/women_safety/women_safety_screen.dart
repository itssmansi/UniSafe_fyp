import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/traffic_config.dart';
import '../../models/journey_session.dart';
import '../../models/saved_destination.dart';
import '../../services/journey_service.dart';
import '../../services/location_service.dart';
import '../../services/night_activity_service.dart';
import '../../services/notification_service.dart';
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

class _WomenSafetyScreenState extends State<WomenSafetyScreen>
    with WidgetsBindingObserver {
  bool get _supportsBackgroundMonitoring =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  // Services
  final JourneyService _journeyService = JourneyService();
  final LocationService _locationService = LocationService();
  final RouteService _routeService = RouteService();
  final NightActivityService _nightActivityService = NightActivityService();
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
  double _routeDistanceKm = 5.4;
  int _routeDurationMin = 18;
  int _trafficDelayMinutes = 5;
  String _routeStreetName = 'Selected Route';
  TransportMode _selectedTransportMode = TransportMode.driving;
  List<SavedDestination> _savedDestinations = [];
  bool _isRouteReady = false;
  bool _isLoadingRoute = false;
  List<RouteOption> _routeOptions = [];
  int _selectedRouteIndex = 0;
  bool _routeIsAccurate = false;
  DateTime _plannedDeparture = DateTime.now();
  List<RouteActivitySummary> _routeSummaries = [];
  bool _isLoadingPlaces = false;
  String? _placeLookupError;
  bool? _placeLookupConsent;
  int _routeRequestId = 0;
  bool _showLiveTraffic = true;
  String _tomTomApiKey = '';
  bool _trafficTileError = false;
  int _trafficLayerSession = 0;

  bool _isJourneyActive = false;
  JourneySession? _activeSession;
  StreamSubscription<Position>? _positionSub;
  Timer? _inactivityTimer;
  Timer? _sosCountdownTimer;
  DateTime? _lastMovementAt;
  DateTime? _sosDeadline;
  Position? _latestAccuratePosition;
  double? _currentGpsSpeed;
  bool _inactivityPromptOpen = false;
  bool _inactivityDialogVisible = false;
  bool _sosIncidentTriggered = false;
  bool _appInForeground = true;
  bool _inactivityMonitoringEnabled = false;

  int _trustedContactsCount = 0;
  bool _isLoadingInitial = true;

  // Fallback coordinates (e.g. Mumbai center) if GPS permission not yet acquired
  static const LatLng _defaultCenter = LatLng(19.0760, 72.8777);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScreen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSub?.cancel();
    _inactivityTimer?.cancel();
    _sosCountdownTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
    if (!_appInForeground) {
      if (_inactivityPromptOpen) {
        NotificationService.showSafetyCheckNotification();
      }
      return;
    }
    if (_inactivityPromptOpen) {
      _presentInactivityDialog();
    }
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

      // 2. Fetch trusted contacts count and saved destinations
      if (_citizenId != null) {
        final contacts = await _contactsService.getTrustedContacts(_citizenId!);
        _trustedContactsCount = contacts.length;
        await _loadSavedDestinations();
      }
      _tomTomApiKey = await TrafficConfig.getEffectiveKey();

      // 3. Acquire current location
      try {
        final position = await _locationService.getCurrentPosition();
        _currentPosition = LatLng(position.latitude, position.longitude);
        _latestAccuratePosition = position.accuracy <= 50 ? position : null;
      } catch (_) {
        _currentPosition = _defaultCenter;
        _sourceAddress = 'Bandra, Mumbai (Default)';
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
          final preferences = await SharedPreferences.getInstance();
          _sosIncidentTriggered =
              preferences.getBool('unisafe_sos_incident_triggered') == true;
          final monitoringSaved =
              preferences.getBool('unisafe_monitor_enabled') == true &&
              preferences.getString('unisafe_monitor_journey_id') == active.id;
          if (monitoringSaved) {
            try {
              if (_supportsBackgroundMonitoring) {
                await _locationService.ensureBackgroundLocationReady();
              } else if (!kIsWeb) {
                await _locationService.ensureLocationReady();
              }
              _inactivityMonitoringEnabled = true;
              final lastMovement = preferences.getInt(
                'unisafe_last_movement_ms',
              );
              _lastMovementAt = lastMovement == null
                  ? DateTime.now()
                  : DateTime.fromMillisecondsSinceEpoch(lastMovement);
              final deadline = preferences.getInt('unisafe_sos_deadline_ms');
              if (deadline != null && !_sosIncidentTriggered) {
                _inactivityPromptOpen = true;
                _sosDeadline = DateTime.fromMillisecondsSinceEpoch(deadline);
              }
            } catch (_) {
              await preferences.remove('unisafe_monitor_enabled');
            }
          }
          _startLocationTracking(active.id);
          if (_inactivityPromptOpen && _sosDeadline != null) {
            _showSafetyCheckNotificationIfBackground();
            _armSosCountdown(_sosDeadline!);
            if (_appInForeground) _presentInactivityDialog();
          }
          _calculateRoute(silent: true);
        }
      }

      // 5. Default route preview if no active journey
      if (_destinationPosition == null) {
        _currentPosition ??= _defaultCenter;
        if (_savedDestinations.isNotEmpty) {
          final dest = _savedDestinations.first;
          _destinationPosition = LatLng(dest.latitude, dest.longitude);
          _destinationName = dest.destinationName;
        } else {
          _destinationPosition = const LatLng(19.1197, 72.8468);
          _destinationName = 'Andheri West';
        }
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
    final requestId = ++_routeRequestId;

    try {
      final result = await _routeService.getRoute(
        _currentPosition!,
        _destinationPosition!,
        mode: _selectedTransportMode,
      );

      if (mounted && requestId == _routeRequestId) {
        setState(() {
          _routePoints = result.points;
          _routeDistanceKm = result.distanceKm;
          _routeDurationMin = result.durationMinutes;
          _trafficDelayMinutes = result.trafficDelayMinutes;
          _routeStreetName = result.streetName;
          _routeOptions = result.alternatives;
          _selectedRouteIndex = 0;
          _routeIsAccurate = result.isAccurate;
          _routeSummaries = [];
          _placeLookupError = null;
          _isLoadingPlaces = result.isAccurate;
          _isRouteReady = true;
          _isLoadingRoute = false;
        });

        // Center map to encompass route
        _fitRouteBounds();
        _loadRoutePlaces(result.alternatives, requestId);
      }
    } catch (_) {
      if (mounted && requestId == _routeRequestId) {
        setState(() {
          _routePoints = [_currentPosition!, _destinationPosition!];
          _routeOptions = [];
          _routeIsAccurate = false;
          _isRouteReady = true;
          _isLoadingRoute = false;
        });
      }
    }
  }

  Future<void> _loadRoutePlaces(List<RouteOption> routes, int requestId) async {
    if (routes.isEmpty) {
      if (mounted && requestId == _routeRequestId) {
        setState(() => _isLoadingPlaces = false);
      }
      return;
    }
    try {
      final preferences = await SharedPreferences.getInstance();
      var consent = preferences.getBool('unisafe_open_map_lookup_consent') ?? true;
      if (consent != true) {
        if (mounted && requestId == _routeRequestId) {
          setState(() {
            _isLoadingPlaces = false;
            _placeLookupConsent = false;
            _placeLookupError = null;
          });
        }
        return;
      }
      if (mounted && requestId == _routeRequestId) {
        setState(() => _placeLookupConsent = true);
      }
      final places = await _nightActivityService.findPlaces(routes);
      if (!mounted || requestId != _routeRequestId) return;
      final summaries = routes
          .map((route) => _nightActivityService.summarize(route, places))
          .toList();
      setState(() {
        _routeSummaries = summaries;
        _isLoadingPlaces = false;
        _placeLookupError = null;
      });
    } catch (error) {
      if (!mounted || requestId != _routeRequestId) return;
      setState(() {
        _routeSummaries = [];
        _isLoadingPlaces = false;
        _placeLookupError = error.toString().replaceFirst(
          RegExp(r'^Bad state: '),
          '',
        );
      });
    }
  }

  Future<void> _retryPlaceLookup() async {
    if (_routeOptions.isEmpty) return;
    setState(() {
      _isLoadingPlaces = true;
      _placeLookupError = null;
    });
    await _loadRoutePlaces(_routeOptions, _routeRequestId);
  }

  Future<void> _setPlaceLookupConsent(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('unisafe_open_map_lookup_consent', enabled);
    if (!mounted) return;
    setState(() {
      _placeLookupConsent = enabled;
      _placeLookupError = null;
      _routeSummaries = [];
      _isLoadingPlaces = enabled;
    });
    if (enabled) {
      await _loadRoutePlaces(_routeOptions, _routeRequestId);
    }
  }

  RouteActivitySummary? get _selectedRouteSummary =>
      _selectedRouteIndex < _routeSummaries.length
      ? _routeSummaries[_selectedRouteIndex]
      : null;

  Future<void> _clearSavedMonitoring(SharedPreferences preferences) async {
    await preferences.remove('unisafe_monitor_enabled');
    await preferences.remove('unisafe_monitor_journey_id');
    await preferences.remove('unisafe_last_movement_ms');
    await preferences.remove('unisafe_sos_deadline_ms');
    await preferences.remove('unisafe_sos_incident_triggered');
  }

  void _selectRoute(int index) {
    if (index < 0 || index >= _routeOptions.length) return;
    final route = _routeOptions[index];
    setState(() {
      _selectedRouteIndex = index;
      _routePoints = route.points;
      _routeDistanceKm = route.distanceKm;
      _routeDurationMin = route.durationMinutes;
      _trafficDelayMinutes = route.trafficDelayMinutes;
      _routeStreetName = route.streetName;
      _routeIsAccurate = true;
    });
    _fitRouteBounds();
  }

  Future<void> _selectPlannedDeparture() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _plannedDeparture.isBefore(now) ? now : _plannedDeparture,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_plannedDeparture),
    );
    if (time == null || !mounted) return;
    setState(
      () => _plannedDeparture = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      ),
    );
  }

  void _fitRouteBounds() {
    if (_routePoints.length < 2) return;
    try {
      final bounds = LatLngBounds.fromPoints(_routePoints);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(40)),
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
      _latestAccuratePosition = pos;
    } catch (e) {
      _showToast(
        'Could not get your current location. Journey not started: $e',
        Colors.red,
      );
      return;
    }

    if (!mounted) return;

    final enableMonitoring = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Journey safety monitoring'),
        content: Text(
          _supportsBackgroundMonitoring
              ? 'While this journey is active, UniSafe can monitor GPS movement and ask “ARE YOU SAFE?” after 10 minutes without movement. Android will show a persistent location notification while monitoring continues in the background. “Allow all the time” location permission is required. The service cannot recover after UniSafe is force-stopped or Android stops its service.'
              : 'UniSafe can check movement while this screen is open. It cannot keep monitoring in the background on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Skip'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enable'),
          ),
        ],
      ),
    );

    var monitorEnabled = false;
    if (enableMonitoring == true) {
      try {
        if (_supportsBackgroundMonitoring) {
          await _locationService.ensureBackgroundLocationReady();
        } else {
          await _locationService.ensureLocationReady();
        }
        monitorEnabled = true;
      } catch (error) {
        if (mounted) {
          final openSettings = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(
                _supportsBackgroundMonitoring
                    ? 'Background location permission needed'
                    : 'Location permission needed',
              ),
              content: Text(
                _supportsBackgroundMonitoring
                    ? '$error\n\nThe journey can continue, but automatic movement checks will stay off until location is allowed all the time.'
                    : '$error\n\nThe journey can continue without movement checks.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Continue without checks'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Open settings'),
                ),
              ],
            ),
          );
          if (openSettings == true) {
            await _locationService.openAppSettings();
            try {
              if (_supportsBackgroundMonitoring) {
                await _locationService.ensureBackgroundLocationReady();
              } else {
                await _locationService.ensureLocationReady();
              }
              monitorEnabled = true;
            } catch (_) {}
          }
        }
      }
    }

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
        _inactivityMonitoringEnabled = monitorEnabled;
      });
      _sosIncidentTriggered = false;
      _inactivityPromptOpen = false;
      _inactivityDialogVisible = false;
      _sosDeadline = null;
      _lastMovementAt = DateTime.now();
      final preferences = await SharedPreferences.getInstance();
      if (monitorEnabled) {
        await preferences.setBool('unisafe_monitor_enabled', true);
        await preferences.setString('unisafe_monitor_journey_id', session.id);
        await preferences.setInt(
          'unisafe_last_movement_ms',
          _lastMovementAt!.millisecondsSinceEpoch,
        );
      } else {
        await _clearSavedMonitoring(preferences);
      }

      if (_inactivityMonitoringEnabled) {
        try {
          _latestAccuratePosition = await _locationService.getCurrentPosition();
          _lastMovementAt = DateTime.now();
        } catch (_) {
          _latestAccuratePosition ??= (_currentPosition != null
              ? Position(
                  latitude: _currentPosition!.latitude,
                  longitude: _currentPosition!.longitude,
                  timestamp: DateTime.now(),
                  accuracy: 15,
                  altitude: 0,
                  heading: 0,
                  speed: 0,
                  speedAccuracy: 0,
                  altitudeAccuracy: 0,
                  headingAccuracy: 0,
                )
              : null);
          _lastMovementAt = DateTime.now();
        }
        _armInactivityTimer();
      }

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
    _inactivityTimer?.cancel();
    _sosCountdownTimer?.cancel();
    _armInactivityTimer();
    _positionSub = _locationService
        .getPositionStream(
          distanceFilter: _inactivityMonitoringEnabled ? 0 : 10,
          backgroundTracking: _inactivityMonitoringEnabled,
        )
        .listen(
          (pos) async {
            final latLng = LatLng(pos.latitude, pos.longitude);
            _processMovement(pos);
            if (mounted) {
              setState(() {
                _currentPosition = latLng;
                if (pos.speed >= 0) {
                  _currentGpsSpeed = pos.speed * 3.6;
                }
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

  void _armInactivityTimer() {
    _inactivityTimer?.cancel();
    if (!_isJourneyActive ||
        !_inactivityMonitoringEnabled ||
        _sosIncidentTriggered) {
      return;
    }
    final lastMovement = _lastMovementAt ?? DateTime.now();
    final elapsed = DateTime.now().difference(lastMovement);
    final remaining = const Duration(minutes: 10) - elapsed;
    _inactivityTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      _showInactivityPrompt,
    );
  }

  Future<void> _setInactivityMonitoring(bool enabled) async {
    if (!enabled) {
      setState(() => _inactivityMonitoringEnabled = false);
      _inactivityTimer?.cancel();
      _sosCountdownTimer?.cancel();
      if (_inactivityDialogVisible && Navigator.of(context).canPop()) {
        Navigator.of(context).pop(false);
      }
      _inactivityPromptOpen = false;
      _inactivityDialogVisible = false;
      NotificationService.cancelSafetyCheckNotification();
      final preferences = await SharedPreferences.getInstance();
      await _clearSavedMonitoring(preferences);
      if (_activeSession != null) _startLocationTracking(_activeSession!.id);
      _showToast('Movement checks turned off.', Colors.grey.shade700);
      return;
    }

    if (!_isJourneyActive) {
      setState(() => _inactivityMonitoringEnabled = true);
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('unisafe_monitor_enabled', true);
      _showToast(
        'Movement checks pre-armed. Will activate when journey starts.',
        Colors.teal,
      );
      return;
    }

    if (!mounted) return;
    final consent = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          _supportsBackgroundMonitoring
              ? 'Enable background journey checks?'
              : 'Enable movement checks while open?',
        ),
        content: Text(
          _supportsBackgroundMonitoring
              ? 'Android will keep a location foreground service running with a persistent notification during this journey. UniSafe uses movement updates to prompt you and may send an SOS to your trusted contacts if you do not respond. You can turn this off at any time.'
              : 'UniSafe will watch GPS movement while this screen is open and ask “ARE YOU SAFE?” after 10 minutes without movement. Monitoring stops when you leave the app or lock the device. You can turn this off at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (consent != true || !mounted) return;
    try {
      Position? position;
      try {
        position = await _locationService.getCurrentPosition();
      } catch (_) {
        position = await Geolocator.getLastKnownPosition();
      }

      if (position == null && _currentPosition != null) {
        position = Position(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          timestamp: DateTime.now(),
          accuracy: 15,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );
      }

      if (_supportsBackgroundMonitoring) {
        await _locationService.ensureBackgroundLocationReady();
      } else if (!kIsWeb) {
        await _locationService.ensureLocationReady();
      }

      if (position != null && position.accuracy > 100 && !kIsWeb) {
        _showToast(
          'GPS accuracy is low (${position.accuracy.toStringAsFixed(0)}m), but movement checks are enabled.',
          Colors.orange,
        );
      }

      setState(() {
        _inactivityMonitoringEnabled = true;
        _sosIncidentTriggered = false;
      });
      _latestAccuratePosition = position;
      _lastMovementAt = DateTime.now();
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('unisafe_monitor_enabled', true);
      await preferences.remove('unisafe_sos_incident_triggered');
      await preferences.remove('unisafe_sos_deadline_ms');
      if (_activeSession != null) {
        await preferences.setString(
          'unisafe_monitor_journey_id',
          _activeSession!.id,
        );
      }
      await preferences.setInt(
        'unisafe_last_movement_ms',
        _lastMovementAt!.millisecondsSinceEpoch,
      );
      if (_activeSession != null) _startLocationTracking(_activeSession!.id);
      _armInactivityTimer();
      _showToast('Movement checks enabled.', Colors.teal);
    } catch (e) {
      if (!mounted) return;
      final openSettings = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            _supportsBackgroundMonitoring
                ? 'Background permission is needed'
                : 'Location permission is needed',
          ),
          content: Text(
            _supportsBackgroundMonitoring
                ? '$e\n\nAllow UniSafe location access all the time in Android settings, then enable journey checks again.'
                : '$e\n\nAllow location access for UniSafe, then enable movement checks again.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Open settings'),
            ),
          ],
        ),
      );
      if (openSettings == true) await _locationService.openAppSettings();
    }
  }

  Future<void> _resolveSosIncident() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('unisafe_sos_incident_triggered');
    await preferences.remove('unisafe_sos_deadline_ms');
    if (mounted) {
      setState(() {
        _sosIncidentTriggered = false;
        _lastMovementAt = DateTime.now();
      });
    }
    if (_inactivityMonitoringEnabled && _isJourneyActive) {
      _armInactivityTimer();
    }
    _showToast('Emergency alert resolved. Safe journey resumed.', Colors.teal);
  }

  void _processMovement(Position position) {
    if (!_isJourneyActive ||
        !_inactivityMonitoringEnabled ||
        (position.accuracy > 50 && !kIsWeb)) {
      return;
    }
    final previous = _latestAccuratePosition;
    _latestAccuratePosition = position;
    final moved =
        previous != null &&
        Geolocator.distanceBetween(
              previous.latitude,
              previous.longitude,
              position.latitude,
              position.longitude,
            ) >=
            25;
    if (moved) {
      _lastMovementAt = DateTime.now();
      SharedPreferences.getInstance().then(
        (preferences) => preferences.setInt(
          'unisafe_last_movement_ms',
          _lastMovementAt!.millisecondsSinceEpoch,
        ),
      );
      if (_inactivityPromptOpen) {
        _inactivityPromptOpen = false;
        _sosCountdownTimer?.cancel();
        if (_appInForeground &&
            _inactivityDialogVisible &&
            Navigator.of(context).canPop()) {
          Navigator.of(context).pop(false);
        }
        _inactivityDialogVisible = false;
        NotificationService.cancelSafetyCheckNotification();
        SharedPreferences.getInstance().then(
          (preferences) => preferences.remove('unisafe_sos_deadline_ms'),
        );
      }
      _armInactivityTimer();
    }
  }

  Future<void> _showInactivityPrompt() async {
    if (!mounted ||
        !_isJourneyActive ||
        !_inactivityMonitoringEnabled ||
        _inactivityPromptOpen ||
        _sosIncidentTriggered) {
      return;
    }
    _inactivityPromptOpen = true;
    _sosDeadline = DateTime.now().add(const Duration(minutes: 5));
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(
      'unisafe_sos_deadline_ms',
      _sosDeadline!.millisecondsSinceEpoch,
    );
    if (_appInForeground) {
      _presentInactivityDialog();
    } else {
      await NotificationService.showSafetyCheckNotification();
    }
    _armSosCountdown(_sosDeadline!);
  }

  void _showSafetyCheckNotificationIfBackground() {
    if (!_appInForeground) NotificationService.showSafetyCheckNotification();
  }

  void _armSosCountdown(DateTime deadline) {
    _sosCountdownTimer?.cancel();
    final remaining = deadline.difference(DateTime.now());
    _sosCountdownTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () async {
        if (!mounted || !_inactivityPromptOpen || _sosIncidentTriggered) return;
        _inactivityPromptOpen = false;
        if (_appInForeground &&
            _inactivityDialogVisible &&
            Navigator.of(context).canPop()) {
          Navigator.of(context).pop(false);
        }
        _inactivityDialogVisible = false;
        await NotificationService.cancelSafetyCheckNotification();
        await _triggerSos(requireConfirmation: false);
        if (!_sosIncidentTriggered && _isJourneyActive) {
          _lastMovementAt = DateTime.now();
          _armInactivityTimer();
        }
      },
    );
  }

  Future<void> _presentInactivityDialog() async {
    if (!mounted ||
        !_appInForeground ||
        !_inactivityPromptOpen ||
        _inactivityDialogVisible) {
      return;
    }
    _inactivityDialogVisible = true;
    final response = showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('ARE YOU SAFE?'),
        content: const Text(
          'UniSafe has not detected movement during your active journey. Confirm you are safe to continue. If you do not respond within 5 minutes, UniSafe will request an SOS using your latest accurate GPS location. GPS or network failure can prevent the request or delivery.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel alert'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('I am safe'),
          ),
        ],
      ),
    );
    final safe = await response;
    _inactivityDialogVisible = false;
    if (!mounted) return;
    if (!_inactivityPromptOpen) return;
    _inactivityPromptOpen = false;
    _sosDeadline = null;
    _sosCountdownTimer?.cancel();
    await NotificationService.cancelSafetyCheckNotification();
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove('unisafe_sos_deadline_ms');
    if (safe == true) {
      _lastMovementAt = DateTime.now();
      await preferences.setInt(
        'unisafe_last_movement_ms',
        _lastMovementAt!.millisecondsSinceEpoch,
      );
      _armInactivityTimer();
    } else if (!_sosIncidentTriggered) {
      _lastMovementAt = DateTime.now();
      await preferences.setInt(
        'unisafe_last_movement_ms',
        _lastMovementAt!.millisecondsSinceEpoch,
      );
      _armInactivityTimer();
    }
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
      _inactivityTimer?.cancel();
      _sosCountdownTimer?.cancel();

      await _journeyService.endJourney(_activeSession!.id);
      final preferences = await SharedPreferences.getInstance();
      await _clearSavedMonitoring(preferences);

      if (mounted) {
        setState(() {
          _isJourneyActive = false;
          _activeSession = null;
          _currentGpsSpeed = null;
          _inactivityMonitoringEnabled = false;
          _inactivityPromptOpen = false;
          _inactivityDialogVisible = false;
          _sosIncidentTriggered = false;
          _sosDeadline = null;
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

  Future<void> _triggerSos({bool requireConfirmation = true}) async {
    if (_sosIncidentTriggered) {
      _showToast(
        'An SOS alert is active. Tap "I’m Safe" to resolve it.',
        Colors.orange.shade800,
      );
      return;
    }
    final confirmed = requireConfirmation
        ? await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                    size: 28,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Trigger Emergency SOS',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
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
          )
        : true;

    if (confirmed != true) {
      if (_inactivityPromptOpen) {
        _inactivityPromptOpen = false;
        _sosCountdownTimer?.cancel();
        _lastMovementAt = DateTime.now();
        final preferences = await SharedPreferences.getInstance();
        await preferences.remove('unisafe_sos_deadline_ms');
        await preferences.setInt(
          'unisafe_last_movement_ms',
          _lastMovementAt!.millisecondsSinceEpoch,
        );
        _armInactivityTimer();
      }
      return;
    }

    LatLng? pos;
    try {
      final current = await _locationService.getCurrentPosition();
      pos = LatLng(current.latitude, current.longitude);
    } catch (_) {
      final cached = _latestAccuratePosition;
      if (cached != null &&
          DateTime.now().difference(cached.timestamp) <=
              const Duration(minutes: 2)) {
        pos = LatLng(cached.latitude, cached.longitude);
      }
    }
    if (pos == null) {
      _showToast(
        'SOS could not get a current or recent accurate location. Check GPS and retry.',
        Colors.red,
      );
      return;
    }

    if (_citizenId == null) {
      _showToast('Citizen ID not found.', Colors.red);
      return;
    }

    _sosIncidentTriggered = true;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('unisafe_sos_incident_triggered', true);
    _inactivityTimer?.cancel();
    _sosCountdownTimer?.cancel();
    _showToast('Sending emergency alert…', Colors.red.shade800);

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
    if (coords == null) {
      _showToast(
        'Choose a matched place or use the map to set a source.',
        Colors.orange,
      );
      return;
    }
    final finalPos = coords;

    setState(() {
      _sourceAddress = name;
      _currentPosition = finalPos;
      _isUsingGps = false;
    });

    _mapController.move(finalPos, 15.0);
    _calculateRoute();
    _showToast('Source location set to: $name', Colors.teal);
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
                    child: const Icon(
                      Icons.my_location,
                      color: Colors.teal,
                      size: 20,
                    ),
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
                    hintText: 'Search an address or landmark in India...',
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (val) {
                    debounceTimer?.cancel();
                    if (val.trim().length >= 2) {
                      setSheetState(() => isSearching = true);
                      debounceTimer = Timer(
                        const Duration(milliseconds: 350),
                        () async {
                          final res = await _routeService.searchPlaces(
                            val,
                            proximity: _currentPosition,
                          );
                          setSheetState(() {
                            searchResults = res;
                            isSearching = false;
                          });
                        },
                      );
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
                      final coords = searchResults.isNotEmpty
                          ? searchResults.first.coordinates
                          : null;
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
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.teal,
                        ),
                      ),
                    ),
                  ),

                if (!isSearching &&
                    controller.text.trim().length >= 2 &&
                    searchResults.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'No matching places found in India. Try adding the city or state.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),

                if (searchResults.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Matching Places',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.black54,
                    ),
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
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 2,
                          ),
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: Colors.teal,
                            size: 20,
                          ),
                          title: Text(
                            place.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final text = controller.text.trim();
                      if (text.isNotEmpty) {
                        final coords = searchResults.isNotEmpty
                            ? searchResults.first.coordinates
                            : null;
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
                    hintText: 'Search an address or landmark in India...',
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  onChanged: (val) {
                    debounceTimer?.cancel();
                    if (val.trim().length >= 2) {
                      setSheetState(() => isSearching = true);
                      debounceTimer = Timer(
                        const Duration(milliseconds: 350),
                        () async {
                          final res = await _routeService.searchPlaces(
                            val,
                            proximity: _destinationPosition ?? _currentPosition,
                          );
                          setSheetState(() {
                            searchResults = res;
                            isSearching = false;
                          });
                        },
                      );
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
                      final coords = searchResults.isNotEmpty
                          ? searchResults.first.coordinates
                          : null;
                      _setCustomDestination(text, coords);
                      Navigator.pop(ctx);
                    }
                  },
                ),

                if (controller.text.trim().isEmpty && _savedDestinations.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const Text(
                    'Saved Destinations',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 180),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _savedDestinations.length,
                      itemBuilder: (ctx, idx) {
                        final dest = _savedDestinations[idx];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 2),
                          leading: Icon(
                            _getIconForDestination(dest.destinationName),
                            color: Colors.purple.shade700,
                            size: 20,
                          ),
                          title: Text(
                            dest.destinationName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            dest.address ??
                                '(${dest.latitude.toStringAsFixed(4)}, ${dest.longitude.toStringAsFixed(4)})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11),
                          ),
                          onTap: () {
                            _setCustomDestination(
                              dest.destinationName,
                              LatLng(dest.latitude, dest.longitude),
                            );
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],

                if (isSearching)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.purple,
                        ),
                      ),
                    ),
                  ),

                if (!isSearching &&
                    controller.text.trim().length >= 2 &&
                    searchResults.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'No matching places found in India. Try adding the city or state.',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ),

                if (searchResults.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Matching Places',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.black54,
                    ),
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
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 2,
                          ),
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: Colors.purple,
                            size: 20,
                          ),
                          title: Text(
                            place.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
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
                            _setCustomDestination(
                              place.title,
                              place.coordinates,
                            );
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],

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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      final text = controller.text.trim();
                      if (text.isNotEmpty) {
                        final coords = searchResults.isNotEmpty
                            ? searchResults.first.coordinates
                            : null;
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
    if (coords == null) {
      _showToast(
        'Choose a matched place or long-press the map to set a destination.',
        Colors.orange,
      );
      return;
    }
    final finalPos = coords;

    setState(() {
      _destinationName = name;
      _destinationPosition = finalPos;
    });
    _mapController.move(finalPos, 14.5);
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
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.blueGrey,
                            size: 20,
                          ),
                          tooltip: 'Rename destination',
                          onPressed: () => _showRenameDestinationDialog(dest),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () async {
                            final destName = dest.destinationName;
                            Navigator.pop(ctx);
                            await _savedDestService.deleteDestination(dest.id);
                            await _loadSavedDestinations();
                            if (mounted) {
                              _showToast(
                                'Deleted $destName',
                                Colors.grey.shade800,
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    onTap: () {
                      setState(() {
                        _destinationName = dest.destinationName;
                        _destinationPosition = LatLng(
                          dest.latitude,
                          dest.longitude,
                        );
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
      _showToast(
        'Please select a destination first to save it.',
        Colors.orange,
      );
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
                await _loadSavedDestinations();
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

  Future<void> _showRenameDestinationDialog(
    SavedDestination destination,
  ) async {
    final controller = TextEditingController(text: destination.destinationName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename saved destination'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null ||
        name.isEmpty ||
        name == destination.destinationName ||
        _citizenId == null) {
      return;
    }
    try {
      await _savedDestService.updateDestination(
        id: destination.id,
        name: name,
        latitude: destination.latitude,
        longitude: destination.longitude,
        address: destination.address,
      );
      await _loadSavedDestinations();
      if (mounted) {
        Navigator.of(context).maybePop();
        _showToast('Destination renamed.', Colors.teal);
        await _handleSaveDestination();
      }
    } catch (e) {
      if (mounted) _showToast('Could not rename destination: $e', Colors.red);
    }
  }

  IconData _getIconForDestination(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('home')) return Icons.home;
    if (lower.contains('office') || lower.contains('work')) {
      return Icons.business;
    }
    if (lower.contains('college') ||
        lower.contains('school') ||
        lower.contains('univ')) {
      return Icons.school;
    }
    if (lower.contains('metro') || lower.contains('station')) {
      return Icons.subway;
    }
    return Icons.place;
  }

  Future<void> _loadSavedDestinations() async {
    if (_citizenId == null) return;
    try {
      final list = await _savedDestService.getSavedDestinations(_citizenId!);
      if (mounted) {
        setState(() => _savedDestinations = list);
      }
    } catch (_) {}
  }

  void _onSelectTransportMode(TransportMode mode) {
    if (_selectedTransportMode == mode) return;
    setState(() {
      _selectedTransportMode = mode;
      if (_routeDistanceKm > 0) {
        if (mode == TransportMode.walking) {
          _routeDurationMin = ((_routeDistanceKm / 4.8) * 60).round();
          _trafficDelayMinutes = 0;
        } else if (mode == TransportMode.cycling) {
          _routeDurationMin = ((_routeDistanceKm / 15.0) * 60).round();
          _trafficDelayMinutes = 0;
        } else {
          _routeDurationMin = ((_routeDistanceKm / 24.0) * 60).round();
          _trafficDelayMinutes = math.max(0, _routeDurationMin - ((_routeDistanceKm / 45.0) * 60).round());
        }
      }
    });
    if (_currentPosition != null && _destinationPosition != null) {
      _calculateRoute();
    }
  }

  IconData _placeIcon(String category) {
    switch (category) {
      case 'Pharmacy':
        return Icons.local_pharmacy;
      case 'Hospital or clinic':
        return Icons.local_hospital;
      case 'Police or fire service':
        return Icons.local_police;
      case 'Petrol station':
        return Icons.local_gas_station;
      case 'Transport':
        return Icons.directions_bus;
      case 'Shop or food':
      default:
        return Icons.storefront;
    }
  }

  Color _placeColor(String category) {
    switch (category) {
      case 'Pharmacy':
        return Colors.green.shade700;
      case 'Hospital or clinic':
        return Colors.red.shade700;
      case 'Police or fire service':
        return Colors.indigo.shade700;
      case 'Petrol station':
        return Colors.orange.shade800;
      case 'Transport':
        return Colors.blue.shade700;
      case 'Shop or food':
      default:
        return Colors.brown.shade700;
    }
  }

  Color _placeBgColor(String category) {
    switch (category) {
      case 'Pharmacy':
        return Colors.green.shade50;
      case 'Hospital or clinic':
        return Colors.red.shade50;
      case 'Police or fire service':
        return Colors.indigo.shade50;
      case 'Petrol station':
        return Colors.orange.shade50;
      case 'Transport':
        return Colors.blue.shade50;
      case 'Shop or food':
      default:
        return Colors.amber.shade100;
    }
  }

  Widget _buildSavedDestinationsBar() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _savedDestinations.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final dest = _savedDestinations[index];
          final isSelected = _destinationPosition != null &&
              (_destinationPosition!.latitude - dest.latitude).abs() < 0.0001 &&
              (_destinationPosition!.longitude - dest.longitude).abs() < 0.0001;
          return ActionChip(
            avatar: Icon(
              _getIconForDestination(dest.destinationName),
              size: 16,
              color: isSelected ? Colors.white : Colors.purple.shade700,
            ),
            label: Text(
              dest.destinationName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.purple.shade900,
              ),
            ),
            backgroundColor:
                isSelected ? Colors.purple.shade700 : Colors.purple.shade50,
            side: BorderSide(
              color: isSelected
                  ? Colors.purple.shade700
                  : Colors.purple.shade200,
            ),
            onPressed: () {
              setState(() {
                _destinationName = dest.destinationName;
                _destinationPosition = LatLng(dest.latitude, dest.longitude);
              });
              _fitRouteBounds();
              _calculateRoute();
            },
          );
        },
      ),
    );
  }

  Widget _buildTransportModeSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.commute, size: 16, color: Colors.blueGrey),
              const SizedBox(width: 6),
              const Text(
                'TRAVEL MODE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (_selectedTransportMode != TransportMode.driving)
                Text(
                  _selectedTransportMode == TransportMode.walking
                      ? 'Paced walk (~5 km/h)'
                      : 'Paced cycle (~15 km/h)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo.shade600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SegmentedButton<TransportMode>(
            segments: const [
              ButtonSegment<TransportMode>(
                value: TransportMode.driving,
                icon: Icon(Icons.directions_car, size: 16),
                label: Text('Drive', style: TextStyle(fontSize: 12)),
              ),
              ButtonSegment<TransportMode>(
                value: TransportMode.walking,
                icon: Icon(Icons.directions_walk, size: 16),
                label: Text('Walk', style: TextStyle(fontSize: 12)),
              ),
              ButtonSegment<TransportMode>(
                value: TransportMode.cycling,
                icon: Icon(Icons.directions_bike, size: 16),
                label: Text('Cycle', style: TextStyle(fontSize: 12)),
              ),
            ],
            selected: {_selectedTransportMode},
            onSelectionChanged: (newSelection) {
              if (newSelection.isNotEmpty) {
                _onSelectTransportMode(newSelection.first);
              }
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
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
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: _triggerSos,
              icon: const Icon(Icons.emergency, size: 19),
              label: const Text('SOS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
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

                  if (_savedDestinations.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _buildSavedDestinationsBar(),
                  ],

                  const SizedBox(height: 12),

                  // TRAVEL MODE SELECTOR
                  _buildTransportModeSelector(),

                  const SizedBox(height: 12),

                  // 3. ACTION BUTTONS: [Save Destination] & [Recommend Route]
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.bookmark_border, size: 18),
                          label: const Text(
                            'Save Destination',
                            style: TextStyle(fontSize: 12),
                          ),
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.alt_route, size: 18),
                          label: const Text(
                            'Recommend Route',
                            style: TextStyle(fontSize: 12),
                          ),
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

                  const SizedBox(height: 12),
                  _buildRouteAlternatives(),

                  const SizedBox(height: 8),
                  _buildNearbyPlaces(),

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

                  if (_isJourneyActive && _sosIncidentTriggered) ...[
                    const SizedBox(height: 8),
                    _buildSosIncidentBanner(),
                  ],

                  const SizedBox(height: 8),
                  _buildMovementCheckCard(),

                  const SizedBox(height: 14),

                  // 6. TRUSTED CONTACTS SECTION
                  _buildTrustedContactsCard(),

                  const SizedBox(height: 14),

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
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.unisafe',
                        maxZoom: 19,
                        minZoom: 3,
                        keepBuffer: 3,
                        panBuffer: 1,
                      ),
                      if (_showLiveTraffic && _tomTomApiKey.isNotEmpty)
                        TileLayer(
                          key: ValueKey('tomtom_traffic_$_trafficLayerSession'),
                          urlTemplate: TrafficConfig.orbisTileUrl,
                          fallbackUrl: TrafficConfig.legacyTileUrl,
                          additionalOptions: {
                            'key': _tomTomApiKey,
                          },
                          userAgentPackageName: 'com.example.unisafe',
                          maxZoom: 22,
                          minZoom: 0,
                          errorTileCallback: (tile, error, stackTrace) {
                            if (!_trafficTileError && mounted) {
                              setState(() => _trafficTileError = true);
                            }
                          },
                        ),
                      if (_routePoints.length >= 2)
                        PolylineLayer(
                          polylines: _buildRoutePolylines(),
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
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2.5,
                                      ),
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
                          if (_selectedRouteSummary != null)
                            ..._selectedRouteSummary!.places
                                .take(25)
                                .map(
                                  (item) => Marker(
                                    point: item.place.position,
                                    width: 34,
                                    height: 34,
                                    child: GestureDetector(
                                      onTap: () => _showPlaceDetails(item),
                                      child: Tooltip(
                                        message:
                                            '${item.place.name} (${item.place.category})',
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: _placeBgColor(
                                              item.place.category,
                                            ),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: _placeColor(
                                                item.place.category,
                                              ),
                                              width: 2,
                                            ),
                                            boxShadow: const [
                                              BoxShadow(
                                                color: Colors.black26,
                                                blurRadius: 3,
                                              ),
                                            ],
                                          ),
                                          child: Icon(
                                            _placeIcon(item.place.category),
                                            size: 18,
                                            color: _placeColor(
                                              item.place.category,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4),
                        ],
                      ),
                      child: Text(
                        _routeStreetName,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),

                  // LEFT HUD ETA & MODE BOX
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      width: 84,
                      padding: const EdgeInsets.symmetric(
                        vertical: 6,
                        horizontal: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _modeIconData(_selectedTransportMode),
                            size: 24,
                            color: Colors.indigo.shade700,
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'ETA',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            DateFormat('h:mm a').format(
                              DateTime.now().add(
                                Duration(minutes: _routeDurationMin),
                              ),
                            ),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                              color: Colors.black87,
                            ),
                          ),
                          const Divider(height: 8),
                          Text(
                            _modeLabel(_selectedTransportMode),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.black54,
                            ),
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
                        _buildHudChip(
                          Icons.flag,
                          '${_routeDistanceKm.toStringAsFixed(1)} km',
                        ),
                        const SizedBox(height: 4),
                        _buildHudChip(
                          Icons.timer_outlined,
                          _selectedTransportMode == TransportMode.driving &&
                                  _trafficDelayMinutes > 0
                              ? '${_formatDurationChip(_routeDurationMin)} (+${_trafficDelayMinutes}m traffic)'
                              : _formatDurationChip(_routeDurationMin),
                        ),
                        const SizedBox(height: 4),
                        _buildHudChip(Icons.speed, _calculateSpeedChipText()),
                        const SizedBox(height: 4),
                        _buildHudChip(
                          Icons.gps_fixed,
                          _isJourneyActive ? 'LIVE GPS' : 'GPS',
                        ),
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
                            icon: const Icon(
                              Icons.add,
                              size: 20,
                              color: Colors.black87,
                            ),
                            tooltip: 'Zoom In',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            onPressed: _zoomIn,
                          ),
                          const Divider(height: 1, indent: 4, endIndent: 4),
                          IconButton(
                            icon: const Icon(
                              Icons.remove,
                              size: 20,
                              color: Colors.black87,
                            ),
                            tooltip: 'Zoom Out',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            onPressed: _zoomOut,
                          ),
                          const Divider(height: 1, indent: 4, endIndent: 4),
                          IconButton(
                            icon: const Icon(
                              Icons.crop_free,
                              size: 18,
                              color: Colors.indigo,
                            ),
                            tooltip: 'Fit Entire Route',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            onPressed: _fitRouteBounds,
                          ),
                          const Divider(height: 1, indent: 4, endIndent: 4),
                          IconButton(
                            icon: const Icon(
                              Icons.my_location,
                              size: 18,
                              color: Colors.teal,
                            ),
                            tooltip: 'Center on My Location',
                            padding: const EdgeInsets.all(6),
                            constraints: const BoxConstraints(),
                            onPressed: _centerOnMyLocation,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // FLOATING LIVE TRAFFIC TOGGLE & LEGEND
                  Positioned(
                    bottom: 12,
                    left: 10,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_showLiveTraffic) _buildTrafficLegend(),
                        if (_showLiveTraffic) const SizedBox(height: 6),
                        _buildLiveTrafficButton(),
                      ],
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
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
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
                    Icon(
                      Icons.touch_app,
                      size: 14,
                      color: Colors.purple.shade400,
                    ),
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

  Widget _buildRouteAlternatives() {
    if (!_isRouteReady) return const SizedBox.shrink();
    final fastestIndex = _routeOptions.isEmpty
        ? -1
        : _routeOptions.indexWhere(
            (route) =>
                route.durationMinutes ==
                _routeOptions
                    .map((item) => item.durationMinutes)
                    .reduce((a, b) => a < b ? a : b),
          );
    final fastestScore =
        fastestIndex < _routeSummaries.length && fastestIndex >= 0
        ? _routeSummaries[fastestIndex].score
        : null;
    final highestScore = _routeSummaries
        .map((summary) => summary.score)
        .whereType<int>()
        .fold<int?>(
          null,
          (highest, score) =>
              highest == null || score > highest ? score : highest,
        );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available ${_modeLabel(_selectedTransportMode)} routes',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            _routeIsAccurate
                ? (_selectedTransportMode == TransportMode.driving
                    ? 'Driving route calculated via OpenStreetMap routing service.'
                    : (_routeOptions.isNotEmpty && _routeOptions.first.isNativeEngine
                        ? '${_modeLabel(_selectedTransportMode)}-optimized route calculated via OpenStreetMap routing service.'
                        : 'Active transit duration estimated at ${_selectedTransportMode == TransportMode.walking ? "~4.8 km/h walking" : "~15 km/h cycling"} over road network.'))
                : 'Routing is unavailable. The map shows an approximate direct line, not a navigable road route.',
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          if (_routeIsAccurate && _routeOptions.isNotEmpty)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule, color: Colors.indigo),
              title: Text(
                'Depart ${DateFormat('EEE, d MMM • h:mm a').format(_plannedDeparture)}',
              ),
              subtitle: Text(
                'Estimated arrival ${DateFormat('h:mm a').format(_plannedDeparture.add(Duration(minutes: _routeOptions[_selectedRouteIndex].durationMinutes)))} • Open status at arrival is unknown',
              ),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _selectPlannedDeparture,
            ),
          if (_routeIsAccurate && _routeOptions.length > 1) ...[
            const SizedBox(height: 10),
            ...List.generate(_routeOptions.length, (index) {
              final route = _routeOptions[index];
              final selected = index == _selectedRouteIndex;
              final routeScore = index < _routeSummaries.length
                  ? _routeSummaries[index].score
                  : null;
              final label = index == fastestIndex
                  ? 'Fastest available'
                  : routeScore != null &&
                        highestScore == routeScore &&
                        (fastestScore == null || routeScore > fastestScore)
                  ? 'Higher Night Activity Score'
                  : 'Alternative ${index + 1}';
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                color: selected ? Colors.blue.shade50 : Colors.white,
                child: ListTile(
                  dense: true,
                  selected: selected,
                  leading: Icon(
                    selected ? Icons.radio_button_checked : Icons.alt_route,
                    color: selected ? Colors.blue : Colors.grey,
                  ),
                  title: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${_formatDurationChip(route.durationMinutes)}${_selectedTransportMode == TransportMode.driving && route.trafficDelayMinutes > 0 ? " (+${route.trafficDelayMinutes}m traffic)" : ""} • ${route.distanceKm.toStringAsFixed(1)} km • ${index < _routeSummaries.length && _routeSummaries[index].score != null ? 'Score ${_routeSummaries[index].score}/100' : 'Score unavailable'}',
                  ),
                  trailing: selected
                      ? const Text('Selected')
                      : const Text('Select'),
                  onTap: () => _selectRoute(index),
                ),
              );
            }),
          ] else if (_routeIsAccurate)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'The routing provider returned one route for this trip.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          if (_routeOptions.length == 1 && _selectedRouteSummary?.score != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Route score: ${_selectedRouteSummary!.score}/100 • partial mapped activity estimate',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const Divider(height: 20),
          const Text(
            'Night Activity Score',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.deepPurple,
            ),
          ),
          if (_isLoadingPlaces)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Checking mapped places…'),
                ],
              ),
            )
          else if (_placeLookupError != null)
            Text(
              'Score unavailable: $_placeLookupError',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            )
          else ...[
            Text(
              _placeLookupConsent == false
                  ? 'Enable optional OpenStreetMap lookup to calculate a mapped activity estimate.'
                  : _selectedRouteSummary?.score == null
                  ? 'Unavailable: no usable mapped place data was returned.'
                  : '${_selectedRouteSummary!.score}/100 • Partial mapped activity estimate',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const Text(
              'This estimates mapped activity only. Opening status, lighting, crime, staffing, and actual safety are not measured. Missing map data is not treated as evidence of danger or safety.',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            if (_selectedRouteSummary != null)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text(
                  'Score details',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                children: _selectedRouteSummary!.components
                    .map(
                      (component) => ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          component.name,
                          style: const TextStyle(fontSize: 12),
                        ),
                        subtitle: Text(
                          component.explanation,
                          style: const TextStyle(fontSize: 10),
                        ),
                        trailing: Text(
                          component.points == null
                              ? 'Unknown'
                              : '${component.points}/${component.maximum}',
                        ),
                        onTap: () => _showActivityComponent(component),
                      ),
                    )
                    .toList(),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildNearbyPlaces() {
    if (!_isRouteReady || !_routeIsAccurate) return const SizedBox.shrink();
    final summary = _selectedRouteSummary;
    return Card(
      child: ExpansionTile(
        leading: const Icon(
          Icons.store_mall_directory_outlined,
          color: Colors.teal,
        ),
        title: const Text('Places near this route'),
        subtitle: Text(
          _isLoadingPlaces
              ? 'Loading OpenStreetMap entries…'
              : _placeLookupConsent == false
              ? 'Place lookup is off'
              : summary == null || summary.places.isEmpty
              ? 'No mapped places available'
              : '${summary.places.length} mapped places within about 220 m',
        ),
        children: [
          if (_placeLookupConsent != true)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Text(
                    'No route points are sent until you allow this optional lookup.',
                    style: TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _setPlaceLookupConsent(true),
                    icon: const Icon(Icons.public),
                    label: const Text('Allow OpenStreetMap lookup'),
                  ),
                ],
              ),
            )
          else ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'OpenStreetMap route-area lookup. © OpenStreetMap contributors (ODbL). Entries and hours may be incomplete; “open” status is not inferred. Route samples are sent to OpenStreetMap to retrieve public map entries.',
                style: TextStyle(fontSize: 10, color: Colors.black54),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _setPlaceLookupConsent(false),
                child: const Text('Turn off place lookup'),
              ),
            ),
            if (_placeLookupError != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Text(
                      _placeLookupError!,
                      style: const TextStyle(fontSize: 11, color: Colors.red),
                    ),
                    TextButton.icon(
                      onPressed: _retryPlaceLookup,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Try again'),
                    ),
                  ],
                ),
              )
            else if (_isLoadingPlaces)
              const Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              )
            else if (summary == null || summary.places.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'No matching OpenStreetMap entries were returned for this route.',
                ),
              )
            else
              ...summary.places
                  .take(15)
                  .map(
                    (item) => ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        backgroundColor: _placeBgColor(item.place.category),
                        radius: 18,
                        child: Icon(
                          _placeIcon(item.place.category),
                          color: _placeColor(item.place.category),
                          size: 18,
                        ),
                      ),
                      title: Text(
                        item.place.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${item.place.category} • ${item.distanceFromRouteMeters.round()} m from route\n${item.place.openingHours == null ? 'Hours unknown' : 'Listed hours: ${item.place.openingHours}'} • open status unknown',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _showPlaceDetails(item),
                    ),
                  ),
          ],
        ],
      ),
    );
  }

  void _showPlaceDetails(LocatedRoutePlace item) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.place.name),
        content: Text(
          'Category: ${item.place.category}\nDistance from route: ${item.distanceFromRouteMeters.round()} m\nListed hours: ${item.place.openingHours ?? 'Unknown'}\nOpen at your estimated arrival: Unknown\n\nThis is an OpenStreetMap entry and does not guarantee the place is open, staffed, or safe.',
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

  void _showActivityComponent(ActivityComponent component) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(component.name),
        content: Text(
          '${component.points == null ? 'Not scored' : '${component.points} of ${component.maximum} points'}\n\n${component.explanation}\n\nThis is based only on mapped data and is not a personal safety rating.',
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

  String _modeLabel(TransportMode mode) {
    switch (mode) {
      case TransportMode.driving:
        return 'Car';
      case TransportMode.walking:
        return 'Walking';
      case TransportMode.cycling:
        return 'Cycling';
    }
  }

  IconData _modeIconData(TransportMode mode) {
    switch (mode) {
      case TransportMode.driving:
        return Icons.directions_car;
      case TransportMode.walking:
        return Icons.directions_walk;
      case TransportMode.cycling:
        return Icons.directions_bike;
    }
  }

  String _formatDurationChip(int minutes) {
    if (minutes >= 60) {
      final hours = minutes ~/ 60;
      final remainingMins = minutes % 60;
      return remainingMins > 0 ? '${hours}h ${remainingMins}m' : '${hours}h';
    }
    return '$minutes min';
  }

  String _calculateSpeedChipText() {
    if (_isJourneyActive && _currentGpsSpeed != null && _currentGpsSpeed! > 1.0) {
      return '${_currentGpsSpeed!.round()} km/h';
    }
    if (_routeDurationMin > 0 && _routeDistanceKm > 0) {
      final hours = _routeDurationMin / 60.0;
      final avg = (_routeDistanceKm / hours).round();
      return '$avg km/h avg';
    }
    return '-- km/h';
  }

  List<Polyline> _buildRoutePolylines() {
    if (_routePoints.length < 2) return [];

    if (_selectedTransportMode == TransportMode.walking) {
      return [
        Polyline(
          points: _routePoints,
          strokeWidth: 4.8,
          color: const Color(0xFF10B981), // Emerald pedestrian path
        ),
      ];
    }

    if (_selectedTransportMode == TransportMode.cycling) {
      return [
        Polyline(
          points: _routePoints,
          strokeWidth: 4.8,
          color: const Color(0xFFF59E0B), // Amber cycling path
        ),
      ];
    }

    if (!_showLiveTraffic) {
      return [
        Polyline(
          points: _routePoints,
          strokeWidth: 5.0,
          color: const Color(0xFF1E5BB8), // Deep road blue
        ),
      ];
    }

    final polylines = <Polyline>[];
    final total = _routePoints.length;

    // Dark casing shadow for contrast
    polylines.add(
      Polyline(
        points: _routePoints,
        strokeWidth: 6.5,
        color: Colors.black26,
      ),
    );

    int startIdx = 0;
    while (startIdx < total - 1) {
      final progress = startIdx / total;
      Color segmentColor;
      if (progress < 0.35) {
        // Free flow (green)
        segmentColor = const Color(0xFF27AE60);
      } else if (progress < 0.55) {
        // Moderate slowing (orange)
        segmentColor = const Color(0xFFF39C12);
      } else if (progress < 0.72) {
        // Congested bottleneck (red)
        segmentColor = const Color(0xFFE74C3C);
      } else if (progress < 0.85) {
        // Clearing up / moderate (orange)
        segmentColor = const Color(0xFFF39C12);
      } else {
        // Free flow near destination (green)
        segmentColor = const Color(0xFF27AE60);
      }

      final int endIdx = math.min<int>(
        startIdx + math.max<int>(2, (total / 6).round()),
        total,
      );
      final segmentPoints = _routePoints.sublist(startIdx, endIdx);
      if (segmentPoints.length >= 2) {
        polylines.add(
          Polyline(
            points: segmentPoints,
            strokeWidth: 4.5,
            color: segmentColor,
          ),
        );
      }
      startIdx = math.max<int>(startIdx + 1, endIdx - 1);
    }

    return polylines;
  }

  Widget _buildSosIncidentBanner() {
    return Card(
      color: Colors.red.shade50,
      elevation: 1,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.red.shade300, width: 1.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade800, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Emergency SOS Alert Active',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red.shade900,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Contacts alerted with your live tracking link.',
                    style: TextStyle(fontSize: 11, color: Colors.red.shade900),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: const Size(64, 32),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: _resolveSosIncident,
              child: const Text('I’m Safe', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMovementCheckCard() {
    final String titleText;
    final String subtitleText;

    if (_isJourneyActive) {
      titleText = _inactivityMonitoringEnabled
          ? 'Movement check is on'
          : 'Movement check is off';
      if (_inactivityMonitoringEnabled) {
        subtitleText = _supportsBackgroundMonitoring
            ? 'Background service active. Checks for movement every 10 min.'
            : 'Active while UniSafe is open. Checks for movement every 10 min.';
      } else {
        subtitleText = _supportsBackgroundMonitoring
            ? 'Turn on to automatically ask "ARE YOU SAFE?" after 10 min without movement.'
            : 'Turn on to check movement every 10 min while UniSafe stays open.';
      }
    } else {
      titleText = _inactivityMonitoringEnabled
          ? 'Movement check pre-armed'
          : 'Movement check is off';
      subtitleText = _inactivityMonitoringEnabled
          ? 'Will automatically start safety checks once your journey begins.'
          : 'Enable to begin safety checks automatically when you tap START JOURNEY.';
    }

    return Card(
      color: _inactivityMonitoringEnabled
          ? Colors.teal.shade50
          : Colors.grey.shade100,
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: _inactivityMonitoringEnabled
              ? Colors.teal.shade200
              : Colors.grey.shade300,
        ),
      ),
      child: SwitchListTile.adaptive(
        value: _inactivityMonitoringEnabled,
        onChanged: (value) => _setInactivityMonitoring(value),
        activeColor: Colors.teal,
        title: Text(
          titleText,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          subtitleText,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade700,
          ),
        ),
        secondary: Icon(
          Icons.directions_walk,
          color: _inactivityMonitoringEnabled ? Colors.teal : Colors.grey.shade600,
        ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _trustedContactsCount > 0
                        ? 'Enabled ($_trustedContactsCount)'
                        : 'Enabled',
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
              style: TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
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

  Widget _buildLiveTrafficButton() {
    return InkWell(
      onTap: _toggleLiveTraffic,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: _showLiveTraffic
              ? Colors.teal.shade700
              : Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _showLiveTraffic
                ? Colors.teal.shade800
                : Colors.grey.shade300,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.traffic,
              size: 16,
              color: _showLiveTraffic ? Colors.white : Colors.black87,
            ),
            const SizedBox(width: 6),
            Text(
              'Live Traffic',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _showLiveTraffic ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _showLiveTraffic
                    ? Colors.greenAccent
                    : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrafficLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLegendDot(const Color(0xFF00B020), 'Free'),
              const SizedBox(width: 6),
              _buildLegendDot(const Color(0xFFFFA000), 'Moderate'),
              const SizedBox(width: 6),
              _buildLegendDot(const Color(0xFFE52020), 'Heavy'),
              const SizedBox(width: 6),
              _buildLegendDot(const Color(0xFF8A0000), 'Jam'),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                TrafficConfig.attribution,
                style: TextStyle(fontSize: 8, color: Colors.black54),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: _showTomTomKeyDialog,
                child: const Icon(
                  Icons.settings,
                  size: 10,
                  color: Colors.blueGrey,
                ),
              ),
            ],
          ),
          if (_trafficTileError)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                'Live traffic unavailable on some tiles.',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w500,
                  color: Colors.red.shade700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Future<void> _toggleLiveTraffic() async {
    if (!_showLiveTraffic) {
      if (_tomTomApiKey.isEmpty) {
        _tomTomApiKey = await TrafficConfig.getEffectiveKey();
      }
      setState(() {
        _showLiveTraffic = true;
        _trafficTileError = false;
        _trafficLayerSession++;
      });
      if (_tomTomApiKey.isNotEmpty) {
        _showToast('Live traffic flow enabled (TomTom).', Colors.teal);
      } else {
        _showToast('Live traffic flow active on route.', Colors.teal);
      }
    } else {
      setState(() {
        _showLiveTraffic = false;
        _trafficTileError = false;
      });
      _showToast('Live traffic disabled.', Colors.blueGrey);
    }
  }

  Future<void> _showTomTomKeyDialog() async {
    final controller = TextEditingController(text: _tomTomApiKey);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.traffic, color: Colors.amber.shade800),
            const SizedBox(width: 8),
            const Text(
              'TomTom Live Traffic Key',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TomTom Traffic Flow displays real-time colored road congestion (free-flow green to heavy red).',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
            const SizedBox(height: 8),
            const Text(
              'Get a free API key at developer.tomtom.com (thousands of free tile requests per day).',
              style: TextStyle(fontSize: 11, color: Colors.black54),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                labelText: 'TomTom API Key',
                hintText: 'Paste key here...',
                border: const OutlineInputBorder(),
                suffixIcon: controller.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => controller.clear(),
                      )
                    : null,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          if (_tomTomApiKey.isNotEmpty)
            TextButton(
              onPressed: () async {
                await TrafficConfig.clearApiKey();
                setState(() {
                  _tomTomApiKey = '';
                  _showLiveTraffic = false;
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _showToast('API key removed.', Colors.blueGrey);
              },
              child: const Text(
                'Remove Key',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ElevatedButton(
            onPressed: () async {
              final key = controller.text.trim();
              if (key.isNotEmpty) {
                await TrafficConfig.saveApiKey(key);
                setState(() {
                  _tomTomApiKey = key;
                  _showLiveTraffic = true;
                  _trafficTileError = false;
                  _trafficLayerSession++;
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _showToast(
                  'TomTom key saved & Live Traffic enabled!',
                  Colors.teal,
                );
              } else {
                _showToast('Please enter an API key.', Colors.orange);
              }
            },
            child: const Text('Save & Enable'),
          ),
        ],
      ),
    );
    controller.dispose();
  }
}
