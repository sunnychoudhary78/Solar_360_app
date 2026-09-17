package com.imt.greenenergy.ar

import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.sin
import org.json.JSONArray
import org.json.JSONObject

object SolarArrayGlbExporter {
    private const val RafterY = -SolarArrayDims.RafterH * 0.5f - 0.002f
    private const val RailY = -SolarArrayDims.RafterH - SolarArrayDims.RailH * 0.5f - 0.004f

    fun export(spec: SolarArraySpec): ByteArray {
        val layout = SolarArrayLayoutEngine.compute(spec)
        val builder = GlbBuilder()
        val glassMat = builder.material(SolarArrayLook.GlassRgb, metallic = 0.35f, roughness = 0.12f)
        val frameMat = builder.material(SolarArrayLook.FrameRgb, metallic = 0.88f, roughness = 0.28f)
        val busMat = builder.material(SolarArrayLook.BusbarRgb, metallic = 0.82f, roughness = 0.32f)
        val steelMat = builder.material(SolarArrayLook.SteelRgb, metallic = 0.90f, roughness = 0.34f)
        val aluMat = builder.material(SolarArrayLook.AluminumRgb, metallic = 0.94f, roughness = 0.22f)
        val concreteMat = builder.material(SolarArrayLook.ConcreteRgb, metallic = 0.08f, roughness = 0.78f)

        // Match in-app preview: concrete pad only (no green site pad).
        builder.box(
            cx = 0f, cy = 0.018f, cz = 0f,
            sx = layout.footprintW, sy = 0.036f, sz = layout.footprintL,
            rotXDeg = 0f, material = concreteMat,
        )

        val tilt = spec.tiltDeg
        layout.panelCenters.forEach { (x, s) ->
            val world = layout.slopeToWorld(x, 0f, s)
            addFramedPanel(
                builder = builder,
                cx = world.x, cy = world.y, cz = world.z,
                panelW = spec.panelW, panelL = spec.panelL,
                rotXDeg = tilt,
                glassMat = glassMat,
                frameMat = frameMat,
                busMat = busMat,
            )
        }

        val cx = layout.supportX[1]
        val cs = layout.supportS[1]
        layout.supportX.forEach { x ->
            addSlopeBox(builder, layout, x, RafterY, 0f, SolarArrayDims.RafterW, SolarArrayDims.RafterH, cs * 2f, steelMat)
        }
        layout.supportS.forEach { s ->
            addSlopeBox(builder, layout, 0f, RafterY, s, cx * 2f, SolarArrayDims.RafterH, SolarArrayDims.RafterW, steelMat)
        }
        val diagLength = hypot(cx * 2f, cs * 2f).coerceAtLeast(0.05f)
        val diagYawSe = Math.toDegrees(kotlin.math.atan2(cx * 2f, cs * 2f).toDouble()).toFloat()
        val diagYawSw = Math.toDegrees(kotlin.math.atan2(-cx * 2f, cs * 2f).toDouble()).toFloat()
        addSlopeBox(builder, layout, 0f, RafterY, 0f, SolarArrayDims.Brace, SolarArrayDims.Brace, diagLength, steelMat, yawDeg = diagYawSe)
        addSlopeBox(builder, layout, 0f, RafterY, 0f, SolarArrayDims.Brace, SolarArrayDims.Brace, diagLength, steelMat, yawDeg = diagYawSw)
        layout.purlinS.forEach { s ->
            addSlopeBox(builder, layout, 0f, RailY, s, layout.arrayW + 0.06f, SolarArrayDims.RailH, SolarArrayDims.RailW, aluMat)
        }

        layout.supportX.forEach { x ->
            layout.supportS.forEach { s ->
                val top = layout.slopeToWorld(x, RafterY - SolarArrayDims.RafterH * 0.5f, s)
                val height = (top.y - SolarArrayDims.PlateT).coerceAtLeast(0.05f)
                builder.box(
                    cx = top.x, cy = SolarArrayDims.PlateT + height * 0.5f, cz = top.z,
                    sx = SolarArrayDims.Post, sy = height, sz = SolarArrayDims.Post,
                    rotXDeg = 0f, material = steelMat,
                )
                builder.box(
                    cx = top.x, cy = SolarArrayDims.PlateT * 0.5f, cz = top.z,
                    sx = SolarArrayDims.Plate, sy = SolarArrayDims.PlateT, sz = SolarArrayDims.Plate,
                    rotXDeg = 0f, material = steelMat,
                )
                builder.box(
                    cx = top.x, cy = top.y + 0.012f, cz = top.z,
                    sx = SolarArrayDims.Plate * 0.72f, sy = 0.016f, sz = SolarArrayDims.Plate * 0.72f,
                    rotXDeg = 0f, material = steelMat,
                )
            }
        }

        return builder.toGlb("rooftop_array")
    }

    private fun addFramedPanel(
        builder: GlbBuilder,
        cx: Float,
        cy: Float,
        cz: Float,
        panelW: Float,
        panelL: Float,
        rotXDeg: Float,
        glassMat: Int,
        frameMat: Int,
        busMat: Int,
    ) {
        val frame = SolarArrayDims.FrameW
        val glassW = (panelW - frame * 2f).coerceAtLeast(panelW * 0.82f)
        val glassL = (panelL - frame * 2f).coerceAtLeast(panelL * 0.82f)
        val frameH = SolarArrayDims.PanelThickness + SolarArrayDims.FrameLift
        fun place(lx: Float, ly: Float, lz: Float, sx: Float, sy: Float, sz: Float, mat: Int) {
            val o = tiltedOffset(lx, ly, lz, rotXDeg)
            builder.box(
                cx = cx + o[0], cy = cy + o[1], cz = cz + o[2],
                sx = sx, sy = sy, sz = sz,
                rotXDeg = rotXDeg, material = mat,
            )
        }
        place(0f, SolarArrayDims.FrameLift, 0f, glassW, SolarArrayDims.PanelThickness, glassL, glassMat)
        place(0f, 0f, (panelL - frame) * 0.5f, panelW, frameH, frame, frameMat)
        place(0f, 0f, -(panelL - frame) * 0.5f, panelW, frameH, frame, frameMat)
        place((panelW - frame) * 0.5f, 0f, 0f, frame, frameH, glassL, frameMat)
        place(-(panelW - frame) * 0.5f, 0f, 0f, frame, frameH, glassL, frameMat)
        val bus = SolarArrayDims.BusbarW
        val busL = glassL * 0.72f
        val busY = SolarArrayDims.FrameLift + 0.004f
        place(panelW * 0.16f, busY, 0f, bus, 0.004f, busL, busMat)
        place(-panelW * 0.16f, busY, 0f, bus, 0.004f, busL, busMat)
    }

    private fun tiltedOffset(lx: Float, ly: Float, lz: Float, rotXDeg: Float): FloatArray {
        if (rotXDeg == 0f) return floatArrayOf(lx, ly, lz)
        val rx = Math.toRadians(rotXDeg.toDouble())
        val cr = cos(rx).toFloat()
        val sr = sin(rx).toFloat()
        return floatArrayOf(lx, ly * cr - lz * sr, ly * sr + lz * cr)
    }

    private fun addSlopeBox(
        builder: GlbBuilder,
        layout: SolarArrayLayout,
        x: Float,
        yLocal: Float,
        s: Float,
        sx: Float,
        sy: Float,
        sz: Float,
        material: Int,
        yawDeg: Float = 0f,
    ) {
        val world = layout.slopeToWorld(x, yLocal, s)
        builder.box(
            cx = world.x, cy = world.y, cz = world.z,
            sx = sx, sy = sy, sz = sz,
            rotXDeg = layout.spec.tiltDeg,
            yawDeg = yawDeg,
            material = material,
        )
    }
}

private class GlbBuilder {
    private val bin = ArrayList<Byte>()
    private val primitives = JSONArray()
    private val materials = JSONArray()
    private val accessors = JSONArray()
    private val bufferViews = JSONArray()

    fun material(color: FloatArray, metallic: Float, roughness: Float): Int {
        val index = materials.length()
        materials.put(
            JSONObject()
                .put("pbrMetallicRoughness", JSONObject()
                    .put("baseColorFactor", JSONArray().put(color[0]).put(color[1]).put(color[2]).put(1.0))
                    .put("metallicFactor", metallic)
                    .put("roughnessFactor", roughness))
        )
        return index
    }

    fun box(
        cx: Float, cy: Float, cz: Float,
        sx: Float, sy: Float, sz: Float,
        rotXDeg: Float,
        material: Int,
        yawDeg: Float = 0f,
    ) {
        val hx = sx / 2f
        val hy = sy / 2f
        val hz = sz / 2f
        val corners = arrayOf(
            floatArrayOf(-hx, -hy, -hz),
            floatArrayOf(hx, -hy, -hz),
            floatArrayOf(hx, hy, -hz),
            floatArrayOf(-hx, hy, -hz),
            floatArrayOf(-hx, -hy, hz),
            floatArrayOf(hx, -hy, hz),
            floatArrayOf(hx, hy, hz),
            floatArrayOf(-hx, hy, hz),
        )
        val faces = arrayOf(
            intArrayOf(0, 1, 2, 0, 2, 3),
            intArrayOf(5, 4, 7, 5, 7, 6),
            intArrayOf(4, 0, 3, 4, 3, 7),
            intArrayOf(1, 5, 6, 1, 6, 2),
            intArrayOf(3, 2, 6, 3, 6, 7),
            intArrayOf(4, 5, 1, 4, 1, 0),
        )
        val positions = ArrayList<Float>(faces.size * 6 * 3)
        val normals = ArrayList<Float>(faces.size * 6 * 3)
        val indices = ArrayList<Int>(faces.size * 6)
        var vi = 0
        for (face in faces) {
            val a = transform(corners[face[0]], cx, cy, cz, rotXDeg, yawDeg)
            val b = transform(corners[face[1]], cx, cy, cz, rotXDeg, yawDeg)
            val c = transform(corners[face[2]], cx, cy, cz, rotXDeg, yawDeg)
            val n = normal(a, b, c)
            for (tri in 0 until 2) {
                val i0 = face[tri * 3]
                val i1 = face[tri * 3 + 1]
                val i2 = face[tri * 3 + 2]
                val p0 = transform(corners[i0], cx, cy, cz, rotXDeg, yawDeg)
                val p1 = transform(corners[i1], cx, cy, cz, rotXDeg, yawDeg)
                val p2 = transform(corners[i2], cx, cy, cz, rotXDeg, yawDeg)
                positions.addAll(p0.toList())
                positions.addAll(p1.toList())
                positions.addAll(p2.toList())
                repeat(3) { normals.addAll(n.toList()) }
                indices.add(vi++)
                indices.add(vi++)
                indices.add(vi++)
            }
        }
        addMesh(positions, normals, indices, material)
    }

    private fun transform(p: FloatArray, cx: Float, cy: Float, cz: Float, rotXDeg: Float, yawDeg: Float): FloatArray {
        var x = p[0]
        var y = p[1]
        var z = p[2]
        if (yawDeg != 0f) {
            val yaw = Math.toRadians(yawDeg.toDouble())
            val cyaw = cos(yaw).toFloat()
            val syaw = sin(yaw).toFloat()
            val nx = x * cyaw + z * syaw
            val nz = -x * syaw + z * cyaw
            x = nx
            z = nz
        }
        if (rotXDeg != 0f) {
            val rx = Math.toRadians(rotXDeg.toDouble())
            val cr = cos(rx).toFloat()
            val sr = sin(rx).toFloat()
            val ny = y * cr - z * sr
            val nz = y * sr + z * cr
            y = ny
            z = nz
        }
        return floatArrayOf(x + cx, y + cy, z + cz)
    }

    private fun normal(a: FloatArray, b: FloatArray, c: FloatArray): FloatArray {
        val ux = b[0] - a[0]
        val uy = b[1] - a[1]
        val uz = b[2] - a[2]
        val vx = c[0] - a[0]
        val vy = c[1] - a[1]
        val vz = c[2] - a[2]
        val nx = uy * vz - uz * vy
        val ny = uz * vx - ux * vz
        val nz = ux * vy - uy * vx
        val len = hypot(hypot(nx.toDouble(), ny.toDouble()), nz.toDouble()).toFloat().coerceAtLeast(1e-6f)
        return floatArrayOf(nx / len, ny / len, nz / len)
    }

    private fun addMesh(positions: List<Float>, normals: List<Float>, indices: List<Int>, material: Int) {
        val posView = writeFloats(positions)
        val nrmView = writeFloats(normals)
        val idxView = writeIndices(indices)
        val posAcc = accessors.length()
        accessors.put(accessor(posView, "VEC3", positions.size / 3, min3(positions), max3(positions)))
        val nrmAcc = accessors.length()
        accessors.put(accessor(nrmView, "VEC3", normals.size / 3, null, null))
        val idxAcc = accessors.length()
        accessors.put(
            JSONObject()
                .put("bufferView", idxView)
                .put("componentType", 5123)
                .put("count", indices.size)
                .put("type", "SCALAR")
        )
        primitives.put(
            JSONObject()
                .put("attributes", JSONObject().put("POSITION", posAcc).put("NORMAL", nrmAcc))
                .put("indices", idxAcc)
                .put("material", material)
        )
    }

    private fun accessor(view: Int, type: String, count: Int, min: JSONArray?, max: JSONArray?): JSONObject {
        val obj = JSONObject()
            .put("bufferView", view)
            .put("componentType", 5126)
            .put("count", count)
            .put("type", type)
        if (min != null) obj.put("min", min)
        if (max != null) obj.put("max", max)
        return obj
    }

    private fun min3(values: List<Float>): JSONArray {
        var x = Float.POSITIVE_INFINITY
        var y = Float.POSITIVE_INFINITY
        var z = Float.POSITIVE_INFINITY
        var i = 0
        while (i < values.size) {
            x = minOf(x, values[i])
            y = minOf(y, values[i + 1])
            z = minOf(z, values[i + 2])
            i += 3
        }
        return JSONArray().put(x.toDouble()).put(y.toDouble()).put(z.toDouble())
    }

    private fun max3(values: List<Float>): JSONArray {
        var x = Float.NEGATIVE_INFINITY
        var y = Float.NEGATIVE_INFINITY
        var z = Float.NEGATIVE_INFINITY
        var i = 0
        while (i < values.size) {
            x = maxOf(x, values[i])
            y = maxOf(y, values[i + 1])
            z = maxOf(z, values[i + 2])
            i += 3
        }
        return JSONArray().put(x.toDouble()).put(y.toDouble()).put(z.toDouble())
    }

    private fun writeFloats(values: List<Float>): Int {
        pad4()
        val offset = bin.size
        for (v in values) {
            val bits = java.lang.Float.floatToIntBits(v)
            bin.add((bits and 0xff).toByte())
            bin.add((bits shr 8 and 0xff).toByte())
            bin.add((bits shr 16 and 0xff).toByte())
            bin.add((bits shr 24 and 0xff).toByte())
        }
        val index = bufferViews.length()
        bufferViews.put(
            JSONObject().put("buffer", 0).put("byteOffset", offset).put("byteLength", values.size * 4)
        )
        return index
    }

    private fun writeIndices(values: List<Int>): Int {
        pad4()
        val offset = bin.size
        for (v in values) {
            val s = v.coerceIn(0, 65535)
            bin.add((s and 0xff).toByte())
            bin.add((s shr 8 and 0xff).toByte())
        }
        pad4()
        val index = bufferViews.length()
        bufferViews.put(
            JSONObject().put("buffer", 0).put("byteOffset", offset).put("byteLength", values.size * 2)
        )
        return index
    }

    private fun pad4() {
        while (bin.size % 4 != 0) bin.add(0.toByte())
    }

    fun toGlb(name: String): ByteArray {
        pad4()
        val gltf = JSONObject()
            .put("asset", JSONObject().put("version", "2.0").put("generator", "solar360/ar"))
            .put("scene", 0)
            .put("scenes", JSONArray().put(JSONObject().put("nodes", JSONArray().put(0)).put("name", name)))
            .put("nodes", JSONArray().put(JSONObject().put("mesh", 0).put("name", name)))
            .put("meshes", JSONArray().put(JSONObject().put("name", name).put("primitives", primitives)))
            .put("materials", materials)
            .put("accessors", accessors)
            .put("bufferViews", bufferViews)
            .put("buffers", JSONArray().put(JSONObject().put("byteLength", bin.size)))
        val json = StringBuilder(gltf.toString())
        while (json.length % 4 != 0) json.append(' ')
        val jsonBytes = json.toString().toByteArray(Charsets.UTF_8)
        val binBytes = ByteArray(bin.size) { bin[it] }
        val total = 12 + 8 + jsonBytes.size + 8 + binBytes.size
        val out = java.io.ByteArrayOutputStream(total)
        fun writeInt(v: Int) {
            out.write(v and 0xff)
            out.write(v shr 8 and 0xff)
            out.write(v shr 16 and 0xff)
            out.write(v shr 24 and 0xff)
        }
        out.write(byteArrayOf('g'.code.toByte(), 'l'.code.toByte(), 'T'.code.toByte(), 'F'.code.toByte()))
        writeInt(2)
        writeInt(total)
        writeInt(jsonBytes.size)
        writeInt(0x4E4F534A)
        out.write(jsonBytes)
        writeInt(binBytes.size)
        writeInt(0x004E4942)
        out.write(binBytes)
        return out.toByteArray()
    }
}
