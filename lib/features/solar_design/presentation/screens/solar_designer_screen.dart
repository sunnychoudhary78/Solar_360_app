import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:solar_sales/core/network/api_constants.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/shared/module/module_access.dart';

/// Hosts the CRM SolarDesigner (`/solar/designs/:id`) for full web parity:
/// draw roof → auto-fill panels → tools → save → reload.
///
/// Important: do **not** poke the Leaflet DOM on every React re-render.
/// That was clearing roofs/panels when switching tools.
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
  var _hostScriptInjected = false;
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
      // Leaflet must own pinch-zoom; WebView zoom steals gestures and breaks the map.
      ..enableZoom(false)
      ..addJavaScriptChannel(
        'Solar360Host',
        onMessageReceived: (message) {
          if (message.message.trim() == 'close' && mounted) {
            Navigator.of(context).maybePop();
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            _hostScriptInjected = false;
            if (!mounted) return;
            setState(() {
              _loading = true;
              if (_isLoginUrl(url)) _error = null;
            });
          },
          onPageFinished: (url) async {
            await _ensureSession(url);
            await _injectHostScript(url);
            if (!mounted) return;
            setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (!mounted) return;
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
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover"/>
  <title>Opening designer</title>
  <style>
    body{font-family:system-ui,sans-serif;display:flex;align-items:center;justify-content:center;
      min-height:100vh;margin:0;background:#f5f7f6;color:#334155}
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

  /// Minimal host glue only. Must not mutate Leaflet layers / remount the map
  /// when the user switches tools (that wiped roofs & auto-filled panels).
  Future<void> _injectHostScript(String url) async {
    final controller = _controller;
    if (controller == null || _hostScriptInjected) return;
    if (_isLoginUrl(url)) return;
    if (!url.contains('/solar/designs/')) return;

    _hostScriptInjected = true;
    // WebView often reports 0 for env(safe-area-inset-*); pass Flutter insets.
    final mq = mounted ? MediaQuery.of(context) : null;
    final bottomInset = (mq?.padding.bottom ?? 0).clamp(0, 48).toStringAsFixed(0);
    final shortestSide = mq?.size.shortestSide ?? 390;

    await controller.runJavaScript('''
(function () {
  if (window.__solar360Host) return;
  window.__solar360Host = true;

  try {
    var meta = document.querySelector('meta[name="viewport"]');
    if (!meta) {
      meta = document.createElement('meta');
      meta.setAttribute('name', 'viewport');
      document.head.appendChild(meta);
    }
    meta.setAttribute(
      'content',
      'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover'
    );
  } catch (e) {}

  var style = document.createElement('style');
  style.setAttribute('data-solar360', 'host');
  style.textContent = [
    ':root { --solar360-bottom-inset: ${bottomInset}px; --solar360-shortest: ${shortestSide.toStringAsFixed(0)}px; }',
    /* —— Base: readable controls + no accidental page scroll —— */
    'html, body {',
    '  height: 100% !important;',
    '  max-height: 100% !important;',
    '  overflow: hidden !important;',
    '  overscroll-behavior: none !important;',
    '  -webkit-text-size-adjust: 100% !important;',
    '  text-size-adjust: 100% !important;',
    '}',
    'input, textarea, select {',
    '  color: #0f172a !important;',
    '  -webkit-text-fill-color: #0f172a !important;',
    '  caret-color: #ea580c !important;',
    '  font-size: 16px !important;',
    '  line-height: 1.25 !important;',
    '}',
    'input::placeholder, textarea::placeholder {',
    '  color: #94a3b8 !important;',
    '  -webkit-text-fill-color: #94a3b8 !important;',
    '}',
    '[role="combobox"] {',
    '  color: #0f172a !important;',
    '  -webkit-text-fill-color: #0f172a !important;',
    '  font-size: 16px !important;',
    '}',

    /* —— Designer shell fills the WebView on every phone height —— */
    'body > #root, body > #root > * {',
    '  min-height: 0 !important;',
    '}',
    '.fixed.inset-0.z-40.flex.flex-col {',
    '  top: 0 !important;',
    '  right: 0 !important;',
    '  bottom: 0 !important;',
    '  left: 0 !important;',
    '  width: 100% !important;',
    '  height: 100% !important;',
    '  max-height: 100% !important;',
    '  overflow: hidden !important;',
    '}',
    '.fixed.inset-0.z-40.flex.flex-col > .flex.min-h-0.flex-1 {',
    '  min-height: 0 !important;',
    '  flex: 1 1 0 !important;',
    '  overflow: hidden !important;',
    '}',

    /* Header stays above map; wraps instead of overflowing */
    'header {',
    '  position: relative !important;',
    '  z-index: 50 !important;',
    '  background: #fff !important;',
    '  flex-shrink: 0 !important;',
    '  max-width: 100% !important;',
    '}',
    'header .truncate {',
    '  max-width: 100% !important;',
    '  overflow: hidden !important;',
    '  text-overflow: ellipsis !important;',
    '  white-space: nowrap !important;',
    '}',
    'header .ml-auto {',
    '  max-width: 100% !important;',
    '}',

    /* Map pane: MUST shrink on short phones (web min-h-320 caused top clip) */
    'section.relative.isolate,',
    'section.relative {',
    '  position: relative !important;',
    '  flex: 1 1 0 !important;',
    '  min-height: 0 !important;',
    '  max-height: 100% !important;',
    '  overflow: hidden !important;',
    '  z-index: 1 !important;',
    '}',

    /* Keep search + sun toggles fully inside the map (not cut at top) */
    'section.relative > .absolute.left-3.top-3,',
    'section.relative > .absolute[class*="top-3"] {',
    '  top: 10px !important;',
    '  left: 10px !important;',
    '  right: auto !important;',
    '  max-width: calc(100% - 3.25rem) !important;',
    '  box-sizing: border-box !important;',
    '  pointer-events: auto !important;',
    '}',
    /* PlaceSearch (has input) stays above sun-toggle chips */
    'section.relative > .absolute[class*="top-3"]:has(input) {',
    '  z-index: 1000 !important;',
    '  width: min(400px, calc(100% - 3.25rem)) !important;',
    '}',
    'section.relative > .absolute[class*="top-3"]:not(:has(input)) {',
    '  z-index: 20 !important;',
    '}',
    'section.relative .absolute .flex.h-10.items-center,',
    'section.relative .relative > .flex.h-10.items-center {',
    '  height: auto !important;',
    '  min-height: 2.75rem !important;',
    '  max-height: none !important;',
    '  padding-top: 0.4rem !important;',
    '  padding-bottom: 0.4rem !important;',
    '  box-sizing: border-box !important;',
    '  overflow: visible !important;',
    '}',
    'section.relative .relative > .flex.h-10.items-center input {',
    '  height: auto !important;',
    '  min-height: 1.5rem !important;',
    '  font-size: 16px !important;',
    '  line-height: 1.3 !important;',
    '}',
    'section.relative ul[role="listbox"],',
    'section.relative .absolute.inset-x-0.top-full {',
    '  max-height: min(36vh, 260px) !important;',
    '  overflow-y: auto !important;',
    '  -webkit-overflow-scrolling: touch !important;',
    '  z-index: 1001 !important;',
    '}',

    /* Sun-path / panel-info chips wrap cleanly; stay fully visible */
    'section.relative > .absolute[class*="top-3"][class*="flex"] {',
    '  row-gap: 6px !important;',
    '  column-gap: 6px !important;',
    '  align-content: flex-start !important;',
    '}',
    'section.relative > .absolute[class*="top-3"] button {',
    '  max-width: 100% !important;',
    '  white-space: nowrap !important;',
    '}',

    /* Bottom tools / system-size panel: scroll + home-indicator padding */
    'aside[class*="max-h-"] {',
    '  max-height: min(42vh, 420px) !important;',
    '  min-height: 0 !important;',
    '  overflow-x: hidden !important;',
    '  overflow-y: auto !important;',
    '  -webkit-overflow-scrolling: touch !important;',
    '  overscroll-behavior: contain !important;',
    '  padding-bottom: max(12px, var(--solar360-bottom-inset, 0px)) !important;',
    '  box-sizing: border-box !important;',
    '}',

    /* Short phones: give map more room; keep search/overlays on-screen */
    '@media (max-height: 780px) {',
    '  header { padding-top: 0.35rem !important; padding-bottom: 0.35rem !important; }',
    '  aside[class*="max-h-"] { max-height: min(38vh, 340px) !important; }',
    '}',
    '@media (max-height: 680px) {',
    '  aside[class*="max-h-"] { max-height: min(34vh, 280px) !important; }',
    '  section.relative > .absolute.left-3.top-3,',
    '  section.relative > .absolute[class*="top-3"] {',
    '    top: 8px !important;',
    '    left: 8px !important;',
    '    max-width: calc(100% - 2.75rem) !important;',
    '  }',
    '}',
    '@media (max-width: 380px) {',
    '  header { padding-left: 0.5rem !important; padding-right: 0.5rem !important; gap: 0.35rem !important; }',
    '  section.relative > .absolute.left-3.top-3,',
    '  section.relative > .absolute[class*="top-3"] {',
    '    max-width: calc(100% - 2.5rem) !important;',
    '  }',
    '}'
  ].join('\\n');
  document.head.appendChild(style);

  /* Nudge Leaflet after layout settles. Avoid React-mutation loops. */
  function bumpResize() {
    try { window.dispatchEvent(new Event('resize')); } catch (e) {}
    try {
      if (window.visualViewport) {
        window.visualViewport.dispatchEvent(new Event('resize'));
      }
    } catch (e) {}
  }
  setTimeout(bumpResize, 400);
  setTimeout(bumpResize, 1200);

  function notifyClose() {
    try { Solar360Host.postMessage('close'); } catch (e) {}
  }

  function wireBack(root) {
    var scope = root || document;
    var anchors = scope.querySelectorAll('a[href]');
    for (var i = 0; i < anchors.length; i++) {
      var a = anchors[i];
      if (a.dataset.solar360Back) continue;
      var href = a.getAttribute('href') || '';
      var isLeadBack = /\\/solar\\/leads(\\/|\$)/.test(href)
        && href.indexOf('/solar/designs/') === -1;
      if (!isLeadBack) continue;
      a.dataset.solar360Back = '1';
      a.addEventListener('click', function (ev) {
        ev.preventDefault();
        ev.stopPropagation();
        notifyClose();
      }, true);
    }
  }

  wireBack(document);
  var mo = new MutationObserver(function (mutations) {
    for (var i = 0; i < mutations.length; i++) {
      var nodes = mutations[i].addedNodes;
      for (var j = 0; j < nodes.length; j++) {
        if (nodes[j].nodeType === 1) wireBack(nodes[j]);
      }
    }
  });
  mo.observe(document.documentElement, { childList: true, subtree: true });

  window.addEventListener('popstate', function () {
    if (!/\\/solar\\/designs\\//.test(location.pathname)) notifyClose();
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
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;

    // Esri tiles / assets — never block.
    if (!request.isMainFrame) return NavigationDecision.navigate;

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
        // Leaving the designer via full navigation → close Flutter screen.
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
      _hostScriptInjected = false;
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

    final media = MediaQuery.of(context);
    // Top/side system insets only. Bottom (home indicator) is handled in injected
    // CSS so the tools panel can scroll fully on short phones.
    final safePadding = EdgeInsets.only(
      top: media.padding.top,
      left: media.padding.left,
      right: media.padding.right,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: Colors.white,
        body: Padding(
          padding: safePadding,
          child: Stack(
            fit: StackFit.expand,
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
                WebViewWidget(controller: controller)
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
    );
  }
}
