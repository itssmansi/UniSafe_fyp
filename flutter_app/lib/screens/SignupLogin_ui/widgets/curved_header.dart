import 'package:flutter/material.dart';

/// Layer 1: Back wave clipper for rich layered depth
class BackWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 30);

    // Flowing smooth curve
    Offset controlPoint1 = Offset(size.width * 0.35, size.height + 15);
    Offset endPoint1 = Offset(size.width * 0.7, size.height - 35);
    path.quadraticBezierTo(controlPoint1.dx, controlPoint1.dy, endPoint1.dx, endPoint1.dy);

    Offset controlPoint2 = Offset(size.width * 0.9, size.height - 65);
    Offset endPoint2 = Offset(size.width, size.height - 20);
    path.quadraticBezierTo(controlPoint2.dx, controlPoint2.dy, endPoint2.dx, endPoint2.dy);

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

/// Layer 2: Front organic wave clipper
class FrontWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 45);

    // Natural organic wave curve
    Offset controlPoint1 = Offset(size.width * 0.25, size.height + 5);
    Offset endPoint1 = Offset(size.width * 0.58, size.height - 28);
    path.quadraticBezierTo(controlPoint1.dx, controlPoint1.dy, endPoint1.dx, endPoint1.dy);

    Offset controlPoint2 = Offset(size.width * 0.85, size.height - 55);
    Offset endPoint2 = Offset(size.width, size.height - 15);
    path.quadraticBezierTo(controlPoint2.dx, controlPoint2.dy, endPoint2.dx, endPoint2.dy);

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class CurvedHeader extends StatelessWidget {
  final double height;
  final VoidCallback? onBack;
  final Widget? child;
  final String? title;

  const CurvedHeader({
    super.key,
    this.height = 200,
    this.onBack,
    this.child,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        children: [
          // Background Deep Wave Layer (Cyan/Teal accent glow)
          ClipPath(
            clipper: BackWaveClipper(),
            child: Container(
              height: height,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F766E), // Deep teal
                    Color(0xFF0284C7), // Sky ocean
                    Color(0xFF0D9488), // Teal
                  ],
                ),
              ),
            ),
          ),

          // Main Foreground Wave Layer (Rich Midnight Sapphire Gradient)
          ClipPath(
            clipper: FrontWaveClipper(),
            child: Container(
              height: height - 6,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0B132B), // Obsidian navy
                    Color(0xFF1C2541), // Deep sapphire
                    Color(0xFF1E3A8A), // Royal midnight blue
                    Color(0xFF0E7490), // Cyan teal rim
                  ],
                  stops: [0.0, 0.45, 0.82, 1.0],
                ),
              ),
              child: Stack(
                children: [
                  // Ambient light mesh
                  Positioned(
                    top: -40,
                    right: -30,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF38BDF8).withValues(alpha: 0.25),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 20,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF2DD4BF).withValues(alpha: 0.18),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Header content
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (onBack != null)
                                GestureDetector(
                                  onTap: onBack,
                                  behavior: HitTestBehavior.opaque,
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.25),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              if (title != null) ...[
                                const SizedBox(width: 14),
                                Text(
                                  title!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (child != null)
                            Expanded(child: child!),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
