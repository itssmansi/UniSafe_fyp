import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// The shared visual language for all citizen-facing UniSafe experiences.
/// Navy communicates trust, teal is reserved for positive safety signals and
/// amber/red remain semantic colours for warnings and emergencies.
abstract final class UniSafeColors {
  static const ink = Color(0xFF10243E);
  static const mutedInk = Color(0xFF607089);
  static const canvas = Color(0xFFF5F8FC);
  static const surface = Color(0xFFFFFFFF);
  static const line = Color(0xFFDCE5F0);
  static const navy = Color(0xFF0B3B68);
  static const blue = Color(0xFF176BBA);
  static const teal = Color(0xFF087E72);
  static const mint = Color(0xFFE2F5F0);
  static const amber = Color(0xFFE58A14);
  static const danger = Color(0xFFC83E4D);
}

abstract final class UniSafeTheme {
  static final String? fontPrimary = GoogleFonts.inter().fontFamily;
  static const String fontDisplay = 'Flaviotte';

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: UniSafeColors.navy,
      brightness: Brightness.light,
      primary: UniSafeColors.navy,
      secondary: UniSafeColors.teal,
      surface: UniSafeColors.surface,
      error: UniSafeColors.danger,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: GoogleFonts.inter().fontFamily,
      scaffoldBackgroundColor: UniSafeColors.canvas,
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).apply(
        bodyColor: UniSafeColors.ink,
        displayColor: UniSafeColors.ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: UniSafeColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: UniSafeColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: UniSafeColors.line),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: UniSafeColors.ink,
        contentTextStyle: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: UniSafeColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: UniSafeColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: UniSafeColors.blue, width: 1.5),
        ),
      ),
    );
  }
}

class UniSafePageRoute<T> extends PageRouteBuilder<T> {
  UniSafePageRoute({required WidgetBuilder builder, RouteSettings? settings})
      : super(
          settings: settings,
          transitionDuration: const Duration(milliseconds: 360),
          reverseTransitionDuration: const Duration(milliseconds: 260),
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
            return FadeTransition(
              opacity: curve,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0.025, 0.015), end: Offset.zero).animate(curve),
                child: child,
              ),
            );
          },
        );
}

class EntranceReveal extends StatelessWidget {
  const EntranceReveal({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 520),
        tween: Tween(begin: 0, end: 1),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => Opacity(
          opacity: value,
          child: Transform.translate(offset: Offset(0, 18 * (1 - value)), child: child),
        ),
        child: child,
      );
}
