import 'package:flutter/material.dart';
import 'doodle_pattern_data.dart';

/// Full-screen green doodle background widget.
/// Fills the entire screen edge-to-edge behind all auth elements.
class AuthBackground extends StatelessWidget {
  const AuthBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Image.asset(
        'assets/images/preview_white_lines.png',
        fit: BoxFit.cover,
        repeat: ImageRepeat.repeat,
        errorBuilder: (context, error, stackTrace) => Image.memory(
          kPreviewWhiteLinesBytes,
          fit: BoxFit.cover,
          repeat: ImageRepeat.repeat,
        ),
      ),
    );
  }
}
