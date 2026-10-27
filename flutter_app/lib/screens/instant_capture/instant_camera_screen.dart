import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../services/instant_capture_service.dart';
import 'instant_gallery_screen.dart';

class InstantCameraScreen extends StatefulWidget {
  const InstantCameraScreen({super.key});

  @override
  State<InstantCameraScreen> createState() => _InstantCameraScreenState();
}

class _InstantCameraScreenState extends State<InstantCameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isCameraInitialized = false;
  bool _isCapturing = false;
  String? _errorMessage;

  // Zoom
  double _minZoom = 1.0;
  double _maxZoom = 1.0;
  double _currentZoom = 1.0;
  double _baseZoom = 1.0;

  // Flash
  FlashMode _flashMode = FlashMode.off;

  // Location requirement
  bool _isCheckingLocation = true;
  bool _hasLocation = false;
  Position? _currentPosition;
  String? _locationError;
  Timer? _locationTimer;

  // Drafts gallery preview
  int _draftCount = 0;
  Uint8List? _latestDraftBytes;

  // Visual capture flash animation & saved toast
  bool _showShutterFlash = false;
  bool _showSavedToast = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
    _checkLocation();
    _loadDraftInfo();
    // Periodically re-check location in case user turns GPS on
    _locationTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_hasLocation && mounted) {
        _checkLocation(silent: true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _controller?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
      _checkLocation();
    }
  }

  Future<void> _loadDraftInfo() async {
    final drafts = await InstantCaptureService.instance.getDrafts();
    if (mounted) {
      setState(() {
        _draftCount = drafts.length;
        _latestDraftBytes = drafts.isNotEmpty ? drafts.first.imageBytes : null;
      });
    }
  }

  Future<void> _checkLocation({bool silent = false}) async {
    if (!silent) {
      setState(() => _isCheckingLocation = true);
    }
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _hasLocation = false;
            _currentPosition = null;
            _locationError = 'GPS service is turned off';
            _isCheckingLocation = false;
          });
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            setState(() {
              _hasLocation = false;
              _currentPosition = null;
              _locationError = 'Location permission denied';
              _isCheckingLocation = false;
            });
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _hasLocation = false;
            _currentPosition = null;
            _locationError = 'Location permission permanently denied';
            _isCheckingLocation = false;
          });
        }
        return;
      }

      // Permission granted and service enabled -> fetch position
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 7),
        ),
      );

      if (mounted) {
        setState(() {
          _hasLocation = true;
          _currentPosition = pos;
          _locationError = null;
          _isCheckingLocation = false;
        });
      }
    } catch (e) {
      // Fallback to last known position if current times out
      try {
        final lastPos = await Geolocator.getLastKnownPosition();
        if (lastPos != null && mounted) {
          setState(() {
            _hasLocation = true;
            _currentPosition = lastPos;
            _locationError = null;
            _isCheckingLocation = false;
          });
          return;
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _hasLocation = false;
          _currentPosition = null;
          _locationError = 'Unable to acquire GPS';
          _isCheckingLocation = false;
        });
      }
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        if (mounted) {
          setState(() => _errorMessage = 'No camera found on this device');
        }
        return;
      }

      final backIndex = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.back);
      _selectedCameraIndex = backIndex != -1 ? backIndex : 0;
      await _startController(_cameras[_selectedCameraIndex]);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to open camera: $e');
      }
    }
  }

  Future<void> _startController(CameraDescription camera) async {
    final controller = CameraController(
      camera,
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );

    try {
      await controller.initialize();
      _minZoom = await controller.getMinZoomLevel();
      _maxZoom = (await controller.getMaxZoomLevel()).clamp(1.0, 8.0);
      _currentZoom = _minZoom;

      if (!kIsWeb) {
        try {
          await controller.setFlashMode(_flashMode);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _controller = controller;
          _isCameraInitialized = true;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Error initializing camera: $e');
      }
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized || kIsWeb) return;
    HapticFeedback.selectionClick();
    FlashMode next;
    if (_flashMode == FlashMode.off) {
      next = FlashMode.auto;
    } else if (_flashMode == FlashMode.auto) {
      next = FlashMode.torch;
    } else {
      next = FlashMode.off;
    }

    try {
      await _controller!.setFlashMode(next);
      setState(() => _flashMode = next);
    } catch (_) {
      try {
        await _controller!.setFlashMode(FlashMode.off);
        setState(() => _flashMode = FlashMode.off);
      } catch (_) {}
    }
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing) return;

    // Check location requirement
    if (!_hasLocation || _currentPosition == null) {
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Please turn on your location to take photos',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: const Color(0xFF1E293B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'Turn On',
            textColor: const Color(0xFF38BDF8),
            onPressed: () => _checkLocation(),
          ),
        ),
      );
      _checkLocation();
      return;
    }

    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_controller!.value.isTakingPicture) return;

    HapticFeedback.mediumImpact();
    setState(() => _isCapturing = true);

    try {
      // Trigger visual shutter flash
      setState(() => _showShutterFlash = true);
      Future.delayed(const Duration(milliseconds: 90), () {
        if (mounted) setState(() => _showShutterFlash = false);
      });

      final xfile = await _controller!.takePicture();
      final bytes = await xfile.readAsBytes();

      final newDraft = InstantCaptureDraft(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        imageBytes: bytes,
        imagePath: xfile.path,
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        capturedAt: DateTime.now(),
      );

      await InstantCaptureService.instance.saveDraft(newDraft);

      if (mounted) {
        setState(() {
          _isCapturing = false;
          _draftCount++;
          _latestDraftBytes = bytes;
          _showSavedToast = true;
        });

        Future.delayed(const Duration(milliseconds: 2200), () {
          if (mounted) setState(() => _showSavedToast = false);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  void _openGallery() {
    HapticFeedback.lightImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const InstantGalleryScreen()),
    ).then((_) => _loadDraftInfo());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          // Drag right-to-left (swipe back to Home)
          if (details.primaryVelocity != null && details.primaryVelocity! < -250) {
            Navigator.of(context).pop();
          }
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Camera Viewfinder
            if (_isCameraInitialized && _controller != null)
              _buildViewfinder()
            else if (_errorMessage != null)
              _buildErrorView()
            else
              const Center(
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
              ),

            // Shutter Flash Animation Overlay
            if (_showShutterFlash)
              Container(color: Colors.white.withValues(alpha: 0.9)),

            // Top Header Bar (Close, GPS Status Pill, Flash)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(),
            ),

            // Top Saved Pill Notification
            if (_showSavedToast)
              Positioned(
                top: MediaQuery.of(context).padding.top + 54,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 15),
                        SizedBox(width: 7),
                        Text(
                          'Saved to Safety Gallery',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Bottom Controls (Zoom Indicator, Gallery, Shutter Button, Switch Camera)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomControls(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewfinder() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        final screenAspectRatio = screenWidth / screenHeight;

        final previewSize = _controller!.value.previewSize;
        double previewRatio = 9 / 16;
        if (previewSize != null) {
          previewRatio = previewSize.height / previewSize.width;
        }

        double scale = 1.0;
        if (previewRatio < screenAspectRatio) {
          scale = screenAspectRatio / previewRatio;
        } else {
          scale = previewRatio / screenAspectRatio;
        }

        return GestureDetector(
          onScaleStart: (_) => _baseZoom = _currentZoom,
          onScaleUpdate: (details) {
            final newZoom = (_baseZoom * details.scale).clamp(_minZoom, _maxZoom);
            if (newZoom != _currentZoom) {
              _currentZoom = newZoom;
              _controller?.setZoomLevel(newZoom);
              setState(() {});
            }
          },
          child: ClipRect(
            child: Transform.scale(
              scale: scale,
              child: Center(
                child: AspectRatio(
                  aspectRatio: previewRatio,
                  child: CameraPreview(_controller!),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Close Button
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: const Center(
                  child: Icon(LucideIcons.x, color: Colors.white, size: 20),
                ),
              ),
            ),

            // Flash Toggle
            if (!kIsWeb)
              GestureDetector(
                onTap: _toggleFlash,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _flashMode != FlashMode.off
                          ? Colors.amber.withValues(alpha: 0.6)
                          : Colors.white.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      _flashMode == FlashMode.torch || _flashMode == FlashMode.always
                          ? Icons.flash_on_rounded
                          : _flashMode == FlashMode.auto
                              ? Icons.flash_auto_rounded
                              : Icons.flash_off_rounded,
                      color: _flashMode == FlashMode.off ? Colors.white70 : Colors.amber,
                      size: 20,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(width: 42),
          ],
        ),
      ),
    );
  }



  Widget _buildBottomControls() {
    final bool canShoot = _hasLocation && !_isCapturing && _isCameraInitialized;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Sleek Zoom Toggle Pill (1.0x / 2.0x)
            if (_isCameraInitialized && _controller != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    final targetZoom = _currentZoom > 1.4 ? 1.0 : 2.0;
                    _controller?.setZoomLevel(targetZoom);
                    setState(() => _currentZoom = targetZoom);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: Text(
                      '${_currentZoom.toStringAsFixed(1)}x',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),

            // 2. Control Row: Gallery (Left) | Shutter (Center) | Switch Camera (Right)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Gallery Thumbnail Button
                GestureDetector(
                  onTap: _openGallery,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.45),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: _latestDraftBytes != null
                              ? Image.memory(_latestDraftBytes!, fit: BoxFit.cover)
                              : const Center(
                                  child: Icon(LucideIcons.images, color: Colors.white, size: 22),
                                ),
                        ),
                      ),
                      // Count badge
                      if (_draftCount > 0)
                        Positioned(
                          top: -5,
                          right: -5,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white, width: 1.2),
                            ),
                            child: Text(
                              _draftCount > 99 ? '99+' : '$_draftCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Shutter Button (Clean Solid White Camera Shutter)
                GestureDetector(
                  onTap: _capturePhoto,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 3.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isCapturing ? Colors.grey.shade400 : Colors.white,
                        ),
                        child: _isCapturing
                            ? const Center(
                                child: SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.black),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),

                // Switch Camera Button
                if (_cameras.length > 1)
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
                      _startController(_cameras[_selectedCameraIndex]);
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.45),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
                      ),
                      child: const Center(
                        child: Icon(LucideIcons.switchCamera, color: Colors.white, size: 22),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 52),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.cameraOff, size: 50, color: Colors.white54),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Camera Unavailable',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _initCamera,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
              child: const Text('Retry Camera', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
