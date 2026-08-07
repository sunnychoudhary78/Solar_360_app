import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Explicit Plus Jakarta Sans type scale for Solar360.
class AppTypography {
  AppTypography._();

  static TextTheme textTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? ThemeData(brightness: Brightness.dark).textTheme
        : ThemeData(brightness: Brightness.light).textTheme;

    final color = brightness == Brightness.dark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF0F172A);

    TextStyle jakarta({
      required double size,
      required FontWeight weight,
      double height = 1.35,
      double letterSpacing = 0,
      Color? c,
    }) {
      return GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
        color: c ?? color,
      );
    }

    return GoogleFonts.plusJakartaSansTextTheme(base).copyWith(
      displayLarge: jakarta(size: 40, weight: FontWeight.w800, height: 1.15, letterSpacing: -0.8),
      displayMedium: jakarta(size: 32, weight: FontWeight.w800, height: 1.2, letterSpacing: -0.6),
      displaySmall: jakarta(size: 28, weight: FontWeight.w800, height: 1.2, letterSpacing: -0.4),
      headlineLarge: jakarta(size: 24, weight: FontWeight.w800, height: 1.25, letterSpacing: -0.3),
      headlineMedium: jakarta(size: 22, weight: FontWeight.w700, height: 1.3, letterSpacing: -0.2),
      headlineSmall: jakarta(size: 20, weight: FontWeight.w700, height: 1.3, letterSpacing: -0.15),
      titleLarge: jakarta(size: 18, weight: FontWeight.w700, height: 1.35, letterSpacing: -0.1),
      titleMedium: jakarta(size: 16, weight: FontWeight.w700, height: 1.35),
      titleSmall: jakarta(size: 14, weight: FontWeight.w700, height: 1.35),
      bodyLarge: jakarta(size: 16, weight: FontWeight.w500, height: 1.5),
      bodyMedium: jakarta(size: 14, weight: FontWeight.w500, height: 1.45),
      bodySmall: jakarta(size: 12, weight: FontWeight.w500, height: 1.4),
      labelLarge: jakarta(size: 14, weight: FontWeight.w700, height: 1.3, letterSpacing: 0.1),
      labelMedium: jakarta(size: 12, weight: FontWeight.w600, height: 1.3, letterSpacing: 0.2),
      labelSmall: jakarta(size: 11, weight: FontWeight.w600, height: 1.25, letterSpacing: 0.4),
    );
  }

  static TextStyle appBarTitle(ColorScheme scheme) {
    return GoogleFonts.plusJakartaSans(
      fontSize: 18,
      fontWeight: FontWeight.w800,
      color: scheme.onSurface,
      letterSpacing: -0.2,
    );
  }

  static TextStyle chipLabel(ColorScheme scheme) {
    return GoogleFonts.plusJakartaSans(
      fontWeight: FontWeight.w600,
      fontSize: 13,
      color: scheme.onSurface,
    );
  }
}
