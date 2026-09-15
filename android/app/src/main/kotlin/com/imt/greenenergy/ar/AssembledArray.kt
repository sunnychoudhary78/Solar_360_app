package com.imt.greenenergy.ar

import androidx.compose.runtime.Composable
import androidx.compose.runtime.key
import androidx.compose.runtime.remember
import com.google.android.filament.MaterialInstance
import io.github.sceneview.NodeScope
import io.github.sceneview.loaders.MaterialLoader
import io.github.sceneview.loaders.ModelLoader
import io.github.sceneview.math.Position
import io.github.sceneview.math.Rotation
import io.github.sceneview.math.Scale
import io.github.sceneview.math.Size
import io.github.sceneview.node.CubeNode
import io.github.sceneview.node.ModelNode
import io.github.sceneview.node.Node
import io.github.sceneview.node.TextNode
import kotlin.math.atan2
import kotlin.math.hypot

private const val RafterY = -SolarArrayDims.RafterH * 0.5f - 0.002f
private const val RailY = -SolarArrayDims.RafterH - SolarArrayDims.RailH * 0.5f - 0.004f
private const val UnitPost = SolarArrayDims.Post

@Composable
fun NodeScope.AssembledArray(
    spec: SolarArraySpec,
    modelLoader: ModelLoader,
    materialLoader: MaterialLoader,
) {
    val layout = remember(spec) { SolarArrayLayoutEngine.compute(spec) }
    val grid = layout
    val panelInstances = remember(modelLoader, spec.product.asset) {
        modelLoader.createInstancedModel(spec.product.asset, SolarArrayDims.MaxPanels)
    }
    val steel = remember(materialLoader) {
        materialLoader.createColorInstance(
            SolarArrayLook.Steel,
            metallic = 0.90f,
            roughness = 0.34f,
        )
    }
    val aluminum = remember(materialLoader) {
        materialLoader.createColorInstance(
            SolarArrayLook.Aluminum,
            metallic = 0.94f,
            roughness = 0.22f,
        )
    }
    val grass = remember(materialLoader) {
        materialLoader.createColorInstance(
            SolarArrayLook.Grass,
            metallic = 0f,
            roughness = 0.92f,
        )
    }
    val concrete = remember(materialLoader) {
        materialLoader.createColorInstance(
            SolarArrayLook.Concrete,
            metallic = 0.08f,
            roughness = 0.78f,
        )
    }
    val tilt = Rotation(x = spec.tiltDeg)
    val groundCube = remember { Size(1f, 1f, 1f) }

    panelInstances.forEachIndexed { index, instance ->
        val center = layout.panelCenters.getOrNull(index)
        val world = if (center != null) {
            layout.slopeToWorld(center.first, 0f, center.second)
        } else {
            null
        }
        key("panel-$index") {
            Node(
                isVisible = world != null,
                position = if (world != null) {
                    Position(world.x, world.y, world.z)
                } else {
                    Position(y = -20f)
                },
                rotation = tilt,
                scale = Scale(x = spec.product.scaleX, y = 1f, z = spec.product.scaleZ),
            ) {
                ModelNode(
                    modelInstance = instance,
                    autoAnimate = false,
                    isEditable = false,
                )
            }
        }
    }

    Node(
        position = Position(y = -0.02f),
        scale = Scale(
            x = layout.footprintW * SolarArrayDims.SitePadScale,
            y = 0.03f,
            z = layout.footprintL * SolarArrayDims.SitePadScale,
        ),
    ) {
        CubeNode(
            size = groundCube,
            materialInstance = grass,
        )
    }

    Node(
        position = Position(y = 0.018f),
        scale = Scale(x = layout.footprintW, y = 0.036f, z = layout.footprintL),
    ) {
        CubeNode(
            size = groundCube,
            materialInstance = concrete,
        )
    }

    Node(
        position = Position(y = layout.yLift),
        rotation = Rotation(x = spec.tiltDeg),
    ) {
        SlopeRacking(
            grid = grid,
            steel = steel,
            aluminum = aluminum,
        )
        Node(isVisible = spec.showNorthSouth) {
            NorthSouthMarks(
                layout = layout,
                materialLoader = materialLoader,
            )
        }
    }

    WorldPosts(
        layout = layout,
        grid = grid,
        steel = steel,
    )

    Node(isVisible = spec.showDimensions) {
        SetupDimensionMarks(
            layout = layout,
            materialLoader = materialLoader,
            useMeters = spec.useMeters,
        )
    }
}

@Composable
private fun NodeScope.SlopeRacking(
    grid: SolarArrayLayout,
    steel: MaterialInstance,
    aluminum: MaterialInstance,
) {
    val cx = grid.supportX[1]
    val cs = grid.supportS[1]
    val rimNsSize = remember(cs) {
        Size(SolarArrayDims.RafterW, SolarArrayDims.RafterH, cs * 2f)
    }
    val rimEwSize = remember(cx) {
        Size(cx * 2f, SolarArrayDims.RafterH, SolarArrayDims.RafterW)
    }
    val purlinSize = remember(grid.arrayW) {
        Size(grid.arrayW + 0.06f, SolarArrayDims.RailH, SolarArrayDims.RailW)
    }
    val diagLength = hypot(cx * 2f, cs * 2f).coerceAtLeast(0.05f)
    val diagSize = remember(diagLength) {
        Size(SolarArrayDims.Brace, SolarArrayDims.Brace, diagLength)
    }
    val diagYawSe = Math.toDegrees(atan2(cx * 2f, cs * 2f).toDouble()).toFloat()
    val diagYawSw = Math.toDegrees(atan2(-cx * 2f, cs * 2f).toDouble()).toFloat()

    grid.supportX.forEachIndexed { index, x ->
        key("rim-ns-$index") {
            CubeNode(
                size = rimNsSize,
                position = Position(x, RafterY, 0f),
                materialInstance = steel,
            )
        }
    }
    grid.supportS.forEachIndexed { index, s ->
        key("rim-ew-$index") {
            CubeNode(
                size = rimEwSize,
                position = Position(0f, RafterY, s),
                materialInstance = steel,
            )
        }
    }
    key("diag-0") {
        CubeNode(
            size = diagSize,
            position = Position(0f, RafterY, 0f),
            rotation = Rotation(y = diagYawSe),
            materialInstance = steel,
        )
    }
    key("diag-1") {
        CubeNode(
            size = diagSize,
            position = Position(0f, RafterY, 0f),
            rotation = Rotation(y = diagYawSw),
            materialInstance = steel,
        )
    }

    grid.purlinS.forEachIndexed { index, s ->
        key("purlin-$index") {
            CubeNode(
                size = purlinSize,
                position = Position(0f, RailY, s),
                materialInstance = aluminum,
            )
        }
    }
}

@Composable
private fun NodeScope.WorldPosts(
    layout: SolarArrayLayout,
    grid: SolarArrayLayout,
    steel: MaterialInstance,
) {
    val postCube = remember { Size(UnitPost, UnitPost, UnitPost) }
    val plateCube = remember {
        Size(SolarArrayDims.Plate, SolarArrayDims.PlateT, SolarArrayDims.Plate)
    }

    grid.supportX.forEachIndexed { ix, x ->
        grid.supportS.forEachIndexed { iz, s ->
            val top = layout.slopeToWorld(x, RafterY - SolarArrayDims.RafterH * 0.5f, s)
            val height = (top.y - SolarArrayDims.PlateT).coerceAtLeast(0.05f)
            key("post-$ix-$iz") {
                Node(
                    position = Position(top.x, SolarArrayDims.PlateT + height * 0.5f, top.z),
                    scale = Scale(x = 1f, y = height / UnitPost, z = 1f),
                ) {
                    CubeNode(size = postCube, materialInstance = steel)
                }
            }
            key("plate-$ix-$iz") {
                Node(
                    position = Position(top.x, SolarArrayDims.PlateT * 0.5f, top.z),
                ) {
                    CubeNode(size = plateCube, materialInstance = steel)
                }
            }
            key("cap-$ix-$iz") {
                Node(
                    position = Position(top.x, top.y + 0.012f, top.z),
                    scale = Scale(x = 0.72f, y = 2f, z = 0.72f),
                ) {
                    CubeNode(size = plateCube, materialInstance = steel)
                }
            }
        }
    }
}

@Composable
private fun NodeScope.NorthSouthMarks(
    layout: SolarArrayLayout,
    materialLoader: MaterialLoader,
) {
    val northPaint = remember(materialLoader) {
        materialLoader.createColorInstance(
            SolarArrayLook.Teal,
            metallic = 0.12f,
            roughness = 0.38f,
        )
    }
    val southPaint = remember(materialLoader) {
        materialLoader.createColorInstance(
            SolarArrayLook.Amber,
            metallic = 0.12f,
            roughness = 0.38f,
        )
    }
    val stripSize = remember(layout.arrayW) {
        Size(layout.arrayW, 0.018f, 0.08f)
    }
    val northS = -layout.arrayL / 2f
    val southS = layout.arrayL / 2f

    key("north-strip") {
        CubeNode(
            size = stripSize,
            position = Position(0f, 0.03f, northS),
            materialInstance = northPaint,
        )
    }
    key("south-strip") {
        CubeNode(
            size = stripSize,
            position = Position(0f, 0.03f, southS),
            materialInstance = southPaint,
        )
    }
    key("north-label") {
        TextNode(
            text = "NORTH",
            fontSize = 110f,
            textColor = android.graphics.Color.WHITE,
            backgroundColor = 0xCC0F766E.toInt(),
            widthMeters = 1.8f,
            heightMeters = 0.45f,
            position = Position(0f, 0.38f, northS - 0.5f),
        )
    }
    key("south-label") {
        TextNode(
            text = "SOUTH",
            fontSize = 110f,
            textColor = android.graphics.Color.WHITE,
            backgroundColor = 0xCCB45309.toInt(),
            widthMeters = 1.8f,
            heightMeters = 0.45f,
            position = Position(0f, 0.38f, southS + 0.5f),
        )
    }
}

@Composable
private fun NodeScope.SetupDimensionMarks(
    layout: SolarArrayLayout,
    materialLoader: MaterialLoader,
    useMeters: Boolean,
) {
    val paint = remember(materialLoader) {
        materialLoader.createColorInstance(
            SolarArrayLook.Amber,
            metallic = 0.14f,
            roughness = 0.42f,
        )
    }
    val halfW = layout.footprintW / 2f
    val halfL = layout.footprintL / 2f
    val widthBar = remember(layout.footprintW) {
        Size(layout.footprintW, 0.025f, 0.04f)
    }
    val lengthBar = remember(layout.footprintL) {
        Size(0.04f, 0.025f, layout.footprintL)
    }

    key("dim-width-bar") {
        CubeNode(
            size = widthBar,
            position = Position(0f, 0.05f, halfL),
            materialInstance = paint,
        )
    }
    key("dim-length-bar") {
        CubeNode(
            size = lengthBar,
            position = Position(halfW, 0.05f, 0f),
            materialInstance = paint,
        )
    }
    key("dim-width-label") {
        TextNode(
            text = SolarInsights.formatAxisMagnitude(layout.footprintW, useMeters),
            fontSize = 96f,
            textColor = android.graphics.Color.BLACK,
            backgroundColor = 0xE6FBBF24.toInt(),
            widthMeters = 1.9f,
            heightMeters = 0.42f,
            position = Position(0f, 0.32f, halfL + 0.42f),
        )
    }
    key("dim-length-label") {
        TextNode(
            text = SolarInsights.formatAxisMagnitude(layout.footprintL, useMeters),
            fontSize = 96f,
            textColor = android.graphics.Color.BLACK,
            backgroundColor = 0xE6FBBF24.toInt(),
            widthMeters = 1.9f,
            heightMeters = 0.42f,
            position = Position(halfW + 0.42f, 0.32f, 0f),
        )
    }
}
