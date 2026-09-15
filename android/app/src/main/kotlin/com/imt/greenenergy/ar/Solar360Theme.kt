package com.imt.greenenergy.ar

import androidx.compose.material3.darkColorScheme
import androidx.compose.ui.graphics.Color

object Solar360Theme {
    val Brand = Color(0xFF14B8A6)
    val BrandDeep = Color(0xFF0F766E)
    val Window = Color(0xFF0A0E12)

    fun darkColorScheme() = darkColorScheme(
        primary = Color(0xFF14B8A6),
        onPrimary = Color(0xFF042F2E),
        primaryContainer = Color(0xFF115E59),
        onPrimaryContainer = Color(0xFFCCFBF1),
        secondary = Color(0xFF2DD4BF),
        onSecondary = Color(0xFF042F2E),
        secondaryContainer = Color(0xFF134E4A),
        onSecondaryContainer = Color(0xFFCCFBF1),
        tertiary = Color(0xFF38BDF8),
        onTertiary = Color(0xFF0C4A6E),
        tertiaryContainer = Color(0xFF075985),
        onTertiaryContainer = Color(0xFFE0F2FE),
        error = Color(0xFFF87171),
        onError = Color(0xFF7F1D1D),
        errorContainer = Color(0xFF991B1B),
        onErrorContainer = Color(0xFFFEE2E2),
        background = Color(0xFF0F1419),
        onBackground = Color(0xFFF1F5F9),
        surface = Color(0xFF0F1419),
        onSurface = Color(0xFFF1F5F9),
        onSurfaceVariant = Color(0xFF94A3B8),
        outline = Color(0xFF64748B),
        outlineVariant = Color(0xFF334155),
        surfaceContainerLowest = Color(0xFF0A0E12),
        surfaceContainerLow = Color(0xFF161B22),
        surfaceContainer = Color(0xFF1C222A),
        surfaceContainerHigh = Color(0xFF262C35),
        surfaceContainerHighest = Color(0xFF313842),
        inverseSurface = Color(0xFFE2E8F0),
        inverseOnSurface = Color(0xFF1E293B),
        inversePrimary = Color(0xFF0F766E),
        scrim = Color(0xFF000000),
        surfaceTint = Color(0xFF14B8A6),
    )
}

object SolarArrayLook {
    val Grass = Color(0.18f, 0.34f, 0.20f)
    val Concrete = Color(0.62f, 0.63f, 0.61f)
    val Steel = Color(0.40f, 0.42f, 0.41f)
    val Aluminum = Color(0.86f, 0.88f, 0.90f)
    val Glass = Color(0.06f, 0.10f, 0.16f)
    val Frame = Color(0.78f, 0.80f, 0.82f)
    val Busbar = Color(0.72f, 0.58f, 0.18f)
    val Teal = Color(0.08f, 0.72f, 0.65f)
    val Amber = Color(0.96f, 0.76f, 0.28f)

    val GrassRgb = floatArrayOf(0.18f, 0.34f, 0.20f)
    val ConcreteRgb = floatArrayOf(0.62f, 0.63f, 0.61f)
    val SteelRgb = floatArrayOf(0.40f, 0.42f, 0.41f)
    val AluminumRgb = floatArrayOf(0.86f, 0.88f, 0.90f)
    val GlassRgb = floatArrayOf(0.06f, 0.10f, 0.16f)
    val FrameRgb = floatArrayOf(0.78f, 0.80f, 0.82f)
    val BusbarRgb = floatArrayOf(0.72f, 0.58f, 0.18f)
}
