import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

final Set<String> _registeredViews = {};

/// Web implementation of in-app street view iframe
Widget buildInAppStreetViewIframe(String source, {bool isHtmlDoc = false}) {
  final viewType = 'mly-frame-${source.hashCode.abs()}';

  if (!_registeredViews.contains(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        final iframe = web.HTMLIFrameElement()
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..allow =
              'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share'
          ..allowFullscreen = true;
        if (isHtmlDoc) {
          iframe.setAttribute('srcdoc', source);
        } else {
          iframe.setAttribute('src', source);
        }
        return iframe;
      },
    );
    _registeredViews.add(viewType);
  }

  return HtmlElementView(viewType: viewType);
}
