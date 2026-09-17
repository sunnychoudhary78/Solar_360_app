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
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.offset
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
import androidx.compose.material.icons.filled.ErrorOutline
import androidx.compose.material.icons.filled.ExpandLess
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.Explore
import androidx.compose.material.icons.filled.SolarPower
import androidx.compose.material.icons.filled.Straighten
import androidx.compose.material.icons.filled.ViewInAr
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.onSizeChanged
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.IntSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.github.sceneview.RenderQuality
import io.github.sceneview.SceneView
import io.github.sceneview.math.Position
import io.github.sceneview.node.Node
import io.github.sceneview.rememberCameraManipulator
import io.github.sceneview.rememberCameraNode
import io.github.sceneview.rememberEngine
import io.github.sceneview.rememberMaterialLoader
import io.github.sceneview.rememberModelLoader
import io.github.sceneview.rememberView
import kotlin.math.abs
import kotlin.math.atan
import kotlin.math.max
import kotlin.math.roundToInt
import kotlin.math.sqrt
import kotlin.math.tan
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
                typography = Solar360Theme.typography(),
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
    var chromeReady by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    LaunchedEffect(Unit) { chromeReady = true }

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
    val filamentView = rememberView(engine)
    val cameraNode = rememberCameraNode(engine)
    var previewPanePx by remember { mutableStateOf(IntSize.Zero) }
    val orbitFrame = remember(
        kw,
        rows,
        product.id,
        product.widthM,
        product.lengthM,
        previewPanePx.width,
        previewPanePx.height,
    ) {
        previewOrbitFrame(layout, previewPanePx.width, previewPanePx.height)
    }
    val cameraManipulator = key(
        kw,
        rows,
        product.id,
        previewPanePx.width,
        previewPanePx.height,
    ) {
        rememberCameraManipulator(
            orbitHomePosition = orbitFrame.home,
            targetPosition = orbitFrame.target,
        )
    }
    LaunchedEffect(orbitFrame) {
        cameraNode.position = orbitFrame.home
        cameraNode.lookAt(orbitFrame.target)
    }
    var widthChipPx by remember { mutableStateOf<Offset?>(null) }
    var lengthChipPx by remember { mutableStateOf<Offset?>(null) }
    val widthLabelWorld = remember(layout) { layout.widthLabelWorld() }
    val lengthLabelWorld = remember(layout) { layout.lengthLabelWorld() }

    val chromeAlpha by animateFloatAsState(
        targetValue = if (chromeReady) 1f else 0f,
        animationSpec = tween(280),
        label = "chromeAlpha",
    )

    val openGoogleAr: () -> Unit = {
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
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Solar360Theme.Window)
            .onSizeChanged { previewPanePx = it },
    ) {
        SceneView(
            modifier = Modifier.fillMaxSize(),
            engine = engine,
            view = filamentView,
            cameraNode = cameraNode,
            modelLoader = modelLoader,
            materialLoader = materialLoader,
            autoCenterContent = false,
            renderQuality = RenderQuality.Performance,
            cameraManipulator = cameraManipulator,
            onFrame = {
                val vp = filamentView.viewport
                val cam = filamentView.camera ?: cameraNode.camera
                widthChipPx = projectWorldToScreen(cam, vp.width, vp.height, widthLabelWorld)
                lengthChipPx = projectWorldToScreen(cam, vp.width, vp.height, lengthLabelWorld)
            },
        ) {
            Node {
                AssembledArray(
                    spec = spec,
                    modelLoader = modelLoader,
                    materialLoader = materialLoader,
                )
            }
        }
        if (showDimensions) {
            AnchoredDimensionChip(
                text = SolarInsights.formatWidth(layout, spec.useMeters),
                screen = widthChipPx,
            )
            AnchoredDimensionChip(
                text = SolarInsights.formatLength(layout, spec.useMeters),
                screen = lengthChipPx,
            )
        }
        Box(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .fillMaxWidth()
                .height(168.dp)
                .background(
                    Brush.verticalGradient(
                        colors = listOf(Solar360Theme.Vignette.copy(alpha = 0.78f), Color.Transparent),
                    ),
                ),
        )
        Box(
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .fillMaxWidth()
                .height(280.dp)
                .background(
                    Brush.verticalGradient(
                        colors = listOf(Color.Transparent, Solar360Theme.Vignette.copy(alpha = 0.88f)),
                    ),
                ),
        )
        Column(
            modifier = Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding()
                .padding(horizontal = 12.dp)
                .padding(bottom = 10.dp),
        ) {
            DesignerHeader(
                companyName = product.companyName,
                wattsLabel = "${spec.panelWatts} W",
                onClose = onClose,
                modifier = Modifier.graphicsLayer {
                    alpha = chromeAlpha
                    translationY = (1f - chromeAlpha) * -18f
                },
            )
            Row(
                modifier = Modifier
                    .padding(top = 10.dp)
                    .graphicsLayer {
                        alpha = chromeAlpha
                        translationY = (1f - chromeAlpha) * -12f
                    },
                horizontalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                OverlayPill("${spec.kw} kW")
                OverlayPill("${spec.panelCount} panels")
                OverlayPill(formatTilt(spec.tiltDeg))
            }
            Box(modifier = Modifier.weight(0.62f).fillMaxWidth()) {
                SpecReadout(
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .fillMaxWidth()
                        .padding(vertical = 8.dp)
                        .graphicsLayer { alpha = chromeAlpha },
                    spec = spec,
                    layout = layout,
                )
            }
            Box(
                modifier = Modifier
                    .weight(0.38f)
                    .fillMaxWidth()
                    .graphicsLayer {
                        alpha = chromeAlpha
                        translationY = (1f - chromeAlpha) * 28f
                    },
            ) {
                ControlSheet(
                    product = product,
                    spec = spec,
                    kw = kw,
                    rows = rows,
                    northM = northM,
                    southM = southM,
                    panelWatts = panelWatts,
                    showDimensions = showDimensions,
                    showNorthSouth = showNorthSouth,
                    busy = busy,
                    error = error,
                    debugUrl = debugUrl,
                    debugHead = debugHead,
                    copied = copied,
                    showTech = showTech,
                    onKw = { kw = it },
                    onRows = { rows = it },
                    onNorthM = { northM = it },
                    onSouthM = { southM = it },
                    onPanelWatts = { panelWatts = it },
                    onShowDimensions = { showDimensions = it },
                    onShowNorthSouth = { showNorthSouth = it },
                    onShowTech = { showTech = it },
                    onCopied = { copied = it },
                    onOpenGoogleAr = openGoogleAr,
                    clipboardContext = context,
                )
            }
        }
    }
}

@Composable
private fun DesignerHeader(
    companyName: String,
    wattsLabel: String,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val scheme = MaterialTheme.colorScheme
    Row(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 2.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(Solar360Theme.GlassFill)
                .border(1.dp, Solar360Theme.GlassBorderSoft, CircleShape)
                .clickable(onClick = onClose),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.Filled.Close,
                contentDescription = "Close",
                tint = scheme.onSurface,
                modifier = Modifier.size(18.dp),
            )
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                "Design rooftop",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.ExtraBold,
                letterSpacing = (-0.3).sp,
                color = scheme.onSurface,
            )
            Text(
                companyName,
                style = MaterialTheme.typography.bodySmall,
                color = scheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
        StatusChip(
            icon = Icons.Filled.SolarPower,
            label = wattsLabel,
        )
    }
}

@Composable
private fun StatusChip(
    icon: ImageVector,
    label: String,
) {
    val scheme = MaterialTheme.colorScheme
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(50.dp))
            .background(scheme.primary.copy(alpha = 0.12f))
            .border(1.dp, scheme.primary.copy(alpha = 0.28f), RoundedCornerShape(50.dp))
            .padding(horizontal = 10.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(5.dp),
    ) {
        Icon(icon, contentDescription = null, tint = scheme.primary, modifier = Modifier.size(13.dp))
        Text(
            label,
            color = scheme.primary,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.ExtraBold,
        )
    }
}

@Composable
private fun ControlSheet(
    product: SolarPanelProduct,
    spec: SolarArraySpec,
    kw: Int,
    rows: Int,
    northM: Float,
    southM: Float,
    panelWatts: Int,
    showDimensions: Boolean,
    showNorthSouth: Boolean,
    busy: Boolean,
    error: String?,
    debugUrl: String?,
    debugHead: String?,
    copied: Boolean,
    showTech: Boolean,
    onKw: (Int) -> Unit,
    onRows: (Int) -> Unit,
    onNorthM: (Float) -> Unit,
    onSouthM: (Float) -> Unit,
    onPanelWatts: (Int) -> Unit,
    onShowDimensions: (Boolean) -> Unit,
    onShowNorthSouth: (Boolean) -> Unit,
    onShowTech: (Boolean) -> Unit,
    onCopied: (Boolean) -> Unit,
    onOpenGoogleAr: () -> Unit,
    clipboardContext: Context,
) {
    val scheme = MaterialTheme.colorScheme
    val sheetShape = RoundedCornerShape(28.dp)
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(top = 4.dp)
            .shadow(18.dp, sheetShape, ambientColor = Solar360Theme.Glow, spotColor = Color.Black)
            .clip(sheetShape)
            .background(Solar360Theme.SheetGradient)
            .border(1.dp, Solar360Theme.GlassBorderSoft, sheetShape)
            .padding(horizontal = 16.dp, vertical = 10.dp),
    ) {
        Box(
            modifier = Modifier
                .align(Alignment.CenterHorizontally)
                .padding(bottom = 10.dp)
                .size(width = 40.dp, height = 4.dp)
                .clip(CircleShape)
                .background(scheme.outline.copy(alpha = 0.55f)),
        )
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(bottom = 10.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            DisplayChip(
                icon = Icons.Filled.Straighten,
                label = "Dimensions",
                selected = showDimensions,
                onClick = { onShowDimensions(!showDimensions) },
                modifier = Modifier.weight(1f),
            )
            DisplayChip(
                icon = Icons.Filled.Explore,
                label = "N / S",
                selected = showNorthSouth,
                onClick = { onShowNorthSouth(!showNorthSouth) },
                modifier = Modifier.weight(1f),
            )
        }
        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            ControlCard(title = "Panel power") {
                Text(
                    "${spec.panelWatts} W  ·  ${SolarInsights.formatProductSize(product)}",
                    style = MaterialTheme.typography.bodyMedium,
                    color = scheme.onSurface,
                )
                BrandSlider(
                    value = panelWatts.toFloat(),
                    onValueChange = { value ->
                        onPanelWatts(product.clampWatts(value.toInt()))
                    },
                    valueRange = product.minWatts.toFloat()..product.maxWatts.toFloat(),
                    steps = product.sliderSteps.coerceAtLeast(0),
                )
            }
            ControlCard(title = "System size") {
                SegmentRow(
                    labels = listOf("2 kW", "3 kW", "4 kW", "5 kW"),
                    selectedIndex = kw - 2,
                    onSelect = { onKw(it + 2) },
                )
            }
            ControlCard(title = "Alignment") {
                SegmentRow(
                    labels = listOf(
                        "${spec.panelCount / 2}×2  Two rows",
                        "${spec.panelCount}×1  Single row",
                    ),
                    selectedIndex = if (rows == 2) 0 else 1,
                    onSelect = { onRows(if (it == 0) 2 else 1) },
                )
            }
            ControlCard(title = "Heights") {
                HeightControl(
                    title = "South (front)",
                    heightM = northM,
                    onHeightMChange = { value ->
                        onNorthM(SolarHeightLimits.clampNorthM(value, southM, spec.arrayL))
                    },
                )
                HeightControl(
                    title = "North (back)",
                    heightM = southM,
                    onHeightMChange = { value ->
                        onSouthM(SolarHeightLimits.clampSouthM(value, northM, spec.arrayL))
                    },
                )
                Text(
                    "Tilt ${formatTilt(spec.tiltDeg)}. Range 1–13 ft.",
                    style = MaterialTheme.typography.bodySmall,
                    color = scheme.onSurface,
                )
            }
            if (debugUrl != null) {
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(20.dp))
                        .background(Solar360Theme.CardGradient)
                        .border(1.dp, Solar360Theme.GlassBorderSoft, RoundedCornerShape(20.dp)),
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onShowTech(!showTech) }
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
                                Text(debugUrl, style = MaterialTheme.typography.bodySmall)
                            }
                            if (debugHead != null) {
                                Text(
                                    debugHead,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = scheme.onSurfaceVariant,
                                )
                            }
                            TextButton(
                                onClick = {
                                    val clipboard = clipboardContext.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                                    clipboard.setPrimaryClip(ClipData.newPlainText("GLB URL", debugUrl))
                                    onCopied(true)
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
            ErrorBanner(message = error)
        }
        ArCtaButton(busy = busy, enabled = !busy, onClick = onOpenGoogleAr)
    }
}

@Composable
private fun DisplayChip(
    icon: ImageVector,
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val scheme = MaterialTheme.colorScheme
    val border by animateColorAsState(
        if (selected) scheme.primary.copy(alpha = 0.45f) else scheme.outlineVariant.copy(alpha = 0.5f),
        label = "displayBorder",
    )
    val fill by animateColorAsState(
        if (selected) scheme.primary.copy(alpha = 0.16f) else Solar360Theme.GlassFill,
        label = "displayFill",
    )
    val content by animateColorAsState(
        if (selected) scheme.primary else scheme.onSurfaceVariant,
        label = "displayContent",
    )
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(50.dp))
            .background(fill)
            .border(1.dp, border, RoundedCornerShape(50.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        Icon(icon, contentDescription = null, tint = content, modifier = Modifier.size(14.dp))
        Text(
            label,
            modifier = Modifier.padding(start = 6.dp),
            color = content,
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.Bold,
        )
    }
}

@Composable
private fun ControlCard(
    title: String,
    content: @Composable ColumnScope.() -> Unit,
) {
    val scheme = MaterialTheme.colorScheme
    val shape = RoundedCornerShape(20.dp)
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(10.dp, shape, ambientColor = Solar360Theme.Glow.copy(alpha = 0.18f), spotColor = Color.Black.copy(alpha = 0.35f))
            .clip(shape)
            .background(Solar360Theme.CardGradient)
            .border(1.dp, Solar360Theme.GlassBorderSoft, shape)
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp),
        content = {
            Text(
                title.uppercase(),
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
                letterSpacing = 1.2.sp,
                color = scheme.onSurfaceVariant,
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
    val trackShape = RoundedCornerShape(50.dp)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(trackShape)
            .background(scheme.surfaceContainerLowest)
            .border(1.dp, scheme.outlineVariant.copy(alpha = 0.45f), trackShape)
            .padding(4.dp),
        horizontalArrangement = Arrangement.spacedBy(4.dp),
    ) {
        labels.forEachIndexed { index, label ->
            val selected = index == selectedIndex
            val textColor by animateColorAsState(
                if (selected) scheme.onPrimary else scheme.onSurface,
                label = "segmentText$index",
            )
            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(50.dp))
                    .then(
                        if (selected) {
                            Modifier.background(Solar360Theme.BrandGradient)
                        } else {
                            Modifier
                        },
                    )
                    .clickable { onSelect(index) }
                    .padding(vertical = 9.dp, horizontal = 8.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    label,
                    color = textColor,
                    style = MaterialTheme.typography.labelMedium,
                    fontWeight = if (selected) FontWeight.ExtraBold else FontWeight.Medium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
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
            inactiveTrackColor = scheme.outlineVariant.copy(alpha = 0.7f),
            activeTickColor = scheme.onPrimary.copy(alpha = 0.4f),
            inactiveTickColor = scheme.outline,
        ),
    )
}

@Composable
private fun ArCtaButton(
    busy: Boolean,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    val scheme = MaterialTheme.colorScheme
    val shape = RoundedCornerShape(16.dp)
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 10.dp)
            .height(56.dp)
            .shadow(16.dp, shape, ambientColor = Solar360Theme.Glow, spotColor = Solar360Theme.BrandDeep.copy(alpha = 0.55f))
            .clip(shape)
            .background(Solar360Theme.BrandGradient)
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 18.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        Box(
            modifier = Modifier
                .size(28.dp)
                .clip(CircleShape)
                .background(scheme.onPrimary.copy(alpha = 0.18f)),
            contentAlignment = Alignment.Center,
        ) {
            if (busy) {
                CircularProgressIndicator(
                    modifier = Modifier.size(14.dp),
                    strokeWidth = 2.dp,
                    color = scheme.onPrimary,
                )
            } else {
                Icon(
                    Icons.Filled.ViewInAr,
                    contentDescription = null,
                    tint = scheme.onPrimary,
                    modifier = Modifier.size(16.dp),
                )
            }
        }
        Text(
            if (busy) "Preparing AR…" else "View in Google AR",
            modifier = Modifier.padding(start = 10.dp),
            color = scheme.onPrimary,
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.ExtraBold,
        )
    }
}

@Composable
private fun ErrorBanner(message: String) {
    val scheme = MaterialTheme.colorScheme
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 8.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(scheme.errorContainer)
            .border(1.dp, scheme.error.copy(alpha = 0.35f), RoundedCornerShape(14.dp))
            .padding(horizontal = 12.dp, vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Icon(
            Icons.Filled.ErrorOutline,
            contentDescription = null,
            tint = scheme.onErrorContainer,
            modifier = Modifier.size(18.dp),
        )
        Text(
            message,
            color = scheme.onErrorContainer,
            style = MaterialTheme.typography.bodySmall,
        )
    }
}

@Composable
private fun BoxScope.AnchoredDimensionChip(
    text: String,
    screen: Offset?,
) {
    if (screen == null) return
    var chipW by remember { mutableIntStateOf(0) }
    var chipH by remember { mutableIntStateOf(0) }
    DimensionChip(
        text = text,
        modifier = Modifier
            .align(Alignment.TopStart)
            .onSizeChanged { size ->
                chipW = size.width
                chipH = size.height
            }
            .offset {
                IntOffset(
                    screen.x.roundToInt() - chipW / 2,
                    screen.y.roundToInt() - chipH / 2,
                )
            },
    )
}

@Composable
private fun DimensionChip(
    text: String,
    modifier: Modifier = Modifier,
) {
    Text(
        text,
        modifier = modifier
            .clip(RoundedCornerShape(10.dp))
            .background(Color(0xE6FBBF24))
            .padding(horizontal = 14.dp, vertical = 6.dp),
        color = Color.Black,
        style = MaterialTheme.typography.titleSmall,
        fontWeight = FontWeight.Bold,
    )
}

private const val DimBarGap = 0.52f
private const val DimLabelLift = 0.42f
private const val DimLabelOutset = 0.55f
private const val PreviewVerticalFovDeg = 45f
private const val PreviewFillPadding = 0.06f
private const val PreviewChromeTopFraction = 0.12f
private const val PreviewChromeBottomFraction = 0.50f
private const val PreviewNsLabelOutset = 0.8f
private const val PreviewOrbitDirX = 0.55f
private const val PreviewOrbitDirY = 0.10f
private const val PreviewOrbitDirZ = 1f

private data class PreviewOrbitFrame(
    val home: Position,
    val target: Position,
)

private data class PreviewAabb(
    val minX: Float,
    val maxX: Float,
    val minY: Float,
    val maxY: Float,
    val minZ: Float,
    val maxZ: Float,
)

private fun previewAabb(layout: SolarArrayLayout): PreviewAabb {
    val dimPad = DimBarGap + DimLabelOutset
    val halfW = layout.footprintW / 2f + dimPad
    val halfL = layout.footprintL / 2f + max(dimPad, PreviewNsLabelOutset)
    val maxH = max(layout.spec.northHeightM, layout.spec.southHeightM) + 0.5f
    return PreviewAabb(
        minX = -halfW,
        maxX = halfW,
        minY = 0f,
        maxY = maxH,
        minZ = -halfL,
        maxZ = halfL,
    )
}

private fun previewOrbitFrame(
    layout: SolarArrayLayout,
    paneWidthPx: Int,
    paneHeightPx: Int,
): PreviewOrbitFrame {
    val aabb = previewAabb(layout)
    val target = Position(
        x = (aabb.minX + aabb.maxX) * 0.5f,
        y = layout.yLift * 0.45f,
        z = (aabb.minZ + aabb.maxZ) * 0.5f,
    )
    val aspect = if (paneWidthPx > 0 && paneHeightPx > 0) {
        paneWidthPx.toFloat() / paneHeightPx.toFloat()
    } else {
        1.15f
    }
    val verticalClear = (1f - PreviewChromeTopFraction - PreviewChromeBottomFraction)
        .coerceIn(0.4f, 1f)
    val halfVfov = Math.toRadians(PreviewVerticalFovDeg.toDouble()).toFloat() * 0.5f
    val halfHfov = atan(tan(halfVfov) * aspect)
    val tanH = tan(halfHfov).coerceAtLeast(0.08f)
    val tanV = (tan(halfVfov) * verticalClear).coerceAtLeast(0.08f)

    val dirLen = sqrt(
        PreviewOrbitDirX * PreviewOrbitDirX +
            PreviewOrbitDirY * PreviewOrbitDirY +
            PreviewOrbitDirZ * PreviewOrbitDirZ,
    )
    val dirX = PreviewOrbitDirX / dirLen
    val dirY = PreviewOrbitDirY / dirLen
    val dirZ = PreviewOrbitDirZ / dirLen

    var rightX = dirZ
    var rightY = 0f
    var rightZ = -dirX
    val rightLen = sqrt(rightX * rightX + rightY * rightY + rightZ * rightZ).coerceAtLeast(1e-5f)
    rightX /= rightLen
    rightY /= rightLen
    rightZ /= rightLen
    val upX = dirY * rightZ - dirZ * rightY
    val upY = dirZ * rightX - dirX * rightZ
    val upZ = dirX * rightY - dirY * rightX

    var distance = 0.8f
    val xs = floatArrayOf(aabb.minX, aabb.maxX)
    val ys = floatArrayOf(aabb.minY, aabb.maxY)
    val zs = floatArrayOf(aabb.minZ, aabb.maxZ)
    for (x in xs) {
        for (y in ys) {
            for (z in zs) {
                val ox = x - target.x
                val oy = y - target.y
                val oz = z - target.z
                val along = ox * dirX + oy * dirY + oz * dirZ
                val right = abs(ox * rightX + oy * rightY + oz * rightZ)
                val up = abs(ox * upX + oy * upY + oz * upZ)
                distance = max(distance, right / tanH + along)
                distance = max(distance, up / tanV + along)
            }
        }
    }
    distance /= (1f - PreviewFillPadding).coerceIn(0.5f, 0.95f)
    val tanFullV = tan(halfVfov)
    val visibleMid = 0.25f
    val ndcShift = (0.5f - visibleMid) * 2f
    val lookY = target.y - tanFullV * distance * ndcShift
    return PreviewOrbitFrame(
        home = Position(
            x = target.x + dirX * distance,
            y = target.y + dirY * distance,
            z = target.z + dirZ * distance,
        ),
        target = Position(x = target.x, y = lookY, z = target.z),
    )
}

private fun SolarArrayLayout.widthLabelWorld(): Position {
    return Position(0f, DimLabelLift, footprintL / 2f + DimBarGap + DimLabelOutset)
}

private fun SolarArrayLayout.lengthLabelWorld(): Position {
    return Position(footprintW / 2f + DimBarGap + DimLabelOutset, DimLabelLift, 0f)
}

private fun projectWorldToScreen(
    camera: com.google.android.filament.Camera,
    viewportWidth: Int,
    viewportHeight: Int,
    world: Position,
): Offset? {
    if (viewportWidth <= 0 || viewportHeight <= 0) return null
    val view = FloatArray(16)
    camera.getViewMatrix(view)
    val projD = DoubleArray(16)
    camera.getCullingProjectionMatrix(projD)
    val proj = FloatArray(16) { index -> projD[index].toFloat() }
    val world4 = floatArrayOf(world.x, world.y, world.z, 1f)
    val eye = FloatArray(4)
    val clip = FloatArray(4)
    android.opengl.Matrix.multiplyMV(eye, 0, view, 0, world4, 0)
    android.opengl.Matrix.multiplyMV(clip, 0, proj, 0, eye, 0)
    if (clip[3] <= 1e-5f) return null
    val ndcX = clip[0] / clip[3]
    val ndcY = clip[1] / clip[3]
    return Offset(
        (ndcX + 1f) * 0.5f * viewportWidth,
        (1f - ndcY) * 0.5f * viewportHeight,
    )
}

@Composable
private fun OverlayPill(text: String) {
    val scheme = MaterialTheme.colorScheme
    Text(
        text,
        modifier = Modifier
            .clip(RoundedCornerShape(20.dp))
            .background(Solar360Theme.PillFill)
            .border(1.dp, Solar360Theme.PillBorder, RoundedCornerShape(20.dp))
            .padding(horizontal = 11.dp, vertical = 6.dp),
        color = scheme.onPrimaryContainer,
        style = MaterialTheme.typography.labelMedium,
        fontWeight = FontWeight.SemiBold,
    )
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
            Text(
                title,
                style = MaterialTheme.typography.titleSmall,
                color = scheme.onSurface,
            )
            OutlinedTextField(
                modifier = Modifier
                    .width(92.dp)
                    .height(52.dp)
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
                suffix = { Text("ft", color = scheme.onSurfaceVariant, style = MaterialTheme.typography.labelSmall) },
                singleLine = true,
                textStyle = MaterialTheme.typography.bodySmall.copy(color = scheme.onSurface),
                shape = RoundedCornerShape(12.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = scheme.primary,
                    unfocusedBorderColor = Solar360Theme.GlassBorderSoft,
                    focusedContainerColor = Solar360Theme.GlassFill,
                    unfocusedContainerColor = Solar360Theme.GlassFill,
                    cursorColor = scheme.primary,
                    focusedTextColor = scheme.onSurface,
                    unfocusedTextColor = scheme.onSurface,
                    disabledTextColor = scheme.onSurfaceVariant,
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
        tiltDeg > 0f -> "${"%.0f".format(mag)}° S"
        else -> "${"%.0f".format(mag)}° N"
    }
}

@Composable
private fun SpecReadout(
    modifier: Modifier = Modifier,
    spec: SolarArraySpec,
    layout: SolarArrayLayout,
) {
    val scheme = MaterialTheme.colorScheme
    val shape = RoundedCornerShape(16.dp)
    Column(
        modifier = modifier
            .clip(shape)
            .background(Solar360Theme.GlassFillStrong)
            .border(1.dp, Solar360Theme.GlassBorder, shape)
            .padding(horizontal = 14.dp, vertical = 10.dp),
        verticalArrangement = Arrangement.spacedBy(3.dp),
    ) {
        Text(
            SolarInsights.formatCompanyWatts(spec),
            color = scheme.onSurface,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.Bold,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
        Text(
            "${SolarInsights.formatWidth(layout, spec.useMeters)}  ·  " +
                "${SolarInsights.formatLength(layout, spec.useMeters)}  ·  " +
                "S ${SolarInsights.formatAxisMagnitude(spec.northHeightM, spec.useMeters)}  ·  " +
                "N ${SolarInsights.formatAxisMagnitude(spec.southHeightM, spec.useMeters)}",
            color = scheme.onSurfaceVariant,
            style = MaterialTheme.typography.bodySmall,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}
