import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:solar_sales/core/network/api_constants.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/shared/module/module_access.dart';

/// Full rooftop designer — the same web SolarDesigner (`/solar/designs/:id`)
/// loaded edge-to-edge so layout matches the CRM (no second Flutter app bar).
class SolarDesignerScreen extends ConsumerStatefulWidget {
  const SolarDesignerScreen({
    super.key,
    required this.designId,
    this.title = '3D Solar Design',
  });

  final String designId;
  final String title;

  @override
  ConsumerState<SolarDesignerScreen> createState() =>
      _SolarDesignerScreenState();
}

class _SolarDesignerScreenState extends ConsumerState<SolarDesignerScreen> {
  WebViewController? _controller;
  var _loading = true;
  var _mobileTweaksInjected = false;
  String? _error;
  String? _token;
  late final String _designerUrl;
  late final Uri _webOrigin;

  @override
  void initState() {
    super.initState();
    _designerUrl = ApiConstants.solarDesignerUrl(widget.designId);
    _webOrigin = Uri.parse(ApiConstants.webAppBaseUrl);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final token =
        (await ref.read(authRepositoryProvider).getStoredToken())?.trim();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Session expired. Sign in again to open the designer.';
      });
      return;
    }
    _token = token;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF5F5F5))
      ..enableZoom(true)
      ..addJavaScriptChannel(
        'Solar360Host',
        onMessageReceived: (message) {
          final raw = message.message.trim();
          if (raw == 'close' && mounted) {
            Navigator.of(context).maybePop();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            _mobileTweaksInjected = false;
            if (!mounted) return;
            setState(() {
              _loading = true;
              if (_isLoginUrl(url)) {
                _error = null;
              }
            });
          },
          onPageFinished: (url) async {
            await _ensureSession(url);
            await _injectMobileTweaks(url);
            if (!mounted) return;
            setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            // Tile / CDN failures must not blank the whole designer.
            if (error.isForMainFrame == false) return;
            setState(() {
              _loading = false;
              _error = error.description.isNotEmpty
                  ? error.description
                  : 'Could not load the 3D designer.';
            });
          },
          onNavigationRequest: _handleNavigation,
        ),
      );

    _controller = controller;
    if (mounted) setState(() {});
    await _loadBootstrapHtml(controller);
  }

  Future<void> _loadBootstrapHtml(WebViewController controller) async {
    final token = _token;
    if (token == null) return;
    final base = ApiConstants.webAppBaseUrl.replaceAll(RegExp(r'/+$'), '');
    final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no"/>
  <title>Opening designer</title>
  <style>
    body{font-family:system-ui,sans-serif;display:flex;align-items:center;justify-content:center;
      min-height:100vh;margin:0;background:#f5f7f6;color:#334155}
    p{font-size:15px}
  </style>
</head>
<body>
  <p>Opening 3D rooftop designer…</p>
  <script>
    (function () {
      try {
        localStorage.setItem('LMS_accessToken', ${jsonEncode(token)});
        localStorage.setItem(${jsonEncode(storageModuleKey)}, ${jsonEncode(AppModules.solar)});
      } catch (e) {}
      window.location.replace(${jsonEncode(_designerUrl)});
    })();
  </script>
</body>
</html>
''';
    await controller.loadHtmlString(html, baseUrl: '$base/');
  }

  Future<void> _ensureSession(String url) async {
    final token = _token;
    final controller = _controller;
    if (token == null || controller == null) return;

    await controller.runJavaScript('''
      (function () {
        try {
          localStorage.setItem('LMS_accessToken', ${jsonEncode(token)});
          localStorage.setItem(${jsonEncode(storageModuleKey)}, ${jsonEncode(AppModules.solar)});
        } catch (e) {}
      })();
    ''');

    if (_isLoginUrl(url)) {
      await controller.runJavaScript(
        'window.location.replace(${jsonEncode(_designerUrl)});',
      );
    }
  }

  /// Layout + search readability + Leaflet invalidateSize + web back → close.
  Future<void> _injectMobileTweaks(String url) async {
    final controller = _controller;
    if (controller == null || _mobileTweaksInjected) return;
    if (_isLoginUrl(url)) return;
    if (!url.contains('/solar/designs/')) return;

    _mobileTweaksInjected = true;
    await controller.runJavaScript('''
(function () {
  if (window.__solar360MobileTweaks) return;
  window.__solar360MobileTweaks = true;

  var style = document.createElement('style');
  style.setAttribute('data-solar360', 'mobile');
  style.textContent = [
    'html, body { background: #ffffff; height: 100%; overflow: hidden; }',
    /* Keep designer chrome stacked correctly on narrow phones. */
    '.fixed.inset-0 {',
    '  display: flex !important;',
    '  flex-direction: column !important;',
    '  overflow: hidden !important;',
    '}',
    'header {',
    '  position: relative !important;',
    '  z-index: 60 !important;',
    '  flex-shrink: 0 !important;',
    '  background: #ffffff !important;',
    '}',
    /* Map column must clip the absolute PlaceSearch so it cannot cover Report/Save. */
    'section.relative.isolate,',
    'section.relative {',
    '  position: relative !important;',
    '  z-index: 0 !important;',
    '  overflow: hidden !important;',
    '  min-height: 0 !important;',
    '  flex: 1 1 auto !important;',
    '}',
    '.leaflet-container {',
    '  width: 100% !important;',
    '  height: 100% !important;',
    '  z-index: 1 !important;',
    '  background: #e2e8f0 !important;',
    '}',
    /* Search sits inside the map pane only. */
    'section.relative [role="combobox"],',
    'section.relative .relative {',
    '  z-index: 1000 !important;',
    '}',
    'input, textarea, select {',
    '  color: #0f172a !important;',
    '  -webkit-text-fill-color: #0f172a !important;',
    '  caret-color: #ea580c !important;',
    '  opacity: 1 !important;',
    '}',
    'input::placeholder, textarea::placeholder {',
    '  color: #94a3b8 !important;',
    '  -webkit-text-fill-color: #94a3b8 !important;',
    '  opacity: 1 !important;',
    '}',
    'input:-webkit-autofill, input:-webkit-autofill:focus {',
    '  -webkit-text-fill-color: #0f172a !important;',
    '  transition: background-color 99999s ease-in-out 0s;',
    '}',
    '[role="combobox"] {',
    '  color: #0f172a !important;',
    '  -webkit-text-fill-color: #0f172a !important;',
    '  font-size: 16px !important;',
    '}',
    /* Suggestion list above map controls, still under header. */
    'section.relative .absolute.inset-x-0,',
    'section.relative ul[role="listbox"] {',
    '  z-index: 1100 !important;',
    '  max-height: min(40vh, 280px) !important;',
    '}',
    'aside { z-index: 20 !important; }'
  ].join('\\n');
  document.head.appendChild(style);

  function invalidateMapsHard() {
    try { window.dispatchEvent(new Event('resize')); } catch (e) {}
    try {
      document.querySelectorAll('.leaflet-container').forEach(function (c) {
        if (c._leaflet_map && c._leaflet_map.invalidateSize) {
          c._leaflet_map.invalidateSize(false);
        }
        /* Nudge layout so React-Leaflet ResizeObserver reflows tiles. */
        var h = c.style.height;
        c.style.height = (c.clientHeight + 1) + 'px';
        void c.offsetHeight;
        c.style.height = h || '';
      });
    } catch (e2) {}
  }

  var resizeTimer = null;
  function scheduleInvalidate() {
    if (resizeTimer) clearTimeout(resizeTimer);
    resizeTimer = setTimeout(invalidateMapsHard, 120);
  }

  if (window.visualViewport) {
    window.visualViewport.addEventListener('resize', scheduleInvalidate);
    window.visualViewport.addEventListener('scroll', scheduleInvalidate);
  }
  window.addEventListener('resize', scheduleInvalidate);
  document.addEventListener('focusin', function (ev) {
    var t = ev.target;
    if (!t || !t.closest) return;
    if (!t.closest('[role="combobox"], input, textarea')) return;
    /* Keep focus inside the map search — do not scroll the whole fixed shell
       (that was dragging the search over Report / Save). */
    setTimeout(function () {
      try {
        var pane = t.closest('section.relative');
        if (pane) pane.scrollTop = 0;
      } catch (e) {}
      scheduleInvalidate();
    }, 80);
  });
  document.addEventListener('focusout', function () {
    setTimeout(scheduleInvalidate, 160);
  });

  /* After place pick, React flyTo runs — refresh tiles once animation starts. */
  document.addEventListener('click', function (ev) {
    var t = ev.target;
    if (!t || !t.closest) return;
    if (t.closest('ul[role="listbox"] button, ul[role="listbox"] [role="option"]')) {
      setTimeout(invalidateMapsHard, 200);
      setTimeout(invalidateMapsHard, 900);
    }
  }, true);

  var moLayout = new MutationObserver(function () { scheduleInvalidate(); });
  moLayout.observe(document.documentElement, { childList: true, subtree: true });
  setTimeout(invalidateMapsHard, 300);
  setTimeout(invalidateMapsHard, 1000);
  setTimeout(invalidateMapsHard, 2000);

  function notifyClose() {
    try { Solar360Host.postMessage('close'); } catch (e) {}
  }

  function wireBackControls(root) {
    var scope = root || document;
    var anchors = scope.querySelectorAll('a[href]');
    for (var i = 0; i < anchors.length; i++) {
      var a = anchors[i];
      if (a.dataset.solar360Back) continue;
      var href = a.getAttribute('href') || '';
      var isLeadBack = /\\/solar\\/leads(\\/|\$)/.test(href) && href.indexOf('/solar/designs/') === -1;
      if (!isLeadBack) continue;
      a.dataset.solar360Back = '1';
      a.addEventListener('click', function (ev) {
        ev.preventDefault();
        ev.stopPropagation();
        notifyClose();
      }, true);
    }
  }

  wireBackControls(document);
  var mo = new MutationObserver(function (mutations) {
    for (var i = 0; i < mutations.length; i++) {
      var nodes = mutations[i].addedNodes;
      for (var j = 0; j < nodes.length; j++) {
        var n = nodes[j];
        if (n.nodeType === 1) wireBackControls(n);
      }
    }
  });
  mo.observe(document.documentElement, { childList: true, subtree: true });

  window.addEventListener('popstate', function () {
    if (!/\\/solar\\/designs\\//.test(location.pathname)) {
      notifyClose();
    }
  });
})();
''');
  }

  bool _isLoginUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final path = uri.path.replaceAll(RegExp(r'/+$'), '');
    return path.endsWith('/login') || path == '/login';
  }

  bool _isSameAppHost(Uri uri) {
    final host = uri.host.toLowerCase();
    final originHost = _webOrigin.host.toLowerCase();
    if (host.isEmpty || originHost.isEmpty) return false;
    return host == originHost;
  }

  bool _isExternalAppUrl(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'tel' ||
        scheme == 'mailto' ||
        scheme == 'whatsapp' ||
        scheme == 'intent') {
      return true;
    }
    if (scheme != 'http' && scheme != 'https') return false;
    final host = uri.host.toLowerCase();
    return host == 'wa.me' ||
        host.endsWith('.whatsapp.com') ||
        host == 'api.whatsapp.com';
  }

  NavigationDecision _handleNavigation(NavigationRequest request) {
    final url = request.url;
    final uri = Uri.tryParse(url);
    if (uri == null) return NavigationDecision.prevent;

    // CRITICAL: Esri / CDN tile + asset loads are not main-frame navigations.
    // Blocking them greys out the map ("Map data not yet available").
    if (!request.isMainFrame) {
      return NavigationDecision.navigate;
    }

    if (uri.scheme == 'about' || uri.scheme == 'data' || uri.scheme == 'blob') {
      return NavigationDecision.navigate;
    }

    if (_isExternalAppUrl(uri)) {
      _openExternal(uri);
      return NavigationDecision.prevent;
    }

    if (uri.scheme == 'http' || uri.scheme == 'https') {
      if (_isSameAppHost(uri)) {
        final path = uri.path;
        if (!path.contains('/solar/designs/') &&
            !path.contains('/login') &&
            path.isNotEmpty &&
            path != '/') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).maybePop();
          });
          return NavigationDecision.prevent;
        }
        return NavigationDecision.navigate;
      }
      // Other https main-frame (rare) — allow in WebView so map/CDN never breaks.
      return NavigationDecision.navigate;
    }

    return NavigationDecision.navigate;
  }

  Future<void> _openExternal(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _mobileTweaksInjected = false;
    });
    final controller = _controller;
    if (controller == null) {
      await _bootstrap();
      return;
    }
    await _loadBootstrapHtml(controller);
  }

  Future<void> _onClose() async {
    if (mounted) await Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: PopScope(
        canPop: true,
        child: Scaffold(
          resizeToAvoidBottomInset: true,
          backgroundColor: Colors.white,
          body: SafeArea(
            bottom: false,
            child: Stack(
              children: [
                if (_error != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.view_in_ar_outlined, size: 40),
                          const SizedBox(height: 12),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _reload,
                            child: const Text('Retry'),
                          ),
                          TextButton(
                            onPressed: _onClose,
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (controller != null)
                  Positioned.fill(
                    child: WebViewWidget(controller: controller),
                  )
                else
                  const SizedBox.expand(),
                if (_loading)
                  const Positioned(
                    left: 0,
                    right: 0,
                    top: 0,
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
