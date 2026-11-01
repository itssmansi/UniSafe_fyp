import 'package:flutter/material.dart';

/// UniSafe Design System Theme
/// Shared palette between Authority Web Portal and Citizen Flutter App.
class UniSafeTheme {
  UniSafeTheme._();

  // Core Brand Palette
  static const Color background = Color(0xFFF7F8F4);
  static const Color card = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF1F4EE);

  static const Color midnightBlue = Color(0xFF1E3A5F);
  static const Color midnightDark = Color(0xFF162C46);
  static const Color midnightLight = Color(0xFFEEF4FA);

  static const Color teal = Color(0xFF10B981);
  static const Color tealHover = Color(0xFF059669);
  static const Color tealLight = Color(0xFFECFDF5);
  static const Color tealBorder = Color(0xFFA7F3D0);

  static const Color amber = Color(0xFFD97706);
  static const Color amberHover = Color(0xFFB45309);
  static const Color amberLight = Color(0xFFFFFBEB);
  static const Color amberBorder = Color(0xFFFDE68A);

  static const Color crimson = Color(0xFFDC2626);
  static const Color crimsonHover = Color(0xFFB91C1C);
  static const Color crimsonLight = Color(0xFFFEF2F2);
  static const Color crimsonBorder = Color(0xFFFECACA);

  static const Color textDark = Color(0xFF152937);
  static const Color textMain = Color(0xFF1E293B);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textLight = Color(0xFF94A3B8);

  static const Color border = Color(0xFFE2E8F0);
  static const Color borderSubtle = Color(0xFFEDF2F7);

  // Component Metrics
  static const double radiusSm = 6.0;
  static const double radiusMd = 10.0;
  static const double radiusLg = 14.0;
  static const double radiusXl = 18.0;

  // Box Shadows
  static const List<BoxShadow> shadowXs = [
    BoxShadow(
      color: Color(0x0D000000),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];

  static const List<BoxShadow> shadowSm = [
    BoxShadow(
      color: Color(0x14000000),
      offset: Offset(0, 1),
      blurRadius: 3,
    ),
    BoxShadow(
      color: Color(0x0A000000),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
  ];

  static const List<BoxShadow> shadowCard = [
    BoxShadow(
      color: Color(0x0F0F172A),
      offset: Offset(0, 2),
      blurRadius: 6,
    ),
  ];

  /// Material3 ThemeData Configured for UniSafe
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      primaryColor: midnightBlue,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: midnightBlue,
        onPrimary: Colors.white,
        secondary: teal,
        onSecondary: Colors.white,
        error: crimson,
        onError: Colors.white,
        surface: card,
        onSurface: textDark,
      ),
      fontFamily: 'Inter',
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: border),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: card,
        foregroundColor: textDark,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textDark,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: midnightBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: crimson),
        ),
        hintStyle: const TextStyle(
          color: textLight,
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: teal,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMd),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
