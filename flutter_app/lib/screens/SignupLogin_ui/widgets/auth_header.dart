import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'doodle_pattern_data.dart';

class AuthHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final bool isCentered;
  final bool showPattern;

  final bool showBackButton;

  const AuthHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.isCentered = false,
    this.showPattern = false,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final Widget? backButton = showBackButton
        ? Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                    width: 1,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
          )
        : null;

    final Widget titleWidget = Container(
      width: double.infinity,
      height: 110,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          title.toUpperCase(),
          textAlign: TextAlign.center,
          style: GoogleFonts.sixCaps(
            fontSize: 100,
            color: Colors.white,
            letterSpacing: 4.0,
            height: 0.95,
          ),
        ),
      ),
    );

    final Widget patternOverlay = Positioned.fill(
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

    if (isCentered) {
      return SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: Stack(
          children: [
            if (showPattern) patternOverlay,

            // Centered title in the entire available canvas
            Center(
              child: titleWidget,
            ),

            // Pinned top-left back button
            if (backButton != null)
              Positioned(
                top: 8,
                left: 16,
                child: backButton,
              ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
          if (showPattern) patternOverlay,
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ?backButton,
                titleWidget,
              ],
            ),
          ),
        ],
      ),
    );
  }
}
