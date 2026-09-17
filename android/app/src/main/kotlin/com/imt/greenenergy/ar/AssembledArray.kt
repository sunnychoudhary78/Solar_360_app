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
import io.github.sceneview.node.TextNode as SceneTextNode
import kotlin.math.atan2
import kotlin.math.hypot

private const val RafterY = -SolarArrayDims.RafterH * 0.5f - 0.002f
private const val RailY = -SolarArrayDims.RafterH - SolarArrayDims.RailH * 0.5f - 0.004f
private const val UnitPost = SolarArrayDims.Post
private const val MaxPurlins = 4

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
    val concrete = remember(materialLoader) {
        materialLoader.createColorInstance(
            SolarArrayLook.Concrete,
            metallic = 0.08f,
            roughness = 0.78f,
        )
    }
    val tilt = Rotation(x = spec.tiltDeg)
    val unitCube = remember { Size(1f, 1f, 1f) }

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

    // Scale updates reliably; remounting TextNodes crashes Filament textures.
    ScaledCube(
        sx = layout.footprintW,
        sy = 0.036f,
        sz = layout.footprintL,
        position = Position(y = 0.018f),
        materialInstance = concrete,
        unitCube = unitCube,
    )

    Node(
        position = Position(y = layout.yLift),
        rotation = Rotation(x = spec.tiltDeg),
        apply = {
            position = Position(y = layout.yLift)
            rotation = Rotation(x = spec.tiltDeg)
        },
    ) {
        SlopeRacking(
            grid = grid,
            steel = steel,
            aluminum = aluminum,
            unitCube = unitCube,
        )
        Node(isVisible = spec.showNorthSouth) {
            NorthSouthMarks(
                layout = layout,
                materialLoader = materialLoader,
                unitCube = unitCube,
            )
        }
    }

    WorldPosts(
        layout = layout,
        grid = grid,
        steel = steel,
        unitCube = unitCube,
    )

    SetupDimensionMarks(
        layout = layout,
        materialLoader = materialLoader,
        unitCube = unitCube,
        isVisible = spec.showDimensions,
    )
}

@Composable
private fun NodeScope.ScaledCube(
    sx: Float,
    sy: Float,
    sz: Float,
    position: Position,
    materialInstance: MaterialInstance,
    unitCube: Size,
    rotation: Rotation = Rotation(),
    isVisible: Boolean = true,
) {
    val live = remember { LiveXform() }
    live.sx = sx
    live.sy = sy
    live.sz = sz
    live.position = position
    live.rotation = rotation
    live.isVisible = isVisible
    live.node?.let { n ->
        n.isVisible = isVisible
        n.position = position
        n.rotation = rotation
        n.scale = Scale(x = sx, y = sy, z = sz)
    }
    Node(
        isVisible = isVisible,
        position = position,
        rotation = rotation,
        scale = Scale(x = sx, y = sy, z = sz),
        apply = {
            live.node = this
            this.isVisible = live.isVisible
            this.position = live.position
            this.rotation = live.rotation
            this.scale = Scale(x = live.sx, y = live.sy, z = live.sz)
        },
    ) {
        CubeNode(size = unitCube, materialInstance = materialInstance)
    }
}

@Composable
private fun NodeScope.SlopeRacking(
    grid: SolarArrayLayout,
    steel: MaterialInstance,
    aluminum: MaterialInstance,
    unitCube: Size,
) {
    val cx = grid.supportX[1]
    val cs = grid.supportS[1]
    val rimNsZ = cs * 2f
    val rimEwX = cx * 2f
    val purlinX = grid.arrayW + 0.06f
    val diagLength = hypot(cx * 2f, cs * 2f).coerceAtLeast(0.05f)
    val diagYawSe = Math.toDegrees(atan2(cx * 2f, cs * 2f).toDouble()).toFloat()
    val diagYawSw = Math.toDegrees(atan2(-cx * 2f, cs * 2f).toDouble()).toFloat()

    grid.supportX.forEachIndexed { index, x ->
        key("rim-ns-$index") {
            ScaledCube(
                sx = SolarArrayDims.RafterW,
                sy = SolarArrayDims.RafterH,
                sz = rimNsZ,
                position = Position(x, RafterY, 0f),
                materialInstance = steel,
                unitCube = unitCube,
            )
        }
    }
    grid.supportS.forEachIndexed { index, s ->
        key("rim-ew-$index") {
            ScaledCube(
                sx = rimEwX,
                sy = SolarArrayDims.RafterH,
                sz = SolarArrayDims.RafterW,
                position = Position(0f, RafterY, s),
                materialInstance = steel,
                unitCube = unitCube,
            )
        }
    }
    key("diag-0") {
        ScaledCube(
            sx = SolarArrayDims.Brace,
            sy = SolarArrayDims.Brace,
            sz = diagLength,
            position = Position(0f, RafterY, 0f),
            rotation = Rotation(y = diagYawSe),
            materialInstance = steel,
            unitCube = unitCube,
        )
    }
    key("diag-1") {
        ScaledCube(
            sx = SolarArrayDims.Brace,
            sy = SolarArrayDims.Brace,
            sz = diagLength,
            position = Position(0f, RafterY, 0f),
            rotation = Rotation(y = diagYawSw),
            materialInstance = steel,
            unitCube = unitCube,
        )
    }

    // Fixed slots so Alignment row changes hide extras instead of disposing nodes.
    repeat(MaxPurlins) { index ->
        val s = grid.purlinS.getOrNull(index)
        key("purlin-$index") {
            ScaledCube(
                sx = purlinX,
                sy = SolarArrayDims.RailH,
                sz = SolarArrayDims.RailW,
                position = Position(0f, RailY, s ?: 0f),
                materialInstance = aluminum,
                unitCube = unitCube,
                isVisible = s != null,
            )
        }
    }
}

@Composable
private fun NodeScope.WorldPosts(
    layout: SolarArrayLayout,
    grid: SolarArrayLayout,
    steel: MaterialInstance,
    unitCube: Size,
) {
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
                    scale = Scale(x = UnitPost, y = height, z = UnitPost),
                ) {
                    CubeNode(size = unitCube, materialInstance = steel)
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
                    scale = Scale(
                        x = SolarArrayDims.Plate * 0.72f,
                        y = 0.016f,
                        z = SolarArrayDims.Plate * 0.72f,
                    ),
                ) {
                    CubeNode(size = unitCube, materialInstance = steel)
                }
            }
        }
    }
}

@Composable
private fun NodeScope.NorthSouthMarks(
    layout: SolarArrayLayout,
    materialLoader: MaterialLoader,
    unitCube: Size,
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
    // -Z is north (back). +Z is south (front).
    val northS = -layout.arrayL / 2f
    val southS = layout.arrayL / 2f

    key("north-strip") {
        ScaledCube(
            sx = layout.arrayW,
            sy = 0.05f,
            sz = 0.16f,
            position = Position(0f, 0.12f, northS),
            materialInstance = northPaint,
            unitCube = unitCube,
        )
    }
    key("south-strip") {
        ScaledCube(
            sx = layout.arrayW,
            sy = 0.05f,
            sz = 0.16f,
            position = Position(0f, 0.12f, southS),
            materialInstance = southPaint,
            unitCube = unitCube,
        )
    }
    StableTextLabel(
        id = "north-label",
        text = "NORTH",
        position = Position(0f, 0.38f, northS - 0.5f),
        materialLoader = materialLoader,
        fontSize = 110f,
        textColor = android.graphics.Color.WHITE,
        backgroundColor = 0xCC0F766E.toInt(),
        widthMeters = 1.8f,
        heightMeters = 0.45f,
    )
    StableTextLabel(
        id = "south-label",
        text = "SOUTH",
        position = Position(0f, 0.38f, southS + 0.5f),
        materialLoader = materialLoader,
        fontSize = 110f,
        textColor = android.graphics.Color.WHITE,
        backgroundColor = 0xCCB45309.toInt(),
        widthMeters = 1.8f,
        heightMeters = 0.45f,
    )
}

@Composable
private fun NodeScope.SetupDimensionMarks(
    layout: SolarArrayLayout,
    materialLoader: MaterialLoader,
    unitCube: Size,
    isVisible: Boolean,
) {
    val paint = remember(materialLoader) {
        materialLoader.createColorInstance(
            SolarArrayLook.Amber,
            metallic = 0.0f,
            roughness = 0.48f,
        )
    }
    val halfW = layout.footprintW / 2f
    val halfL = layout.footprintL / 2f
    val y = 0.16f
    val barH = 0.08f
    val barT = 0.10f
    val headL = 0.42f
    val headT = 0.10f
    // +Z is south (front). Keep the whole dimension set outside that edge.
    val gap = 0.52f
    val northZ = halfL + gap
    val eastX = halfW + gap
    val d = headL * 0.35f

    key("dim-width-bar") {
        ScaledCube(
            sx = layout.footprintW,
            sy = barH,
            sz = barT,
            position = Position(0f, y, northZ),
            materialInstance = paint,
            unitCube = unitCube,
            isVisible = isVisible,
        )
    }
    key("dim-length-bar") {
        ScaledCube(
            sx = barT,
            sy = barH,
            sz = layout.footprintL,
            position = Position(eastX, y, 0f),
            materialInstance = paint,
            unitCube = unitCube,
            isVisible = isVisible,
        )
    }
    key("dim-width-arrow-left-top") {
        ScaledCube(
            sx = headL, sy = headT, sz = headT,
            position = Position(-halfW + d, y, northZ + d),
            rotation = Rotation(y = -45f),
            materialInstance = paint,
            unitCube = unitCube,
            isVisible = isVisible,
        )
    }
    key("dim-width-arrow-left-bottom") {
        ScaledCube(
            sx = headL, sy = headT, sz = headT,
            position = Position(-halfW + d, y, northZ - d),
            rotation = Rotation(y = 45f),
            materialInstance = paint,
            unitCube = unitCube,
            isVisible = isVisible,
        )
    }
    key("dim-width-arrow-right-top") {
        ScaledCube(
            sx = headL, sy = headT, sz = headT,
            position = Position(halfW - d, y, northZ + d),
            rotation = Rotation(y = -135f),
            materialInstance = paint,
            unitCube = unitCube,
            isVisible = isVisible,
        )
    }
    key("dim-width-arrow-right-bottom") {
        ScaledCube(
            sx = headL, sy = headT, sz = headT,
            position = Position(halfW - d, y, northZ - d),
            rotation = Rotation(y = 135f),
            materialInstance = paint,
            unitCube = unitCube,
            isVisible = isVisible,
        )
    }
    key("dim-length-arrow-bottom-left") {
        ScaledCube(
            sx = headT, sy = headT, sz = headL,
            position = Position(eastX - d, y, -halfL + d),
            rotation = Rotation(y = -45f),
            materialInstance = paint,
            unitCube = unitCube,
            isVisible = isVisible,
        )
    }
    key("dim-length-arrow-bottom-right") {
        ScaledCube(
            sx = headT, sy = headT, sz = headL,
            position = Position(eastX + d, y, -halfL + d),
            rotation = Rotation(y = 45f),
            materialInstance = paint,
            unitCube = unitCube,
            isVisible = isVisible,
        )
    }
    key("dim-length-arrow-top-left") {
        ScaledCube(
            sx = headT, sy = headT, sz = headL,
            position = Position(eastX - d, y, halfL + d),
            rotation = Rotation(y = -135f),
            materialInstance = paint,
            unitCube = unitCube,
            isVisible = isVisible,
        )
    }
    key("dim-length-arrow-top-right") {
        ScaledCube(
            sx = headT, sy = headT, sz = headL,
            position = Position(eastX + d, y, halfL + d),
            rotation = Rotation(y = 135f),
            materialInstance = paint,
            unitCube = unitCube,
            isVisible = isVisible,
        )
    }
    // Width/length ft text is drawn in Compose on SolarConfigScreen so it
    // stays in sync with the UTL readout. Filament TextNode textures do not.
}

private class LiveXform {
    var sx: Float = 1f
    var sy: Float = 1f
    var sz: Float = 1f
    var position: Position = Position()
    var rotation: Rotation = Rotation()
    var isVisible: Boolean = true
    var node: Node? = null
}

private class LiveText(
    var value: String,
    var position: Position,
    var visible: Boolean,
    var wrapper: Node? = null,
)

@Composable
private fun NodeScope.StableTextLabel(
    id: String,
    text: String,
    position: Position,
    materialLoader: MaterialLoader,
    fontSize: Float,
    textColor: Int,
    backgroundColor: Int,
    widthMeters: Float,
    heightMeters: Float,
    isVisible: Boolean = true,
) {
    val node = remember(id, materialLoader) {
        SceneTextNode(
            materialLoader = materialLoader,
            text = text,
            fontSize = fontSize,
            textColor = textColor,
            backgroundColor = backgroundColor,
            widthMeters = widthMeters,
            heightMeters = heightMeters,
        )
    }
    val faceCamera = remember(node) { node.onFrame }
    val live = remember(id) { LiveText(text, position, isVisible) }
    live.value = text
    live.position = position
    live.visible = isVisible
    // Official TextNode API re-uploads the Filament texture when UTL width/length change.
    if (node.text != text) {
        node.text = text
    }
    node.isVisible = isVisible
    node.onFrame = { frameTime ->
        faceCamera?.invoke(frameTime)
        val pending = live.value
        if (node.text != pending) {
            node.text = pending
        }
        node.isVisible = live.visible
    }
    live.wrapper?.let { wrapper ->
        wrapper.isVisible = isVisible
        wrapper.position = position
    }
    Node(
        isVisible = isVisible,
        position = position,
        apply = {
            live.wrapper = this
            if (node.parent !== this) {
                node.position = Position()
                addChildNode(node)
            }
            this.isVisible = live.visible
            this.position = live.position
            node.isVisible = live.visible
            if (node.text != live.value) {
                node.text = live.value
            }
        },
    )
}
