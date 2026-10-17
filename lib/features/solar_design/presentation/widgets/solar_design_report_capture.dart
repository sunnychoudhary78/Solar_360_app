import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:solar_sales/core/network/api_constants.dart';
import 'package:solar_sales/shared/module/module_access.dart';

/// Captures a JPEG data-URL of the designer's 3D canvas (same as web Report).
///
/// Rejects mostly-black frames (common on mobile when WebGL has not painted yet)
/// so the caller can fall back to a plan snapshot instead of a black PDF image.
Future<String?> captureSolarDesignSnapshot(
  BuildContext context, {
  required String designId,
  required String token,
}) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _SolarDesignReportCaptureDialog(
      designId: designId,
      token: token,
    ),
  );
}

/// True when a JPEG/PNG data-URL is empty or almost entirely black.
Future<bool> isMostlyBlackDataUrl(String? dataUrl) async {
  if (dataUrl == null || dataUrl.isEmpty) return true;
  final match =
      RegExp(r'^data:image/[\w+.-]+;base64,(.+)$').firstMatch(dataUrl.trim());
  if (match == null) return true;
  try {
    final bytes = base64Decode(match.group(1)!);
    if (bytes.length < 400) return true;
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: 48,
      targetHeight: 48,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final bd = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    if (bd == null) return true;
    final px = bd.buffer.asUint8List();
    var dark = 0;
    var samples = 0;
    for (var i = 0; i + 3 < px.length; i += 16) {
      samples++;
      if (px[i] < 32 && px[i + 1] < 32 && px[i + 2] < 32) dark++;
    }
    if (samples == 0) return true;
    return dark / samples > 0.82;
  } catch (_) {
    return true;
  }
}

class _SolarDesignReportCaptureDialog extends StatefulWidget {
  const _SolarDesignReportCaptureDialog({
    required this.designId,
    required this.token,
  });

  final String designId;
  final String token;

  @override
  State<_SolarDesignReportCaptureDialog> createState() =>
      _SolarDesignReportCaptureDialogState();
}

class _SolarDesignReportCaptureDialogState
    extends State<_SolarDesignReportCaptureDialog> {
  WebViewController? _controller;
  var _status = 'Opening designer…';
  var _finished = false;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    _timeout = Timer(const Duration(seconds: 40), () {
      _finish(null);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  Future<void> _finish(String? snapshot) async {
    if (_finished || !mounted) return;
    _finished = true;
    _timeout?.cancel();
    final trimmed = snapshot?.trim() ?? '';
    final ok = trimmed.startsWith('data:image/') &&
        trimmed.length > 800 &&
        !(await isMostlyBlackDataUrl(trimmed));
    if (!mounted) return;
    Navigator.of(context).pop(ok ? trimmed : null);
  }

  Future<void> _bootstrap() async {
    final designerUrl = ApiConstants.solarDesignerUrl(widget.designId);
    final base = ApiConstants.webAppBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final token = widget.token;

    late final WebViewController controller;
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFCFE3EF))
      ..enableZoom(false)
      ..addJavaScriptChannel(
        'Solar360Capture',
        onMessageReceived: (message) {
          _finish(message.message);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) async {
            if (_finished) return;
            if (!url.contains('/solar/designs/')) return;
            if (!mounted) return;
            setState(() => _status = 'Loading 3D view…');
            await _runCaptureScript(controller);
          },
        ),
      );

    _controller = controller;
    if (mounted) setState(() {});

    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1"/>
</head>
<body style="margin:0;background:#cfe3ef;font-family:system-ui,sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;color:#334155">
  <p>Preparing 3D snapshot…</p>
  <script>
    (function () {
      try {
        localStorage.setItem('LMS_accessToken', ${jsonEncode(token)});
        localStorage.setItem(${jsonEncode(storageModuleKey)}, ${jsonEncode(AppModules.solar)});
      } catch (e) {}
      window.location.replace(${jsonEncode(designerUrl)});
    })();
  </script>
</body>
</html>
''';
    await controller.loadHtmlString(html, baseUrl: '$base/');
  }

  Future<void> _runCaptureScript(WebViewController controller) async {
    // Web Report: switch to 3D → wait until ground paints → gl.render → toDataURL.
    // Mobile often returns a black buffer if we capture too early; wait + sample.
    await controller.runJavaScript(r'''
(function () {
  if (window.__solar360Capturing) return;
  window.__solar360Capturing = true;

  function sleep(ms) { return new Promise(function (r) { setTimeout(r, ms); }); }

  function post(data) {
    try { Solar360Capture.postMessage(data || ''); } catch (e) {
      try { Solar360Capture.postMessage(''); } catch (e2) {}
    }
  }

  function clickLabel(want) {
    var buttons = document.querySelectorAll('button');
    for (var i = 0; i < buttons.length; i++) {
      var label = (buttons[i].textContent || '').replace(/\s+/g, ' ').trim();
      if (label === want) {
        try { buttons[i].click(); } catch (e) {}
        return true;
      }
    }
    return false;
  }

  function isMostlyBlackDataUrl(dataUrl) {
    return new Promise(function (resolve) {
      try {
        if (!dataUrl || dataUrl.length < 800) { resolve(true); return; }
        var img = new Image();
        img.onload = function () {
          try {
            var c = document.createElement('canvas');
            c.width = 48; c.height = 48;
            var ctx = c.getContext('2d');
            ctx.drawImage(img, 0, 0, 48, 48);
            var px = ctx.getImageData(0, 0, 48, 48).data;
            var dark = 0, n = 0;
            for (var i = 0; i < px.length; i += 16) {
              n++;
              if (px[i] < 32 && px[i + 1] < 32 && px[i + 2] < 32) dark++;
            }
            resolve(n > 0 && dark / n > 0.82);
          } catch (e) { resolve(true); }
        };
        img.onerror = function () { resolve(true); };
        img.src = dataUrl;
      } catch (e) { resolve(true); }
    });
  }

  /** Nudge R3F / Three to paint (web Capture calls gl.render before toDataURL). */
  function nudgePaint(canvas) {
    try { window.dispatchEvent(new Event('resize')); } catch (e) {}
    try {
      if (window.visualViewport) {
        window.visualViewport.dispatchEvent(new Event('resize'));
      }
    } catch (e) {}
    try {
      canvas.dispatchEvent(new Event('webglcontextrestored'));
    } catch (e) {}
    // Camera presets force a useFrame pass
    clickLabel('Top');
  }

  function grabFrame(canvas) {
    return new Promise(function (resolve) {
      requestAnimationFrame(function () {
        requestAnimationFrame(function () {
          try {
            resolve(canvas.toDataURL('image/jpeg', 0.88));
          } catch (e) {
            resolve('');
          }
        });
      });
    });
  }

  (async function () {
    try {
      for (var t = 0; t < 60; t++) {
        if (document.querySelector('button')) break;
        await sleep(250);
      }

      clickLabel('3D');
      await sleep(600);

      var canvas = null;
      for (var w = 0; w < 60; w++) {
        canvas = document.querySelector('canvas');
        if (canvas && canvas.width >= 64 && canvas.height >= 64) break;
        await sleep(250);
      }
      if (!canvas) { post(''); return; }

      // Wait until satellite ground / scene paints (web waits onGroundReady).
      var best = '';
      for (var attempt = 0; attempt < 24; attempt++) {
        if (attempt === 0) clickLabel('3D');
        if (attempt === 3) clickLabel('Top');
        if (attempt === 6) clickLabel('3D');
        if (attempt === 10) clickLabel('S');
        if (attempt === 14) clickLabel('3D');

        nudgePaint(canvas);
        await sleep(450 + attempt * 40);
        var data = await grabFrame(canvas);
        if (!data) continue;
        var black = await isMostlyBlackDataUrl(data);
        if (!black) {
          post(data);
          return;
        }
        best = data;
      }

      // Last resort: only send if somehow usable (Dart also rejects black).
      post('');
    } catch (err) {
      post('');
    }
  })();
})();
''');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // Large visible WebView so WebGL actually composites frames (small/hidden = black).
    final webW = size.width.clamp(360.0, 900.0);
    final webH = (size.height * 0.72).clamp(420.0, 780.0);
    final scheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: webW,
          height: webH,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_controller != null)
                WebViewWidget(controller: _controller!)
              else
                const ColoredBox(color: Color(0xFFCFE3EF)),
              Align(
                alignment: Alignment.topCenter,
                child: Material(
                  elevation: 4,
                  color: scheme.surface.withValues(alpha: 0.95),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _status,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  'Waiting for satellite & panels (same as web Report)…',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
