import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../theme/unisafe_theme.dart';

/// Calm backdrop featuring pattern_black_transparent.png on UniSafe canvas
/// with true Gaussian edge blur softening around the perimeter.
/// Optimized using a pre-blurred seamless asset to deliver 60fps animations
/// without runtime convolution lag.
class AuthBackground extends StatelessWidget {
  final double opacity;
  final bool enableEdgeBlur;

  const AuthBackground({
    super.key,
    this.opacity = 0.12,
    this.enableEdgeBlur = true,
  });

  Widget _buildPatternImage() {
    return Image.asset(
      'assets/images/pattern_black_transparent.png',
      fit: BoxFit.cover,
      repeat: ImageRepeat.repeat,
      opacity: AlwaysStoppedAnimation(opacity),
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/assets/images/pattern_black_transparent.png',
          fit: BoxFit.cover,
          repeat: ImageRepeat.repeat,
          opacity: AlwaysStoppedAnimation(opacity),
        );
      },
    );
  }

  Widget _buildBlurredPatternImage() {
    return Image.asset(
      'assets/images/pattern_black_transparent_blur.png',
      fit: BoxFit.cover,
      repeat: ImageRepeat.repeat,
      opacity: AlwaysStoppedAnimation(opacity),
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/assets/images/pattern_black_transparent_blur.png',
          fit: BoxFit.cover,
          repeat: ImageRepeat.repeat,
          opacity: AlwaysStoppedAnimation(opacity),
          errorBuilder: (context, error, stackTrace) {
            // Fallback to runtime filter if asset not yet loaded
            return ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
              child: _buildPatternImage(),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: RepaintBoundary(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: UniSafeColors.canvas,
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Layer 1: True Gaussian blurred pattern for the perimeter/edges
              if (enableEdgeBlur)
                _buildBlurredPatternImage(),

              // Layer 2: Sharp pattern in the center, feathered at the edges
              if (enableEdgeBlur)
                ShaderMask(
                  blendMode: BlendMode.dstIn,
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black,
                      Colors.black,
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.08, 0.92, 1.0],
                  ).createShader(bounds),
                  child: ShaderMask(
                    blendMode: BlendMode.dstIn,
                    shaderCallback: (bounds) => const LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.transparent,
                        Colors.black,
                        Colors.black,
                        Colors.transparent,
                      ],
                      stops: [0.0, 0.10, 0.90, 1.0],
                    ).createShader(bounds),
                    child: _buildPatternImage(),
                  ),
                )
              else
                _buildPatternImage(),

              // Layer 3: Ultra subtle vignette feathering on the extreme edges
              if (enableEdgeBlur)
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.15,
                      colors: [
                        Colors.transparent,
                        UniSafeColors.canvas.withValues(alpha: 0.0),
                        UniSafeColors.canvas.withValues(alpha: 0.35),
                      ],
                      stops: const [0.0, 0.75, 1.0],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
