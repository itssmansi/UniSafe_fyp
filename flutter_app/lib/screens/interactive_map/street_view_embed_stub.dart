import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Mobile (Android / iOS) implementation of in-app Street View using native WebView
class MobileStreetViewEmbed extends StatefulWidget {
  final String source;
  final bool isHtmlDoc;
  final double? latitude;
  final double? longitude;

  const MobileStreetViewEmbed({
    super.key,
    required this.source,
    this.isHtmlDoc = false,
    this.latitude,
    this.longitude,
  });

  @override
  State<MobileStreetViewEmbed> createState() => _MobileStreetViewEmbedState();
}

class _MobileStreetViewEmbedState extends State<MobileStreetViewEmbed> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorDesc;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF0F172A))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
          },
          onPageFinished: (url) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onWebResourceError: (error) {
            debugPrint('[StreetView] WebView resource error: ${error.description}');
            if (error.isForMainFrame ?? false) {
              if (mounted) {
                setState(() {
                  _hasError = true;
                  _errorDesc = error.description;
                  _isLoading = false;
                });
              }
            }
          },
          onNavigationRequest: (NavigationRequest request) async {
            final url = request.url;
            if (url.startsWith('https://www.google.com/maps') ||
                url.startsWith('https://maps.google.com') ||
                url.startsWith('http://maps.google.com') ||
                url.startsWith('google.navigation:')) {
              try {
                await launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                );
              } catch (_) {}
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );

    if (widget.isHtmlDoc) {
      _controller.loadHtmlString(
        widget.source,
        baseUrl: 'https://maps.googleapis.com',
      );
    } else {
      _controller.loadRequest(Uri.parse(widget.source));
    }
  }

  Future<void> _openExternalMaps() async {
    final lat = widget.latitude;
    final lng = widget.longitude;
    final url = (lat != null && lng != null)
        ? 'https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=$lat,$lng'
        : 'https://maps.google.com';
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        color: const Color(0xFF0F172A),
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFF87171)),
            const SizedBox(height: 16),
            const Text(
              'Unable to render in-app 360° Street View',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorDesc ?? 'Please check internet connection or open directly in Google Maps.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _openExternalMaps,
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Open in Google Maps App'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: WebViewWidget(
            controller: _controller,
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(
                () => EagerGestureRecognizer(),
              ),
            },
          ),
        ),
        if (_isLoading)
          Container(
            color: const Color(0xFF0F172A),
            alignment: Alignment.center,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: Color(0xFF38BDF8),
                  strokeWidth: 3,
                ),
                SizedBox(height: 16),
                Text(
                  'Loading 360° Street View...',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Fallback / mobile implementation for in-app Street View
Widget buildInAppStreetViewIframe(
  String source, {
  bool isHtmlDoc = false,
  double? latitude,
  double? longitude,
}) {
  return MobileStreetViewEmbed(
    source: source,
    isHtmlDoc: isHtmlDoc,
    latitude: latitude,
    longitude: longitude,
  );
}
