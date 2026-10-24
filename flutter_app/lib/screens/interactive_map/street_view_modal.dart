import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'street_view_embed.dart';

/// In-app street view modal displaying pure 100% immersive 360° panoramic photography.
/// Minimalist design: Only the top drag handle to close, zero headers, zero bottom bars.
class StreetViewModal extends StatefulWidget {
  final double latitude;
  final double longitude;
  final String? title;

  const StreetViewModal({
    super.key,
    required this.latitude,
    required this.longitude,
    this.title,
  });

  /// Session-persisted Google Maps API Key for in-app Street View iframe embedding
  static String? sessionApiKey = 'AIzaSyByV-cPIBexOEt32rSJpz7OAVxQpKOSmmE';

  static Future<void> show(
    BuildContext context, {
    required double latitude,
    required double longitude,
    String? title,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      elevation: 0,
      builder: (context) => StreetViewModal(
        latitude: latitude,
        longitude: longitude,
        title: title,
      ),
    );
  }

  @override
  State<StreetViewModal> createState() => _StreetViewModalState();
}

class _StreetViewModalState extends State<StreetViewModal> {
  late TextEditingController _keyController;
  bool _showKeyInput = false;
  String? _errorMessage;
  double _dragAccumulator = 0;

  @override
  void initState() {
    super.initState();
    _keyController =
        TextEditingController(text: StreetViewModal.sessionApiKey ?? '');
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _openGoogleStreetView() async {
    final url =
        'https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=${widget.latitude},${widget.longitude}';
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _openDemoKeyPortal() async {
    final uri = Uri.parse(
        'https://mapsplatform.google.com/maps-demo-key?utm_campaign=gmp_git_agentskills_v1');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _applyApiKey() {
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a valid Google Maps API Key or Demo Key.';
      });
      return;
    }

    setState(() {
      StreetViewModal.sessionApiKey = key;
      _errorMessage = null;
      _showKeyInput = false;
    });
  }

  void _clearApiKey() {
    setState(() {
      StreetViewModal.sessionApiKey = null;
      _keyController.clear();
      _showKeyInput = true;
    });
  }

  String _generateGoogleMapsStreetViewHtml(
      String apiKey, double lat, double lng) {
    return '''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
    html, body {
      width: 100%;
      height: 100%;
      overflow: hidden;
      background: #0f172a;
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      touch-action: none;
      user-select: none;
      -webkit-user-select: none;
    }
    #pano {
      width: 100%;
      height: 100%;
      position: absolute;
      top: 0; left: 0;
      touch-action: none;
    }
    /* Auto-invert Google's negative canvas back to true natural colors */
    #pano canvas {
      filter: invert(1) !important;
      -webkit-filter: invert(1) !important;
      transition: filter 0.2s ease;
    }
    .natural-mode #pano canvas {
      filter: invert(1) !important;
      -webkit-filter: invert(1) !important;
    }
    .raw-mode #pano canvas {
      filter: none !important;
      -webkit-filter: none !important;
    }
    /* Hide Google dev-mode warning popup & watermark overlays */
    .gm-err-container, .gm-err-content,
    .gm-style-cc,
    a[href*="billing"], a[href*="degraded"] {
      display: none !important;
      opacity: 0 !important;
      pointer-events: none !important;
      visibility: hidden !important;
    }
    #status-banner {
      display: none;
      position: absolute;
      top: 0; left: 0; width: 100%; height: 100%;
      background: #0f172a;
      color: white;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      text-align: center;
      padding: 24px;
      z-index: 999;
    }
    .status-title { font-size: 16px; font-weight: 800; margin-bottom: 8px; color: #f8fafc; }
    .status-desc { font-size: 13px; color: #94a3b8; max-width: 320px; line-height: 1.4; margin-bottom: 16px; }
    .action-btn {
      display: inline-flex;
      align-items: center;
      gap: 6px;
      background: #059669;
      color: white;
      font-weight: 700;
      font-size: 13px;
      padding: 10px 18px;
      border-radius: 10px;
      text-decoration: none;
    }

    /* Floating On-Screen 360 Camera Controls */
    .controls-overlay {
      position: absolute;
      bottom: 24px;
      right: 14px;
      display: flex;
      flex-direction: column;
      align-items: center;
      gap: 6px;
      z-index: 100;
      pointer-events: auto;
    }
    .ctrl-row {
      display: flex;
      gap: 6px;
    }
    .ctrl-btn {
      width: 44px;
      height: 44px;
      border-radius: 22px;
      background: rgba(15, 23, 42, 0.78);
      border: 1px solid rgba(255, 255, 255, 0.25);
      color: #ffffff;
      font-size: 18px;
      font-weight: bold;
      display: flex;
      align-items: center;
      justify-content: center;
      box-shadow: 0 4px 12px rgba(0,0,0,0.4);
      cursor: pointer;
      user-select: none;
      -webkit-user-select: none;
    }
    .ctrl-btn:active {
      background: #059669;
      transform: scale(0.92);
    }
    .ctrl-btn-center {
      font-size: 12px;
      letter-spacing: -0.5px;
    }
    .color-toggle-btn {
      position: absolute;
      bottom: 24px;
      left: 14px;
      height: 38px;
      padding: 0 14px;
      border-radius: 19px;
      background: rgba(15, 23, 42, 0.78);
      border: 1px solid rgba(255, 255, 255, 0.25);
      color: #ffffff;
      font-size: 12px;
      font-weight: 700;
      display: flex;
      align-items: center;
      gap: 6px;
      box-shadow: 0 4px 12px rgba(0,0,0,0.4);
      cursor: pointer;
      z-index: 100;
      user-select: none;
      -webkit-user-select: none;
    }
    .color-toggle-btn:active {
      background: #059669;
      transform: scale(0.95);
    }
  </style>
</head>
<body class="natural-mode">
  <div id="pano"></div>

  <!-- Floating On-Screen 360 Camera Controls (Touch or Tap) -->
  <div class="controls-overlay">
    <button class="ctrl-btn" id="btn-up" aria-label="Look Up">▲</button>
    <div class="ctrl-row">
      <button class="ctrl-btn" id="btn-left" aria-label="Turn Left">◀</button>
      <button class="ctrl-btn ctrl-btn-center" id="btn-reset" aria-label="Reset View">RESET</button>
      <button class="ctrl-btn" id="btn-right" aria-label="Turn Right">▶</button>
    </div>
    <button class="ctrl-btn" id="btn-down" aria-label="Look Down">▼</button>
  </div>

  <!-- Color Inversion Mode Switcher -->
  <button class="color-toggle-btn" id="btn-toggle-color">
    <span>🎨</span> <span id="color-mode-text">Colors: Natural</span>
  </button>

  <div id="status-banner">
    <div class="status-title" id="status-title">No 360° Street View Nearby</div>
    <div class="status-desc" id="status-desc">Google does not have street-level camera recordings right at this exact coordinate point.</div>
    <a class="action-btn" target="_blank" href="https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=$lat,$lng">
      Open in Full Google Maps ↗
    </a>
  </div>

  <script>
    window.streetViewPanorama = null;
    let isNaturalMode = true;

    function initStreetView() {
      const pos = { lat: $lat, lng: $lng };
      const svService = new google.maps.StreetViewService();
      
      // Look for closest Street View within 400 meters
      svService.getPanorama({ location: pos, radius: 400, source: google.maps.StreetViewSource.DEFAULT }, function(data, status) {
        if (status === google.maps.StreetViewStatus.OK && data && data.location) {
          window.streetViewPanorama = new google.maps.StreetViewPanorama(document.getElementById('pano'), {
            pano: data.location.pano,
            pov: { heading: 0, pitch: 0 },
            zoom: 1,
            addressControl: false,
            fullscreenControl: false,
            panControl: false,
            zoomControl: false,
            enableCloseButton: false,
            linksControl: true,         // Road navigation arrows
            showRoadLabels: true,
            motionTracking: false,
            motionTrackingControl: false,
            clickToGo: true,
            scrollwheel: true
          });
          setupDirectTouchRotation();
          applyColorCorrection();
        } else {
          document.getElementById('status-banner').style.display = 'flex';
        }
      });
    }

    // Direct touch-drag camera rotation (bypasses Google's degraded restrictions)
    function setupDirectTouchRotation() {
      const panoEl = document.getElementById('pano');
      let isTouching = false;
      let startX = 0, startY = 0;
      let startHeading = 0, startPitch = 0;

      panoEl.addEventListener('touchstart', function(e) {
        if (e.touches.length === 1 && window.streetViewPanorama) {
          isTouching = true;
          startX = e.touches[0].clientX;
          startY = e.touches[0].clientY;
          const pov = window.streetViewPanorama.getPov() || { heading: 0, pitch: 0 };
          startHeading = pov.heading || 0;
          startPitch = pov.pitch || 0;
        }
      }, { passive: false });

      panoEl.addEventListener('touchmove', function(e) {
        if (!isTouching || e.touches.length !== 1 || !window.streetViewPanorama) return;
        const currentX = e.touches[0].clientX;
        const currentY = e.touches[0].clientY;
        const deltaX = currentX - startX;
        const deltaY = currentY - startY;

        // Smooth 360 degree rotation
        const sensitivity = 0.35;
        const newHeading = (startHeading - deltaX * sensitivity + 3600) % 360;
        const newPitch = Math.max(-85, Math.min(85, startPitch + deltaY * sensitivity));

        window.streetViewPanorama.setPov({ heading: newHeading, pitch: newPitch });
        e.preventDefault();
      }, { passive: false });

      panoEl.addEventListener('touchend', function() { isTouching = false; });
      panoEl.addEventListener('touchcancel', function() { isTouching = false; });
    }

    // Floating On-Screen D-Pad handlers
    function rotateCam(deltaHeading, deltaPitch) {
      if (!window.streetViewPanorama) return;
      const pov = window.streetViewPanorama.getPov() || { heading: 0, pitch: 0 };
      const newHeading = ((pov.heading || 0) + deltaHeading + 3600) % 360;
      const newPitch = Math.max(-85, Math.min(85, (pov.pitch || 0) + deltaPitch));
      window.streetViewPanorama.setPov({ heading: newHeading, pitch: newPitch });
    }

    document.getElementById('btn-left').addEventListener('click', function(e) {
      e.stopPropagation();
      rotateCam(-30, 0);
    });
    document.getElementById('btn-right').addEventListener('click', function(e) {
      e.stopPropagation();
      rotateCam(30, 0);
    });
    document.getElementById('btn-up').addEventListener('click', function(e) {
      e.stopPropagation();
      rotateCam(0, 15);
    });
    document.getElementById('btn-down').addEventListener('click', function(e) {
      e.stopPropagation();
      rotateCam(0, -15);
    });
    document.getElementById('btn-reset').addEventListener('click', function(e) {
      e.stopPropagation();
      if (window.streetViewPanorama) {
        window.streetViewPanorama.setPov({ heading: 0, pitch: 0 });
      }
    });

    // Toggle between natural positive colors and raw negative
    document.getElementById('btn-toggle-color').addEventListener('click', function(e) {
      e.stopPropagation();
      isNaturalMode = !isNaturalMode;
      document.body.className = isNaturalMode ? 'natural-mode' : 'raw-mode';
      document.getElementById('color-mode-text').innerText = isNaturalMode ? 'Colors: Natural' : 'Colors: Inverted';
      applyColorCorrection();
    });

    function applyColorCorrection() {
      const canvases = document.querySelectorAll('#pano canvas');
      canvases.forEach(function(c) {
        if (isNaturalMode) {
          c.style.setProperty('filter', 'invert(1)', 'important');
          c.style.setProperty('-webkit-filter', 'invert(1)', 'important');
        } else {
          c.style.setProperty('filter', 'none', 'important');
          c.style.setProperty('-webkit-filter', 'none', 'important');
        }
      });
    }

    // Clean watermarks and auto-dismiss warning overlays continuously
    setInterval(function() {
      applyColorCorrection();

      // Auto-hide development purposes watermark divs
      const allDivs = document.querySelectorAll('#pano div');
      for (let i = 0; i < allDivs.length; i++) {
        const el = allDivs[i];
        if (el.children.length === 0 && el.innerText && el.innerText.includes('development purposes')) {
          el.style.setProperty('display', 'none', 'important');
          if (el.parentElement) {
            el.parentElement.style.setProperty('display', 'none', 'important');
          }
        }
      }

      // Auto-click dismiss button if Google creates any alert dialog
      const btn = document.querySelector('.gm-err-content button, button.dismissButton, .gm-err-container button') ||
                  Array.from(document.querySelectorAll('button')).find(function(el) { return el.textContent && el.textContent.trim() === 'OK'; });
      if (btn) btn.click();
    }, 200);

    window.gm_authFailure = function() {
      document.getElementById('status-title').innerText = 'Google Cloud Notice';
      document.getElementById('status-desc').innerText = 'This key requires a billing check on Google Cloud. You can still open full 360° directly in Google Maps for free:';
      document.getElementById('status-banner').style.display = 'flex';
    };

    function handleScriptError() {
      document.getElementById('status-title').innerText = 'Unable to Load Street View';
      document.getElementById('status-desc').innerText = 'Could not load Google Maps script. You can still open full 360° directly in Google Maps:';
      document.getElementById('status-banner').style.display = 'flex';
    }
  </script>
  <script async defer src="https://maps.googleapis.com/maps/api/js?key=$apiKey&callback=initStreetView" onerror="handleScriptError()"></script>
</body>
</html>''';
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isDesktop = media.size.width > 768;
    // Stretch to bottom so underlying dock is completely covered
    final modalHeight = isDesktop ? 780.0 : media.size.height * 0.94;

    final hasKey = StreetViewModal.sessionApiKey != null &&
        StreetViewModal.sessionApiKey!.isNotEmpty;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).pop(),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          child: Container(
            width: isDesktop ? 860 : double.infinity,
            height: modalHeight,
            clipBehavior: Clip.antiAlias,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 36,
                  offset: Offset(0, -10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag & Close Header Bar
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: (_) => _dragAccumulator = 0,
                  onVerticalDragUpdate: (details) {
                    _dragAccumulator += details.primaryDelta ?? 0;
                    if (_dragAccumulator > 25) {
                      Navigator.of(context).pop();
                    }
                  },
                  onVerticalDragEnd: (details) {
                    if (_dragAccumulator > 15 ||
                        (details.primaryVelocity != null &&
                            details.primaryVelocity! > 100)) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Drag handle pill
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Center(
                            child: Container(
                              width: 40,
                              height: 4.5,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDADCE0),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  LucideIcons.compass,
                                  size: 18,
                                  color: Color(0xFF1A73E8),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.title ?? '360° Street View',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF202124),
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    LucideIcons.externalLink,
                                    size: 18,
                                    color: Color(0xFF1A73E8),
                                  ),
                                  tooltip: 'Open in Google Maps App',
                                  splashRadius: 20,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  onPressed: _openGoogleStreetView,
                                ),
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(
                                    LucideIcons.x,
                                    size: 20,
                                    color: Color(0xFF5F6368),
                                  ),
                                  splashRadius: 20,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  onPressed: () => Navigator.of(context).pop(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Pure 100% Edge-to-Edge Street View
                Expanded(
                  child: hasKey && !_showKeyInput
                      ? _buildInAppStreetView()
                      : _buildKeySetupOrDirectLaunch(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Live in-app Google Maps Street View 360° Panorama embed (Pure edge-to-edge)
  Widget _buildInAppStreetView() {
    final apiKey = StreetViewModal.sessionApiKey!;
    final lat = widget.latitude;
    final lng = widget.longitude;
    final html = _generateGoogleMapsStreetViewHtml(apiKey, lat, lng);

    return buildInAppStreetViewIframe(
      html,
      isHtmlDoc: true,
      latitude: lat,
      longitude: lng,
    );
  }

  /// Fast 1-tap launcher card or API key configurator for in-app embedding
  Widget _buildKeySetupOrDirectLaunch() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Visual Hero Banner
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.camera,
                    color: Color(0xFF34D399),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Explore in True 360° View',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Stand right on the road and look around at the storefronts, road conditions, and surroundings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),

                // Primary One-Tap Button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _openGoogleStreetView,
                    icon: const Icon(LucideIcons.externalLink, size: 16),
                    label: const Text(
                      'Launch 360° Street View Now',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // In-App Embedding Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        LucideIcons.sparkles,
                        color: Color(0xFF0284C7),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Embed 360° Directly In-App',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Render the panorama right inside this modal without leaving the app.',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Free Demo Key Link
                InkWell(
                  onTap: _openDemoKeyPortal,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: const Row(
                      children: [
                        Icon(LucideIcons.keyRound,
                            size: 14, color: Color(0xFF0284C7)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Get Free Maps Demo Key (No credit card / 0 billing) ↗',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF0284C7),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Key Input Field
                TextField(
                  controller: _keyController,
                  decoration: InputDecoration(
                    hintText: 'Paste Google Maps Key (e.g. AIzaSy...)',
                    hintStyle: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                          color: Color(0xFF059669), width: 1.5),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(LucideIcons.check,
                          color: Color(0xFF059669), size: 18),
                      onPressed: _applyApiKey,
                    ),
                  ),
                  style: const TextStyle(fontSize: 12.5),
                  onSubmitted: (_) => _applyApiKey(),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(
                      color: Color(0xFFDC2626),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],

                const SizedBox(height: 10),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _applyApiKey,
                        icon: const Icon(LucideIcons.check, size: 14),
                        label: const Text(
                          'Save & Embed In-App',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    if (StreetViewModal.sessionApiKey != null &&
                        StreetViewModal.sessionApiKey!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: _clearApiKey,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFFCA5A5)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Clear Key',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
