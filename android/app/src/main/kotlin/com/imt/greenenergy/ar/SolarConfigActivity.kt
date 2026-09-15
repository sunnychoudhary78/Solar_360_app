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
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.ViewInAr
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.Typography
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
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
            MaterialTheme(
                colorScheme = Solar360Theme.darkColorScheme(),
                typography = Typography(),
            ) {
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
    var showTech by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val scheme = MaterialTheme.colorScheme

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

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(scheme.surfaceContainerLowest)
            .statusBarsPadding()
            .navigationBarsPadding(),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onClose) {
                Icon(Icons.Filled.Close, contentDescription = "Close")
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    "Design rooftop",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                )
                Text(
                    product.companyName,
                    style = MaterialTheme.typography.bodySmall,
                    color = scheme.onSurfaceVariant,
                )
            }
        }
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .weight(0.58f)
                .padding(horizontal = 10.dp)
                .clip(RoundedCornerShape(20.dp))
                .background(Color(0xFF101820)),
        ) {
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
            Row(
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .padding(10.dp),
                horizontalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                OverlayPill("${spec.kw} kW")
                OverlayPill("${spec.panelCount} panels")
                OverlayPill(formatTilt(spec.tiltDeg))
            }
            SpecReadout(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .padding(10.dp),
                spec = spec,
                layout = layout,
            )
        }
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .weight(0.42f)
                .clip(RoundedCornerShape(topStart = 22.dp, topEnd = 22.dp))
                .background(scheme.surfaceContainer)
                .padding(horizontal = 16.dp, vertical = 12.dp),
        ) {
            Box(
                modifier = Modifier
                    .align(Alignment.CenterHorizontally)
                    .padding(bottom = 10.dp)
                    .size(width = 36.dp, height = 4.dp)
                    .clip(CircleShape)
                    .background(scheme.outlineVariant),
            )
            Column(
                modifier = Modifier
                    .weight(1f)
                    .verticalScroll(rememberScrollState()),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                ControlCard(title = "Panel power") {
                    Text(
                        "${spec.panelWatts} W  ·  ${SolarInsights.formatProductSize(product)}",
                        style = MaterialTheme.typography.bodyMedium,
                    )
                    BrandSlider(
                        value = panelWatts.toFloat(),
                        onValueChange = { value ->
                            panelWatts = product.clampWatts(value.toInt())
                        },
                        valueRange = product.minWatts.toFloat()..product.maxWatts.toFloat(),
                        steps = product.sliderSteps.coerceAtLeast(0),
                    )
                }
                ControlCard(title = "System size") {
                    SegmentRow(
                        labels = listOf("2 kW", "3 kW", "4 kW", "5 kW"),
                        selectedIndex = kw - 2,
                        onSelect = { kw = it + 2 },
                    )
                }
                ControlCard(title = "Alignment") {
                    SegmentRow(
                        labels = listOf(
                            "${spec.panelCount / 2}×2  Two rows",
                            "${spec.panelCount}×1  Single row",
                        ),
                        selectedIndex = if (rows == 2) 0 else 1,
                        onSelect = { rows = if (it == 0) 2 else 1 },
                    )
                }
                ControlCard(title = "Heights") {
                    HeightControl(
                        title = "North (front)",
                        heightM = northM,
                        onHeightMChange = { value ->
                            northM = SolarHeightLimits.clampNorthM(value, southM, spec.arrayL)
                        },
                    )
                    HeightControl(
                        title = "South (back)",
                        heightM = southM,
                        onHeightMChange = { value ->
                            southM = SolarHeightLimits.clampSouthM(value, northM, spec.arrayL)
                        },
                    )
                    Text(
                        "Tilt ${formatTilt(spec.tiltDeg)}. Range 1–13 ft.",
                        style = MaterialTheme.typography.bodySmall,
                        color = scheme.onSurfaceVariant,
                    )
                }
                ControlCard(title = "Display") {
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
                        Text("Units", style = MaterialTheme.typography.titleSmall)
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text("ft", style = MaterialTheme.typography.bodySmall)
                            Switch(
                                checked = useMeters,
                                onCheckedChange = { useMeters = it },
                                colors = SwitchDefaults.colors(
                                    checkedThumbColor = scheme.onPrimary,
                                    checkedTrackColor = scheme.primary,
                                ),
                            )
                            Text("m", style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
                if (debugUrl != null) {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(16.dp))
                            .background(scheme.surfaceContainerHigh)
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { showTech = !showTech }
                                .padding(horizontal = 14.dp, vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Text(
                                "Technical details",
                                modifier = Modifier.weight(1f),
                                style = MaterialTheme.typography.titleSmall,
                                color = scheme.onSurfaceVariant,
                            )
                            Icon(
                                if (showTech) Icons.Filled.ExpandLess else Icons.Filled.ExpandMore,
                                contentDescription = null,
                                tint = scheme.onSurfaceVariant,
                            )
                        }
                        AnimatedVisibility(visible = showTech) {
                            Column(
                                modifier = Modifier.padding(start = 14.dp, end = 14.dp, bottom = 12.dp),
                                verticalArrangement = Arrangement.spacedBy(6.dp),
                            ) {
                                SelectionContainer {
                                    Text(debugUrl!!, style = MaterialTheme.typography.bodySmall)
                                }
                                if (debugHead != null) {
                                    Text(
                                        debugHead!!,
                                        style = MaterialTheme.typography.bodySmall,
                                        color = scheme.onSurfaceVariant,
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
                        }
                    }
                }
            }
            if (error != null) {
                Text(
                    error!!,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp)
                        .clip(RoundedCornerShape(12.dp))
                        .background(scheme.errorContainer)
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                    color = scheme.onErrorContainer,
                    style = MaterialTheme.typography.bodySmall,
                )
            }
            Button(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(top = 10.dp)
                    .height(52.dp),
                enabled = !busy,
                shape = RoundedCornerShape(16.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = scheme.primary,
                    contentColor = scheme.onPrimary,
                ),
                onClick = {
                    error = null
                    debugUrl = null
                    debugHead = null
                    copied = false
                    showTech = false
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
                                showTech = true
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
                        color = scheme.onPrimary,
                    )
                } else {
                    Icon(Icons.Filled.ViewInAr, contentDescription = null)
                }
                Text(
                    if (busy) "Preparing AR…" else "View in Google AR",
                    modifier = Modifier.padding(start = 8.dp),
                    fontWeight = FontWeight.Bold,
                )
            }
        }
    }
}

@Composable
private fun ControlCard(
    title: String,
    content: @Composable ColumnScope.() -> Unit,
) {
    val scheme = MaterialTheme.colorScheme
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(scheme.surfaceContainerHigh)
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
        content = {
            Text(
                title,
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
                color = scheme.primary,
            )
            content()
        },
    )
}

@Composable
private fun SegmentRow(
    labels: List<String>,
    selectedIndex: Int,
    onSelect: (Int) -> Unit,
) {
    val scheme = MaterialTheme.colorScheme
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        labels.forEachIndexed { index, label ->
            val selected = index == selectedIndex
            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(12.dp))
                    .background(if (selected) scheme.primary else scheme.surfaceContainerLowest)
                    .clickable { onSelect(index) }
                    .padding(vertical = 10.dp, horizontal = 8.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    label,
                    color = if (selected) scheme.onPrimary else scheme.onSurface,
                    style = MaterialTheme.typography.labelLarge,
                    fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium,
                )
            }
        }
    }
}

@Composable
private fun BrandSlider(
    value: Float,
    onValueChange: (Float) -> Unit,
    valueRange: ClosedFloatingPointRange<Float>,
    steps: Int = 0,
) {
    val scheme = MaterialTheme.colorScheme
    Slider(
        value = value,
        onValueChange = onValueChange,
        valueRange = valueRange,
        steps = steps,
        colors = SliderDefaults.colors(
            thumbColor = scheme.primary,
            activeTrackColor = scheme.primary,
            inactiveTrackColor = scheme.outlineVariant,
        ),
    )
}

@Composable
private fun OverlayPill(text: String) {
    Text(
        text,
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(Color(0xCC0F766E))
            .padding(horizontal = 10.dp, vertical = 5.dp),
        color = Color.White,
        style = MaterialTheme.typography.labelMedium,
        fontWeight = FontWeight.SemiBold,
    )
}

@Composable
private fun OverlayToggle(
    title: String,
    subtitle: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    val scheme = MaterialTheme.colorScheme
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(modifier = Modifier.weight(1f).padding(end = 12.dp)) {
            Text(title, style = MaterialTheme.typography.titleSmall)
            Text(
                subtitle,
                style = MaterialTheme.typography.bodySmall,
                color = scheme.onSurfaceVariant,
            )
        }
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = scheme.onPrimary,
                checkedTrackColor = scheme.primary,
            ),
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
    val scheme = MaterialTheme.colorScheme
    val feet = SolarHeightLimits.metersToFeet(heightM)
    var text by remember { mutableStateOf(formatFeetInput(feet)) }
    var focused by remember { mutableStateOf(false) }

    LaunchedEffect(heightM) {
        if (!focused) {
            text = formatFeetInput(SolarHeightLimits.metersToFeet(heightM))
        }
    }

    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(title, style = MaterialTheme.typography.titleSmall)
            OutlinedTextField(
                modifier = Modifier
                    .width(96.dp)
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
                textStyle = MaterialTheme.typography.bodyMedium,
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = scheme.primary,
                    cursorColor = scheme.primary,
                ),
                keyboardOptions = KeyboardOptions(
                    keyboardType = KeyboardType.Decimal,
                    imeAction = ImeAction.Done,
                ),
                keyboardActions = KeyboardActions(
                    onDone = { focusManager.clearFocus() },
                ),
            )
        }
        BrandSlider(
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
        tiltDeg > 0f -> "${"%.0f".format(mag)}° N"
        else -> "${"%.0f".format(mag)}° S"
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
            .clip(RoundedCornerShape(16.dp))
            .background(Color(0xCC0F766E))
            .border(1.dp, Color(0x66CCFBF1), RoundedCornerShape(16.dp))
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(2.dp),
    ) {
        Text(
            SolarInsights.formatCompanyWatts(spec),
            color = Color.White,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.Bold,
        )
        Text(
            "Total  ${SolarInsights.formatTotalKw(spec)}  ·  ${SolarInsights.formatPanelMix(spec)}",
            color = Color(0xFFE6FFFA),
            style = MaterialTheme.typography.bodySmall,
        )
        Text(
            "Setup  ${SolarInsights.formatSetup(layout, spec.useMeters)}",
            color = Color(0xFFE6FFFA),
            style = MaterialTheme.typography.bodySmall,
        )
        Text(
            "N ${SolarInsights.formatAxisMagnitude(spec.northHeightM, spec.useMeters)}   ·   " +
                "S ${SolarInsights.formatAxisMagnitude(spec.southHeightM, spec.useMeters)}   ·   " +
                formatTilt(spec.tiltDeg),
            color = Color(0xFFE6FFFA),
            style = MaterialTheme.typography.bodySmall,
        )
    }
}
