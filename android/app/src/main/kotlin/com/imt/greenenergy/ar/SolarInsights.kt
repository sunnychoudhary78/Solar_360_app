package com.imt.greenenergy.ar

object SolarInsights {
    fun formatTotalKw(spec: SolarArraySpec): String = "%.2f kW".format(spec.totalKw)

    fun formatPanelMix(spec: SolarArraySpec): String =
        "${spec.panelCount} × ${spec.panelWatts}W"

    fun formatCompanyWatts(spec: SolarArraySpec): String =
        "${spec.product.companyName}  ·  ${spec.panelWatts}W"

    fun formatProductSize(product: SolarPanelProduct): String {
        val widthFt = SolarHeightLimits.metersToFeet(product.widthM)
        val lengthFt = SolarHeightLimits.metersToFeet(product.lengthM)
        return "${"%.1f".format(widthFt)} × ${"%.1f".format(lengthFt)} ft"
    }

    fun formatSetup(layout: SolarArrayLayout, useMeters: Boolean = false): String {
        return if (useMeters) {
            "${"%.2f".format(layout.footprintW)} × ${"%.2f".format(layout.footprintL)} m"
        } else {
            val widthFt = SolarHeightLimits.metersToFeet(layout.footprintW)
            val lengthFt = SolarHeightLimits.metersToFeet(layout.footprintL)
            "${"%.1f".format(widthFt)} × ${"%.1f".format(lengthFt)} ft"
        }
    }

    fun formatAxisMagnitude(meters: Float, useMeters: Boolean): String {
        return if (useMeters) {
            "${"%.2f".format(meters)} m"
        } else {
            "${"%.1f".format(SolarHeightLimits.metersToFeet(meters))} ft"
        }
    }
}
