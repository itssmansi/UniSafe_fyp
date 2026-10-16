import 'package:flutter/material.dart';

/// Non-web fallback for the street view embed
Widget buildInAppStreetViewIframe(String source, {bool isHtmlDoc = false}) {
  return Container(
    color: const Color(0xFFF1F5F9),
    alignment: Alignment.center,
    child: const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.public, size: 40, color: Color(0xFF64748B)),
        SizedBox(height: 12),
        Text(
          'In-app Street View viewer is active on Web',
          style: TextStyle(
            color: Color(0xFF334155),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}
