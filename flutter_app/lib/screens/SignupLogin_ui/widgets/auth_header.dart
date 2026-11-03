import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/unisafe_theme.dart';

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
                  color: UniSafeColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: UniSafeColors.line,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: UniSafeColors.ink.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: UniSafeColors.ink,
                    size: 16,
                  ),
                ),
              ),
            ),
          )
        : null;

    final Widget titleWidget = Container(
      width: double.infinity,
      height: isCentered ? 140 : 120,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          title.toUpperCase(),
          textAlign: TextAlign.center,
          style: GoogleFonts.sixCaps(
            textStyle: const TextStyle(fontFamily: 'SixCaps'),
            fontSize: 135,
            color: UniSafeColors.ink,
            letterSpacing: 4.5,
            height: 0.95,
          ),
        ),
      ),
    );

    final Widget patternOverlay = Positioned.fill(
      child: Image.asset(
        'assets/images/pattern_black_transparent.png',
        fit: BoxFit.cover,
        repeat: ImageRepeat.repeat,
        opacity: const AlwaysStoppedAnimation(0.12),
        errorBuilder: (context, error, stackTrace) => Image.asset(
          'assets/assets/images/pattern_black_transparent.png',
          fit: BoxFit.cover,
          repeat: ImageRepeat.repeat,
          opacity: const AlwaysStoppedAnimation(0.12),
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
