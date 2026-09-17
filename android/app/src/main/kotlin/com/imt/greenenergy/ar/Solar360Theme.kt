package com.imt.greenenergy.ar

import androidx.compose.material3.Typography
import androidx.compose.material3.darkColorScheme
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.googlefonts.Font
import androidx.compose.ui.text.googlefonts.GoogleFont
import androidx.compose.ui.unit.sp
import com.imt.greenenergy.R

object Solar360Theme {
    val Brand = Color(0xFF14B8A6)
    val BrandBright = Color(0xFF2DD4BF)
    val BrandDeep = Color(0xFF0F766E)
    val Window = Color(0xFF061218)

    val GlassFill = Color(0xE6102A32)
    val GlassFillStrong = Color(0xF2102A32)
    val GlassBorder = Color(0x9914B8A6)
    val GlassBorderSoft = Color(0x6614B8A6)
    val PillFill = Color(0xCC115E59)
    val PillBorder = Color(0xFF14B8A6)
    val Vignette = Color(0xFF061218)
    val Glow = Color(0x8814B8A6)

    val BrandGradient = Brush.linearGradient(
        colors = listOf(BrandBright, BrandDeep),
        start = Offset.Zero,
        end = Offset(800f, 200f),
    )

    val SheetGradient = Brush.verticalGradient(
        colors = listOf(Color(0xF2102A30), Color(0xFF0E3A40)),
    )

    val CardGradient = Brush.linearGradient(
        colors = listOf(
            Color(0xE6061218),
            Color(0x4D0F766E),
            Color(0xE6061218),
        ),
        start = Offset.Zero,
        end = Offset(420f, 280f),
    )

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
        background = Color(0xFF07141A),
        onBackground = Color(0xFFF1F5F9),
        surface = Color(0xFF07141A),
        onSurface = Color(0xFFF1F5F9),
        onSurfaceVariant = Color(0xFF94A3B8),
        outline = Color(0xFF5B7A80),
        outlineVariant = Color(0xFF1A4A4E),
        surfaceContainerLowest = Color(0xFF061218),
        surfaceContainerLow = Color(0xFF0C1C20),
        surfaceContainer = Color(0xFF102A30),
        surfaceContainerHigh = Color(0xFF12282C),
        surfaceContainerHighest = Color(0xFF16383E),
        inverseSurface = Color(0xFFE2E8F0),
        inverseOnSurface = Color(0xFF1E293B),
        inversePrimary = Color(0xFF0F766E),
        scrim = Color(0xFF000000),
        surfaceTint = Color(0xFF14B8A6),
    )

    fun typography(): Typography {
        val family = plusJakartaFamily
        fun style(
            size: Int,
            weight: FontWeight,
            height: Float,
            letterSpacing: Float = 0f,
        ) = TextStyle(
            fontFamily = family,
            fontWeight = weight,
            fontSize = size.sp,
            lineHeight = (size * height).sp,
            letterSpacing = letterSpacing.sp,
            color = Color(0xFFF1F5F9),
        )
        return Typography(
            displaySmall = style(28, FontWeight.ExtraBold, 1.2f, -0.4f),
            headlineSmall = style(20, FontWeight.Bold, 1.3f, -0.15f),
            titleLarge = style(18, FontWeight.Bold, 1.35f, -0.2f),
            titleMedium = style(16, FontWeight.Bold, 1.35f, -0.1f),
            titleSmall = style(14, FontWeight.Bold, 1.35f),
            bodyLarge = style(16, FontWeight.Medium, 1.5f),
            bodyMedium = style(14, FontWeight.Medium, 1.45f),
            bodySmall = style(12, FontWeight.Medium, 1.4f),
            labelLarge = style(14, FontWeight.Bold, 1.3f, 0.1f),
            labelMedium = style(12, FontWeight.SemiBold, 1.3f, 0.2f),
            labelSmall = style(11, FontWeight.SemiBold, 1.25f, 0.4f),
        )
    }

    private val plusJakartaFamily: FontFamily by lazy {
        val provider = GoogleFont.Provider(
            providerAuthority = "com.google.android.gms.fonts",
            providerPackage = "com.google.android.gms",
            certificates = R.array.com_google_android_gms_fonts_certs,
        )
        val jakarta = GoogleFont(name = "Plus Jakarta Sans", bestEffort = true)
        FontFamily(
            Font(googleFont = jakarta, fontProvider = provider, weight = FontWeight.Medium),
            Font(googleFont = jakarta, fontProvider = provider, weight = FontWeight.SemiBold),
            Font(googleFont = jakarta, fontProvider = provider, weight = FontWeight.Bold),
            Font(googleFont = jakarta, fontProvider = provider, weight = FontWeight.ExtraBold),
        )
    }
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
    val Amber = Color(1.0f, 0.88f, 0.08f)
    val Ink = Color(0.05f, 0.05f, 0.05f)

    val GrassRgb = floatArrayOf(0.18f, 0.34f, 0.20f)
    val ConcreteRgb = floatArrayOf(0.62f, 0.63f, 0.61f)
    val SteelRgb = floatArrayOf(0.40f, 0.42f, 0.41f)
    val AluminumRgb = floatArrayOf(0.86f, 0.88f, 0.90f)
    val GlassRgb = floatArrayOf(0.06f, 0.10f, 0.16f)
    val FrameRgb = floatArrayOf(0.78f, 0.80f, 0.82f)
    val BusbarRgb = floatArrayOf(0.72f, 0.58f, 0.18f)
}
