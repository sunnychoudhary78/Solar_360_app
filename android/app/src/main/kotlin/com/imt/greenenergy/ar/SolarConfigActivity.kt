package com.imt.greenenergy.ar

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ViewInAr
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import io.github.sceneview.RenderQuality
import io.github.sceneview.SceneView
import io.github.sceneview.math.Position
import io.github.sceneview.node.Node
import io.github.sceneview.rememberCameraManipulator
import io.github.sceneview.rememberEngine
import io.github.sceneview.rememberMaterialLoader
import io.github.sceneview.rememberModelLoader
import kotlin.math.abs
import kotlin.math.max
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class SolarConfigActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val product = SolarPanelExtras.productFromIntent(intent)
        val authToken = intent.getStringExtra(SolarPanelExtras.EXTRA_AUTH_TOKEN).orEmpty()
        val apiBaseUrl = intent.getStringExtra(SolarPanelExtras.EXTRA_API_BASE_URL).orEmpty()
        enableEdgeToEdge()
        setContent {
            MaterialTheme(colorScheme = darkColorScheme()) {
                SolarConfigScreen(
                    product = product,
                    authToken = authToken,
                    apiBaseUrl = apiBaseUrl,
                    onClose = { finish() },
                    onOpenGoogle = { fileUrl, title -> openWithGoogle(fileUrl, title) },
                )
            }
        }
    }

    private fun openWithGoogle(fileUrl: String, title: String) {
        val sceneViewerUri = Uri.parse(SCENE_VIEWER_BASE).buildUpon()
            .appendQueryParameter("file", fileUrl)
            .appendQueryParameter("mode", "ar_preferred")
            .appendQueryParameter("resizable", "false")
            .appendQueryParameter("title", title)
            .build()
        Log.i(ArModelUploader.TAG, "Scene Viewer URI $sceneViewerUri")
        val intent = Intent(Intent.ACTION_VIEW, sceneViewerUri).apply {
            setPackage(GOOGLE_APP_PACKAGE)
        }
        try {
            startActivity(intent)
        } catch (_: ActivityNotFoundException) {
            throw IllegalStateException(
                "The Google app is not installed or is out of date. Install or update it, then try again.",
            )
        }
    }

    companion object {
        private const val GOOGLE_APP_PACKAGE = "com.google.android.googlequicksearchbox"
        private const val SCENE_VIEWER_BASE = "https://arvr.google.com/scene-viewer/1.0"
    }
}

@Composable
private fun SolarConfigScreen(
    product: SolarPanelProduct,
    authToken: String,
    apiBaseUrl: String,
    onClose: () -> Unit,
    onOpenGoogle: (String, String) -> Unit,
) {
    var kw by remember { mutableIntStateOf(3) }
    var rows by remember { mutableIntStateOf(2) }
    var northM by remember { mutableFloatStateOf(SolarHeightLimits.DefaultNorthM) }
    var southM by remember { mutableFloatStateOf(SolarHeightLimits.DefaultSouthM) }
    var showDimensions by remember { mutableStateOf(true) }
    var showNorthSouth by remember { mutableStateOf(true) }
    var useMeters by remember { mutableStateOf(false) }
    var panelWatts by remember { mutableIntStateOf(product.defaultWatts) }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var debugUrl by remember { mutableStateOf<String?>(null) }
    var debugHead by remember { mutableStateOf<String?>(null) }
    var copied by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    val spec = SolarArraySpec(
        kw = kw,
        rows = rows,
        frontPostHeightM = northM,
        southPostHeightM = southM,
        product = product,
        panelWatts = product.clampWatts(panelWatts),
        showDimensions = showDimensions,
        showNorthSouth = showNorthSouth,
        useMeters = useMeters,
    )
    val layout = remember(spec) { SolarArrayLayoutEngine.compute(spec) }

    LaunchedEffect(spec.arrayL) {
        val (n, s) = SolarHeightLimits.clampPair(northM, southM, spec.arrayL)
        northM = n
        southM = s
    }

    val engine = rememberEngine()
    val modelLoader = rememberModelLoader(engine)
    val materialLoader = rememberMaterialLoader(engine)
    val orbitHome = remember(product.id, product.widthM, product.lengthM) {
        val largest = SolarArraySpec(kw = 5, rows = 1, product = product, panelWatts = panelWatts)
        val frame = SolarArrayLayoutEngine.compute(largest)
        val span = max(frame.footprintW, frame.footprintL)
        val height = max(largest.northHeightM, largest.southHeightM)
        val distance = span * 1.05f + height * 0.6f + 1.8f
        Position(x = distance * 0.55f, y = height * 0.55f + distance * 0.15f, z = distance)
    }
    val cameraTarget = remember(product.id) {
        val largest = SolarArraySpec(kw = 5, rows = 1, product = product)
        Position(y = (largest.northHeightM + largest.southHeightM) * 0.5f)
    }
    val cameraManipulator = rememberCameraManipulator(
        orbitHomePosition = orbitHome,
        targetPosition = cameraTarget,
    )

    Column(modifier = Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("Design rooftop array", style = MaterialTheme.typography.titleMedium)
            IconButton(onClick = onClose) {
                Icon(Icons.Filled.Close, contentDescription = "Close")
            }
        }
        Box(modifier = Modifier.fillMaxWidth().weight(1f)) {
            SceneView(
                modifier = Modifier.fillMaxSize(),
                engine = engine,
                modelLoader = modelLoader,
                materialLoader = materialLoader,
                autoCenterContent = false,
                renderQuality = RenderQuality.Performance,
                cameraManipulator = cameraManipulator,
            ) {
                Node {
                    AssembledArray(
                        spec = spec,
                        modelLoader = modelLoader,
                        materialLoader = materialLoader,
                    )
                }
            }
            SpecReadout(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .padding(8.dp),
                spec = spec,
                layout = layout,
            )
        }
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            Text(
                SolarInsights.formatCompanyWatts(spec),
                style = MaterialTheme.typography.titleSmall,
            )
            Text(
                "Panel ${SolarInsights.formatProductSize(product)}",
                style = MaterialTheme.typography.bodySmall,
            )
            Text("Panel power", style = MaterialTheme.typography.titleSmall)
            Text("${spec.panelWatts} W", style = MaterialTheme.typography.bodyMedium)
            Slider(
                value = panelWatts.toFloat(),
                onValueChange = { value ->
                    panelWatts = product.clampWatts(value.toInt())
                },
                valueRange = product.minWatts.toFloat()..product.maxWatts.toFloat(),
                steps = product.sliderSteps.coerceAtLeast(0),
            )
            Text("System size", style = MaterialTheme.typography.titleSmall)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (option in listOf(2, 3, 4, 5)) {
                    FilterChip(
                        selected = kw == option,
                        onClick = { kw = option },
                        label = { Text("$option kW") },
                    )
                }
            }
            Text("Alignment", style = MaterialTheme.typography.titleSmall)
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(
                    selected = rows == 2,
                    onClick = { rows = 2 },
                    label = { Text("${spec.panelCount / 2}×2 · Two rows") },
                )
                FilterChip(
                    selected = rows == 1,
                    onClick = { rows = 1 },
                    label = { Text("${spec.panelCount}×1 · Single row") },
                )
            }
            HeightControl(
                title = "North (front) height",
                heightM = northM,
                onHeightMChange = { value ->
                    northM = SolarHeightLimits.clampNorthM(value, southM, spec.arrayL)
                },
            )
            HeightControl(
                title = "South (back) height",
                heightM = southM,
                onHeightMChange = { value ->
                    southM = SolarHeightLimits.clampSouthM(value, northM, spec.arrayL)
                },
            )
            Text(
                "Tilt  ${formatTilt(spec.tiltDeg)}",
                style = MaterialTheme.typography.titleMedium,
            )
            Text(
                "Range 1–13 ft. Tilt is set by the north/south height difference.",
                style = MaterialTheme.typography.bodySmall,
            )
            Text(
                "Total  ${SolarInsights.formatTotalKw(spec)}  ·  ${SolarInsights.formatPanelMix(spec)}\n" +
                    "Panels ${spec.panelCount}  ·  Grid ${spec.cols}×${spec.rows}\n" +
                    "Setup  ${SolarInsights.formatSetup(layout, spec.useMeters)}\n" +
                    "Includes ${SolarArrayDims.SetupBufferFt.toInt()} ft buffer for poles and racking.",
                style = MaterialTheme.typography.bodyMedium,
            )
            OverlayToggle(
                title = "Show dimensions",
                subtitle = "Numeric size marks on the setup footprint.",
                checked = showDimensions,
                onCheckedChange = { showDimensions = it },
            )
            OverlayToggle(
                title = "Show north/south",
                subtitle = "NORTH and SOUTH marks on the array.",
                checked = showNorthSouth,
                onCheckedChange = { showNorthSouth = it },
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Column(modifier = Modifier.weight(1f)) {
                    Text("Units", style = MaterialTheme.typography.titleSmall)
                    Text(
                        "Dimension labels and setup readout.",
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("ft", style = MaterialTheme.typography.bodyMedium)
                    Switch(
                        checked = useMeters,
                        onCheckedChange = { useMeters = it },
                    )
                    Text("m", style = MaterialTheme.typography.bodyMedium)
                }
            }
            if (error != null) {
                Text(error!!, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
            }
            if (debugUrl != null) {
                Text("Public GLB URL (debug)", style = MaterialTheme.typography.titleSmall)
                SelectionContainer {
                    Text(debugUrl!!, style = MaterialTheme.typography.bodySmall)
                }
                if (debugHead != null) {
                    Text(
                        debugHead!!,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                TextButton(
                    onClick = {
                        val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                        clipboard.setPrimaryClip(ClipData.newPlainText("GLB URL", debugUrl))
                        copied = true
                    },
                ) {
                    Text(if (copied) "Copied URL" else "Copy URL")
                }
            }
            Button(
                modifier = Modifier.fillMaxWidth(),
                enabled = !busy,
                onClick = {
                    error = null
                    debugUrl = null
                    debugHead = null
                    copied = false
                    busy = true
                    scope.launch {
                        try {
                            val bytes = withContext(Dispatchers.Default) {
                                SolarArrayGlbExporter.export(spec)
                            }
                            Log.i(ArModelUploader.TAG, "exported glbBytes=${bytes.size}")
                            val title = "${product.companyName} ${spec.panelWatts}W · ${SolarInsights.formatTotalKw(spec)} rooftop"
                            val fileUrl = withContext(Dispatchers.IO) {
                                ArModelUploader.upload(
                                    apiBaseUrl = apiBaseUrl,
                                    token = authToken,
                                    bytes = bytes,
                                    filename = "rooftop-array.glb",
                                )
                            }
                            val probe = withContext(Dispatchers.IO) {
                                ArModelUploader.probePublicUrl(fileUrl)
                            }
                            debugUrl = fileUrl
                            debugHead = probe.summary
                            if (!probe.okToOpen) {
                                throw IllegalStateException(
                                    probe.blockReason ?: "Public GLB URL is not usable by Scene Viewer.",
                                )
                            }
                            onOpenGoogle(fileUrl, title)
                        } catch (e: Exception) {
                            Log.e(ArModelUploader.TAG, "View in Google AR failed: ${e.message}", e)
                            error = e.message ?: "Could not open Google AR."
                        } finally {
                            busy = false
                        }
                    }
                },
            ) {
                if (busy) {
                    CircularProgressIndicator(
                        modifier = Modifier.width(18.dp),
                        strokeWidth = 2.dp,
                        color = MaterialTheme.colorScheme.onPrimary,
                    )
                } else {
                    Icon(Icons.Filled.ViewInAr, contentDescription = null)
                }
                Text(
                    if (busy) "Preparing AR…" else "View in Google AR",
                    modifier = Modifier.padding(start = 8.dp),
                )
            }
        }
    }
}

@Composable
private fun OverlayToggle(
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f).padding(end = 12.dp)) {
            Text(title, style = MaterialTheme.typography.titleSmall)
            Text(subtitle, style = MaterialTheme.typography.bodySmall)
        }
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
        )
    }
}

@Composable
private fun HeightControl(
    title: String,
    heightM: Float,
    onHeightMChange: (Float) -> Unit,
) {
    val focusManager = LocalFocusManager.current
    val feet = SolarHeightLimits.metersToFeet(heightM)
    var text by remember { mutableStateOf(formatFeetInput(feet)) }
    var focused by remember { mutableStateOf(false) }

    LaunchedEffect(heightM) {
        if (!focused) {
            text = formatFeetInput(SolarHeightLimits.metersToFeet(heightM))
        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(title, style = MaterialTheme.typography.titleSmall)
            OutlinedTextField(
                modifier = Modifier
                    .width(108.dp)
                    .onFocusChanged { state ->
                        val nowFocused = state.isFocused
                        if (focused && !nowFocused) {
                            text = formatFeetInput(SolarHeightLimits.metersToFeet(heightM))
                        }
                        focused = nowFocused
                    },
                value = text,
                onValueChange = { raw ->
                    if (raw.length > 5) {
                        return@OutlinedTextField
                    }
                    if (raw.isEmpty() || raw.matches(Regex("""\d*\.?\d*"""))) {
                        text = raw
                        raw.toFloatOrNull()?.let { typedFt ->
                            onHeightMChange(SolarHeightLimits.feetToMeters(typedFt))
                        }
                    }
                },
                suffix = { Text("ft") },
                singleLine = true,
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Decimal,
                    imeAction = ImeAction.Done,
                ),
                keyboardActions = KeyboardActions(
                    onDone = { focusManager.clearFocus() },
                ),
            )
        }
        Slider(
            value = feet.coerceIn(SolarHeightLimits.MinFt, SolarHeightLimits.MaxFt),
            onValueChange = { valueFt ->
                text = formatFeetInput(valueFt)
                onHeightMChange(SolarHeightLimits.feetToMeters(valueFt))
            },
            valueRange = SolarHeightLimits.MinFt..SolarHeightLimits.MaxFt,
        )
    }
}

private fun formatFeetInput(feet: Float): String = "%.1f".format(feet)

private fun formatTilt(tiltDeg: Float): String {
    val mag = abs(tiltDeg)
    return when {
        mag < 0.5f -> "0° · level"
        tiltDeg > 0f -> "${"%.0f".format(mag)}° toward north"
        else -> "${"%.0f".format(mag)}° toward south"
    }
}

@Composable
private fun SpecReadout(
    modifier: Modifier = Modifier,
    spec: SolarArraySpec,
    layout: SolarArrayLayout,
) {
    Column(
        modifier = modifier
            .background(Color(0xCC000000), RoundedCornerShape(10.dp))
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Text(
            SolarInsights.formatCompanyWatts(spec),
            color = Color.White,
            style = MaterialTheme.typography.bodyMedium,
        )
        Text(
            "Total  ${SolarInsights.formatTotalKw(spec)}  ·  ${SolarInsights.formatPanelMix(spec)}",
            color = Color.White,
            style = MaterialTheme.typography.bodyMedium,
        )
        Text(
            "Setup  ${SolarInsights.formatSetup(layout, spec.useMeters)}",
            color = Color.White,
            style = MaterialTheme.typography.bodyMedium,
        )
        Text(
            "North  ${SolarInsights.formatAxisMagnitude(spec.northHeightM, spec.useMeters)}",
            color = Color.White,
            style = MaterialTheme.typography.bodyMedium,
        )
        Text(
            "South  ${SolarInsights.formatAxisMagnitude(spec.southHeightM, spec.useMeters)}",
            color = Color.White,
            style = MaterialTheme.typography.bodyMedium,
        )
        Text(
            "Tilt  ${formatTilt(spec.tiltDeg)}",
            color = Color.White,
            style = MaterialTheme.typography.bodyMedium,
        )
    }
}
