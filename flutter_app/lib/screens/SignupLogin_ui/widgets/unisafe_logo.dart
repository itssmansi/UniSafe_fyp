import 'package:flutter/material.dart';

class UniSafeEmblem extends StatelessWidget {
  final double size;
  final bool showGlow;

  const UniSafeEmblem({
    super.key,
    this.size = 56,
    this.showGlow = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [
            Color(0xFF1E3A8A), // Royal navy core
            Color(0xFF0F172A), // Dark slate edge
          ],
        ),
        boxShadow: showGlow
            ? [
                BoxShadow(
                  color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                  blurRadius: size * 0.45,
                  spreadRadius: size * 0.05,
                ),
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.25),
                  blurRadius: size * 0.25,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer shield silhouette
            Icon(
              Icons.shield_outlined,
              size: size * 0.58,
              color: const Color(0xFF38BDF8),
            ),
            // Inner glowing safety node
            Container(
              width: size * 0.24,
              height: size * 0.24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF34D399), // Emerald
                    Color(0xFF06B6D4), // Cyan
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF34D399).withValues(alpha: 0.6),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Icon(
                Icons.security_rounded,
                size: size * 0.16,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
