import 'package:flutter/material.dart';

/// Hand-tuned ColorSchemes for Solar360 — deep teal brand, soft neutrals.
///
/// Prefer these over [ColorScheme.fromSeed] so surfaces, containers and
/// accents stay deliberate across light and dark modes.
class AppPalette {
  AppPalette._();

  /// Brand teal — also the default in [appThemeProvider].
  static const Color brand = Color(0xFF0F766E);
  static const Color brandDark = Color(0xFF14B8A6);
  static const Color brandDeep = Color(0xFF0D5C56);

  // ── Light ──────────────────────────────────────────────────────────────

  static const ColorScheme light = ColorScheme(
    brightness: Brightness.light,
    primary: brand,
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFCCFBF1),
    onPrimaryContainer: Color(0xFF134E4A),
    secondary: Color(0xFF0D9488),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFD1FAE5),
    onSecondaryContainer: Color(0xFF064E3B),
    tertiary: Color(0xFF0369A1),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFE0F2FE),
    onTertiaryContainer: Color(0xFF0C4A6E),
    error: Color(0xFFDC2626),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFEE2E2),
    onErrorContainer: Color(0xFF7F1D1D),
    surface: Color(0xFFF8FAF9),
    onSurface: Color(0xFF0F172A),
    onSurfaceVariant: Color(0xFF64748B),
    outline: Color(0xFF94A3B8),
    outlineVariant: Color(0xFFE2E8F0),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF1F5F4),
    surfaceContainer: Color(0xFFE8EEEC),
    surfaceContainerHigh: Color(0xFFE0E7E5),
    surfaceContainerHighest: Color(0xFFD6DEDC),
    inverseSurface: Color(0xFF1E293B),
    onInverseSurface: Color(0xFFF1F5F9),
    inversePrimary: Color(0xFF5EEAD4),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    surfaceTint: brand,
  );

  // ── Dark ───────────────────────────────────────────────────────────────

  static const ColorScheme dark = ColorScheme(
    brightness: Brightness.dark,
    primary: brandDark,
    onPrimary: Color(0xFF042F2E),
    primaryContainer: Color(0xFF115E59),
    onPrimaryContainer: Color(0xFFCCFBF1),
    secondary: Color(0xFF2DD4BF),
    onSecondary: Color(0xFF042F2E),
    secondaryContainer: Color(0xFF134E4A),
    onSecondaryContainer: Color(0xFFCCFBF1),
    tertiary: Color(0xFF38BDF8),
    onTertiary: Color(0xFF0C4A6E),
    tertiaryContainer: Color(0xFF075985),
    onTertiaryContainer: Color(0xFFE0F2FE),
    error: Color(0xFFF87171),
    onError: Color(0xFF7F1D1D),
    errorContainer: Color(0xFF991B1B),
    onErrorContainer: Color(0xFFFEE2E2),
    surface: Color(0xFF0F1419),
    onSurface: Color(0xFFF1F5F9),
    onSurfaceVariant: Color(0xFF94A3B8),
    outline: Color(0xFF64748B),
    outlineVariant: Color(0xFF334155),
    surfaceContainerLowest: Color(0xFF0A0E12),
    surfaceContainerLow: Color(0xFF161B22),
    surfaceContainer: Color(0xFF1C222A),
    surfaceContainerHigh: Color(0xFF262C35),
    surfaceContainerHighest: Color(0xFF313842),
    inverseSurface: Color(0xFFE2E8F0),
    onInverseSurface: Color(0xFF1E293B),
    inversePrimary: brand,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    surfaceTint: brandDark,
  );

  /// Soft canvas behind scaffolds (light).
  static const Color lightScaffold = Color(0xFFF4F7F6);

  /// Soft canvas behind scaffolds (dark).
  static const Color darkScaffold = Color(0xFF0F1419);

  /// Build a ColorScheme tinted by an optional user-selected primary.
  /// Neutrals stay hand-tuned; only primary/container family shifts.
  static ColorScheme resolve({
    required Brightness brightness,
    Color? primaryTint,
  }) {
    final base = brightness == Brightness.dark ? dark : light;
    if (primaryTint == null || primaryTint == brand) return base;

    final seed = ColorScheme.fromSeed(
      seedColor: primaryTint,
      brightness: brightness,
    );
    return base.copyWith(
      primary: seed.primary,
      onPrimary: seed.onPrimary,
      primaryContainer: seed.primaryContainer,
      onPrimaryContainer: seed.onPrimaryContainer,
      secondary: seed.secondary,
      onSecondary: seed.onSecondary,
      secondaryContainer: seed.secondaryContainer,
      onSecondaryContainer: seed.onSecondaryContainer,
      surfaceTint: seed.primary,
      inversePrimary: seed.inversePrimary,
    );
  }
}
