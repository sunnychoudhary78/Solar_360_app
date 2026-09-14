package com.imt.greenenergy.ar

import android.content.Intent
import kotlin.math.asin
import kotlin.math.min
import kotlin.math.sqrt

data class SolarPanelProduct(
    val id: String,
    val companyName: String,
    val widthM: Float,
    val lengthM: Float,
    val minWatts: Int,
    val maxWatts: Int,
    val defaultWatts: Int,
    val wattStep: Int = 10,
    val asset: String = SolarArrayDims.PanelAsset,
    val enabled: Boolean = true,
) {
    val sliderSteps: Int
        get() = ((maxWatts - minWatts) / wattStep).coerceAtLeast(1) - 1

    fun clampWatts(watts: Int): Int {
        val step = wattStep.coerceAtLeast(1)
        val stepped = ((watts + step / 2) / step) * step
        return stepped.coerceIn(minWatts, maxWatts)
    }

    val scaleX: Float
        get() = if (SolarArrayDims.PanelW > 0f) widthM / SolarArrayDims.PanelW else 1f

    val scaleZ: Float
        get() = if (SolarArrayDims.PanelL > 0f) lengthM / SolarArrayDims.PanelL else 1f
}

object SolarHeightLimits {
    const val MinFt = 1f
    const val MaxFt = 13f
    const val DefaultNorthFt = 2f
    const val DefaultSouthFt = 5f
    const val FtToM = 0.3048f
    const val MToFt = 3.28084f
    const val MaxSlopeSin = 0.98f

    val MinM = MinFt * FtToM
    val MaxM = MaxFt * FtToM
    val DefaultNorthM = DefaultNorthFt * FtToM
    val DefaultSouthM = DefaultSouthFt * FtToM

    fun metersToFeet(meters: Float): Float = meters * MToFt

    fun feetToMeters(feet: Float): Float = feet * FtToM

    fun clampM(meters: Float): Float = meters.coerceIn(MinM, MaxM)

    fun maxDeltaM(arrayL: Float): Float = arrayL * MaxSlopeSin

    fun arrayLengthM(rows: Int, panelL: Float = SolarArrayDims.PanelL): Float {
        return rows * panelL + (rows - 1).coerceAtLeast(0) * SolarArrayDims.Gap
    }

    fun clampNorthM(northM: Float, southM: Float, arrayL: Float): Float {
        val south = clampM(southM)
        val maxD = maxDeltaM(arrayL)
        return clampM(northM).coerceIn(south - maxD, south + maxD)
    }

    fun clampSouthM(southM: Float, northM: Float, arrayL: Float): Float {
        val north = clampM(northM)
        val maxD = maxDeltaM(arrayL)
        return clampM(southM).coerceIn(north - maxD, north + maxD)
    }

    fun clampPair(northM: Float, southM: Float, arrayL: Float): Pair<Float, Float> {
        val north = clampM(northM)
        val south = clampSouthM(southM, north, arrayL)
        return north to south
    }
}

data class SolarArraySpec(
    val kw: Int = 3,
    val rows: Int = 2,
    val frontPostHeightM: Float = SolarHeightLimits.DefaultNorthM,
    val southPostHeightM: Float = SolarHeightLimits.DefaultSouthM,
    val product: SolarPanelProduct,
    val panelWatts: Int = product.defaultWatts,
    val showDimensions: Boolean = true,
    val showNorthSouth: Boolean = true,
    val useMeters: Boolean = false,
) {
    val panelW: Float get() = product.widthM
    val panelL: Float get() = product.lengthM
    val panelCount: Int get() = kw * 2
    val totalKw: Float get() = panelCount * panelWatts / 1000f
    val cols: Int get() = (panelCount / rows).coerceAtLeast(1)
    val arrayL: Float get() = SolarHeightLimits.arrayLengthM(rows, panelL)

    val northHeightM: Float
        get() = SolarHeightLimits.clampNorthM(frontPostHeightM, southPostHeightM, arrayL)

    val southHeightM: Float
        get() = SolarHeightLimits.clampSouthM(southPostHeightM, northHeightM, arrayL)

    val tiltDeg: Float
        get() {
            val sinT = ((southHeightM - northHeightM) / arrayL).coerceIn(
                -SolarHeightLimits.MaxSlopeSin,
                SolarHeightLimits.MaxSlopeSin,
            )
            return Math.toDegrees(asin(sinT.toDouble())).toFloat()
        }
}

object SolarArrayDims {
    const val PanelW = 1.2192f
    const val PanelL = 2.286f
    const val Gap = 0.025f
    const val Post = 0.05f
    const val RafterW = 0.05f
    const val RafterH = 0.05f
    const val RailW = 0.04f
    const val RailH = 0.04f
    const val Plate = 0.15f
    const val PlateT = 0.008f
    const val Brace = 0.025f
    const val PostInsetM = 0.35f
    const val MaxPanels = 10
    const val PanelAsset = "models/solar_panel.glb"
    const val PanelThickness = 0.035f
    const val SetupBufferFt = 1f
    val SetupBufferM = SetupBufferFt * SolarHeightLimits.FtToM
}

data class Vec3(val x: Float, val y: Float, val z: Float)

data class SolarArrayLayout(
    val spec: SolarArraySpec,
    val arrayW: Float,
    val arrayL: Float,
    val yLift: Float,
    val cosT: Float,
    val sinT: Float,
    val supportX: FloatArray,
    val supportS: FloatArray,
    val panelCenters: List<Pair<Float, Float>>,
    val purlinS: List<Float>,
    val footprintW: Float,
    val footprintL: Float,
    val rearHeightM: Float,
) {
    fun slopeToWorld(x: Float, yLocal: Float, s: Float): Vec3 {
        return Vec3(
            x = x,
            y = yLocal * cosT + s * -sinT + yLift,
            z = yLocal * sinT + s * cosT,
        )
    }
}

object SolarArrayLayoutEngine {
    fun compute(spec: SolarArraySpec): SolarArrayLayout {
        val cols = spec.cols
        val rows = spec.rows
        val panelW = spec.panelW
        val panelL = spec.panelL
        val arrayW = cols * panelW + (cols - 1) * SolarArrayDims.Gap
        val arrayL = spec.arrayL
        val north = spec.northHeightM
        val south = spec.southHeightM
        val sinT = ((south - north) / arrayL).coerceIn(
            -SolarHeightLimits.MaxSlopeSin,
            SolarHeightLimits.MaxSlopeSin,
        )
        val cosT = sqrt((1f - sinT * sinT).coerceAtLeast(0f))
        val yLift = (north + south) / 2f
        val pitchX = panelW + SolarArrayDims.Gap
        val pitchS = panelL + SolarArrayDims.Gap
        val originX = (cols - 1) * pitchX / 2f
        val originS = (rows - 1) * pitchS / 2f
        val centers = buildList {
            for (row in 0 until rows) {
                val cs = originS - row * pitchS
                for (col in 0 until cols) {
                    add((col * pitchX - originX) to cs)
                }
            }
        }
        val insetX = min(SolarArrayDims.PostInsetM, arrayW * 0.25f)
        val insetS = min(SolarArrayDims.PostInsetM, arrayL * 0.25f)
        val cornerX = (arrayW / 2f - insetX).coerceAtLeast(arrayW * 0.15f)
        val cornerS = (arrayL / 2f - insetS).coerceAtLeast(arrayL * 0.15f)
        val supportX = floatArrayOf(-cornerX, cornerX)
        val supportS = floatArrayOf(-cornerS, cornerS)
        val purlinS = buildList {
            for (row in 0 until rows) {
                val cs = originS - row * pitchS
                add(cs + panelL * 0.22f)
                add(cs - panelL * 0.22f)
            }
        }
        return SolarArrayLayout(
            spec = spec,
            arrayW = arrayW,
            arrayL = arrayL,
            yLift = yLift,
            cosT = cosT,
            sinT = sinT,
            supportX = supportX,
            supportS = supportS,
            panelCenters = centers,
            purlinS = purlinS,
            footprintW = arrayW + SolarArrayDims.SetupBufferM,
            footprintL = arrayL * cosT + SolarArrayDims.SetupBufferM,
            rearHeightM = south,
        )
    }
}

object SolarPanelExtras {
    const val EXTRA_ID = "id"
    const val EXTRA_COMPANY_NAME = "companyName"
    const val EXTRA_WIDTH_M = "widthM"
    const val EXTRA_LENGTH_M = "lengthM"
    const val EXTRA_MIN_WATTS = "minWatts"
    const val EXTRA_MAX_WATTS = "maxWatts"
    const val EXTRA_DEFAULT_WATTS = "defaultWatts"
    const val EXTRA_WATT_STEP = "wattStep"
    const val EXTRA_AUTH_TOKEN = "authToken"
    const val EXTRA_API_BASE_URL = "apiBaseUrl"

    fun productFromIntent(intent: Intent): SolarPanelProduct {
        val minW = intent.getIntExtra(EXTRA_MIN_WATTS, 500)
        val maxW = intent.getIntExtra(EXTRA_MAX_WATTS, 630)
        val defaultW = intent.getIntExtra(EXTRA_DEFAULT_WATTS, minW)
        return SolarPanelProduct(
            id = intent.getStringExtra(EXTRA_ID) ?: "panel",
            companyName = intent.getStringExtra(EXTRA_COMPANY_NAME) ?: "Solar panel",
            widthM = intent.getDoubleExtra(EXTRA_WIDTH_M, SolarArrayDims.PanelW.toDouble()).toFloat(),
            lengthM = intent.getDoubleExtra(EXTRA_LENGTH_M, SolarArrayDims.PanelL.toDouble()).toFloat(),
            minWatts = minW,
            maxWatts = maxW.coerceAtLeast(minW),
            defaultWatts = defaultW.coerceIn(minW, maxW.coerceAtLeast(minW)),
            wattStep = intent.getIntExtra(EXTRA_WATT_STEP, 10).coerceAtLeast(1),
        )
    }

    fun putProduct(intent: Intent, product: SolarPanelProduct) {
        intent.putExtra(EXTRA_ID, product.id)
        intent.putExtra(EXTRA_COMPANY_NAME, product.companyName)
        intent.putExtra(EXTRA_WIDTH_M, product.widthM.toDouble())
        intent.putExtra(EXTRA_LENGTH_M, product.lengthM.toDouble())
        intent.putExtra(EXTRA_MIN_WATTS, product.minWatts)
        intent.putExtra(EXTRA_MAX_WATTS, product.maxWatts)
        intent.putExtra(EXTRA_DEFAULT_WATTS, product.defaultWatts)
        intent.putExtra(EXTRA_WATT_STEP, product.wattStep)
    }
}
