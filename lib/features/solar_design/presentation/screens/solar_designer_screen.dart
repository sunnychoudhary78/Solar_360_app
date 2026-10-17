import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:solar_sales/core/network/api_constants.dart';
import 'package:solar_sales/features/auth/presentation/providers/auth_provider.dart';
import 'package:solar_sales/features/solar_design/presentation/screens/solar_design_preview_screen.dart';
import 'package:solar_sales/shared/module/module_access.dart';
import 'package:solar_sales/shared/utils/app_snackbar.dart';
import 'package:solar_sales/shared/utils/pdf_helper.dart';

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
  var _openingPreview = false;
  var _savingPdf = false;
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
          final msg = message.message.trim();
          if (!mounted) return;
          if (msg == 'close') {
            Navigator.of(context).maybePop();
            return;
          }
          // Share dialog "Open preview" (target=_blank /p/<code>)
          if (msg.startsWith('preview:')) {
            final url = msg.substring('preview:'.length).trim();
            if (url.isNotEmpty) _openPublicPreview(url);
            return;
          }
          // Designer "Report" button → blob PDF (WebView can't open blob: URLs)
          if (msg == 'pdf-status:saving') {
            showAppSnackBar(context, 'Saving PDF report…');
            return;
          }
          if (msg == 'pdf-status:error') {
            showAppSnackBar(
              context,
              'Could not save the PDF report',
              isError: true,
            );
            return;
          }
          if (msg.startsWith('pdf:')) {
            _savePdfFromWebDesigner(msg.substring(4));
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
    // Prefer viewPadding: on edge-to-edge Android, MediaQuery.padding.top can be 0
    // while the status bar still overlays content (company name under the clock).
    final mq = mounted ? MediaQuery.of(context) : null;
    final viewPad = mq?.viewPadding;
    final topInset = (viewPad?.top ?? mq?.padding.top ?? 0)
        .clamp(0, 64)
        .toStringAsFixed(0);
    final bottomInset = (viewPad?.bottom ?? mq?.padding.bottom ?? 0)
        .clamp(0, 48)
        .toStringAsFixed(0);
    final shortestSide = mq?.size.shortestSide ?? 390;

    await controller.runJavaScript('''
(function () {
  if (window.__solar360Host) return;
  window.__solar360Host = true;

  /**
   * Web Report uses downloadBlob → createObjectURL + <a download>.click().
   * Android WebView navigates to blob: and shows ERR_FILE_NOT_FOUND.
   * Intercept blob PDF downloads and send bytes to Flutter (PdfHelper).
   */
  (function installBlobPdfBridge() {
    if (window.__solar360PdfBridge) return;
    window.__solar360PdfBridge = true;

    function handPdfToApp(blobUrl, filename) {
      try { Solar360Host.postMessage('pdf-status:saving'); } catch (e) {}
      fetch(blobUrl).then(function (res) { return res.blob(); }).then(function (blob) {
        var reader = new FileReader();
        reader.onloadend = function () {
          var dataUrl = reader.result || '';
          var name = filename || 'Solar-Design-report.pdf';
          try {
            Solar360Host.postMessage('pdf:' + name + '\\n' + dataUrl);
          } catch (err) {
            try { Solar360Host.postMessage('pdf-status:error'); } catch (e2) {}
          }
        };
        reader.onerror = function () {
          try { Solar360Host.postMessage('pdf-status:error'); } catch (e) {}
        };
        reader.readAsDataURL(blob);
      }).catch(function () {
        try { Solar360Host.postMessage('pdf-status:error'); } catch (e) {}
      });
    }

    var origClick = HTMLAnchorElement.prototype.click;
    HTMLAnchorElement.prototype.click = function () {
      var href = '';
      try { href = this.href || this.getAttribute('href') || ''; } catch (e) {}
      var dl = this.getAttribute('download');
      if (dl != null && href.indexOf('blob:') === 0) {
        handPdfToApp(href, dl || 'Solar-Design-report.pdf');
        return;
      }
      return origClick.apply(this, arguments);
    };

    document.addEventListener('click', function (ev) {
      var a = ev.target && ev.target.closest ? ev.target.closest('a[download]') : null;
      if (!a) return;
      var href = '';
      try { href = a.href || ''; } catch (e) {}
      if (href.indexOf('blob:') !== 0) return;
      ev.preventDefault();
      ev.stopPropagation();
      handPdfToApp(href, a.getAttribute('download') || 'Solar-Design-report.pdf');
    }, true);
  })();

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
    ':root { --solar360-top-inset: ${topInset}px; --solar360-bottom-inset: ${bottomInset}px; --solar360-shortest: ${shortestSide.toStringAsFixed(0)}px; }',
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

    /* Header stays above map; wraps instead of overflowing.
       Status-bar clearance is applied by Flutter (viewPadding), not here —
       padding again would double-space the company name. */
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
    '}',

    /* —— Map / 3D full-screen toggle (additive only) ——
       Sit top-right under Leaflet zoom/Labels so it never covers the centered
       web "Draw the roof" CTA (absolute bottom-3 left-1/2). */
    '.solar360-fs-btn {',
    '  position: absolute !important;',
    '  top: 108px !important;',
    '  right: 10px !important;',
    '  bottom: auto !important;',
    '  left: auto !important;',
    '  z-index: 1100 !important;',
    '  display: inline-flex !important;',
    '  align-items: center !important;',
    '  justify-content: center !important;',
    '  gap: 6px !important;',
    '  max-width: min(168px, calc(100% - 20px)) !important;',
    '  padding: 8px 10px !important;',
    '  border: none !important;',
    '  border-radius: 10px !important;',
    '  background: #0f172a !important;',
    '  color: #fff !important;',
    '  font: 600 11px/1.2 system-ui, -apple-system, sans-serif !important;',
    '  letter-spacing: 0.01em !important;',
    '  box-shadow: 0 4px 14px rgba(15, 23, 42, 0.35) !important;',
    '  pointer-events: auto !important;',
    '  -webkit-tap-highlight-color: transparent !important;',
    '  cursor: pointer !important;',
    '  white-space: nowrap !important;',
    '}',
    '.solar360-fs-btn svg {',
    '  width: 14px !important;',
    '  height: 14px !important;',
    '  flex-shrink: 0 !important;',
    '}',
    '.solar360-fs-btn[aria-pressed="true"] {',
    '  background: #ea580c !important;',
    '}',
    '@media (max-width: 380px) {',
    '  .solar360-fs-btn {',
    '    top: 100px !important;',
    '    padding: 8px !important;',
    '    max-width: 40px !important;',
    '  }',
    '  .solar360-fs-btn span { display: none !important; }',
    '}',
    /* Keep centered Draw-the-roof CTA from stretching under right-side controls */
    'section.relative .absolute[class*="bottom-3"][class*="left-1/2"] {',
    '  max-width: min(340px, calc(100% - 5rem)) !important;',
    '  z-index: 1000 !important;',
    '}',
    'html.solar360-map-fs .fixed.inset-0.z-40.flex.flex-col > header {',
    '  display: none !important;',
    '}',
    'html.solar360-map-fs aside[class*="max-h-"] {',
    '  display: none !important;',
    '}',
    'html.solar360-map-fs .fixed.inset-0.z-40.flex.flex-col > .flex.min-h-0.flex-1 {',
    '  overflow: visible !important;',
    '}',
    'html.solar360-map-fs section.relative.isolate,',
    'html.solar360-map-fs section.relative {',
    '  position: fixed !important;',
    '  top: 0 !important;',
    '  right: 0 !important;',
    '  bottom: 0 !important;',
    '  left: 0 !important;',
    '  width: 100% !important;',
    '  height: 100% !important;',
    '  max-height: none !important;',
    '  min-height: 0 !important;',
    '  flex: none !important;',
    '  z-index: 2000 !important;',
    '  overflow: hidden !important;',
    '}',
    'html.solar360-map-fs .solar360-fs-btn {',
    '  top: max(12px, calc(var(--solar360-top-inset, 0px) + 10px)) !important;',
    '  right: 10px !important;',
    '  bottom: auto !important;',
    '}'
  ].join('\\n');
  document.head.appendChild(style);

  /* Nudge Leaflet / 3D after layout settles. Avoid React-mutation loops. */
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

  var FS_EXPAND_ICON = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M8 3H5a2 2 0 0 0-2 2v3"/><path d="M21 8V5a2 2 0 0 0-2-2h-3"/><path d="M3 16v3a2 2 0 0 0 2 2h3"/><path d="M16 21h3a2 2 0 0 0 2-2v-3"/></svg>';
  var FS_COLLAPSE_ICON = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M8 3v3a2 2 0 0 1-2 2H3"/><path d="M21 8h-3a2 2 0 0 1-2-2V3"/><path d="M3 16h3a2 2 0 0 1 2 2v3"/><path d="M16 21v-3a2 2 0 0 1 2-2h3"/></svg>';

  function isMapFullscreen() {
    return document.documentElement.classList.contains('solar360-map-fs');
  }

  function setMapFullscreen(on) {
    document.documentElement.classList.toggle('solar360-map-fs', !!on);
    var buttons = document.querySelectorAll('[data-solar360="fs-btn"]');
    for (var i = 0; i < buttons.length; i++) {
      var btn = buttons[i];
      btn.setAttribute('aria-pressed', on ? 'true' : 'false');
      btn.setAttribute('aria-label', on ? 'Exit full screen' : 'View full screen');
      btn.innerHTML = (on ? FS_COLLAPSE_ICON + '<span>Exit Full Screen</span>'
        : FS_EXPAND_ICON + '<span>View Full Screen</span>');
    }
    setTimeout(bumpResize, 50);
    setTimeout(bumpResize, 300);
  }

  function findMapSection(root) {
    var scope = root && root.querySelectorAll ? root : document;
    return scope.querySelector('section.relative.isolate')
      || scope.querySelector('.fixed.inset-0.z-40 section.relative')
      || document.querySelector('section.relative.isolate')
      || document.querySelector('.fixed.inset-0.z-40 section.relative');
  }

  function ensureFullscreenButton(root) {
    var section = findMapSection(root);
    if (!section) return;
    if (section.querySelector('[data-solar360="fs-btn"]')) return;

    var btn = document.createElement('button');
    btn.type = 'button';
    btn.setAttribute('data-solar360', 'fs-btn');
    btn.className = 'solar360-fs-btn';
    btn.setAttribute('aria-pressed', isMapFullscreen() ? 'true' : 'false');
    btn.setAttribute('aria-label', isMapFullscreen() ? 'Exit full screen' : 'View full screen');
    btn.innerHTML = isMapFullscreen()
      ? FS_COLLAPSE_ICON + '<span>Exit Full Screen</span>'
      : FS_EXPAND_ICON + '<span>View Full Screen</span>';
    btn.addEventListener('click', function (ev) {
      ev.preventDefault();
      ev.stopPropagation();
      setMapFullscreen(!isMapFullscreen());
    }, true);
    section.appendChild(btn);
  }

  function notifyClose() {
    try { Solar360Host.postMessage('close'); } catch (e) {}
  }

  /** Share dialog "Open preview" uses target=_blank — WebView often drops that.
   *  Capture /p/<code> clicks and hand them to Flutter's preview screen. */
  function wirePreviewLinks(root) {
    var scope = root && root.querySelectorAll ? root : document;
    var anchors = scope.querySelectorAll
      ? scope.querySelectorAll('a[href]')
      : [];
    for (var i = 0; i < anchors.length; i++) {
      var a = anchors[i];
      if (a.dataset.solar360Preview) continue;
      var href = a.getAttribute('href') || '';
      var abs = '';
      try { abs = a.href || href; } catch (e) { abs = href; }
      if (!/\\/p\\/[A-Za-z0-9_-]{6,}/.test(abs) && !/\\/p\\/[A-Za-z0-9_-]{6,}/.test(href)) {
        continue;
      }
      a.dataset.solar360Preview = '1';
      a.addEventListener('click', function (ev) {
        ev.preventDefault();
        ev.stopPropagation();
        var link = '';
        try { link = this.href || this.getAttribute('href') || ''; } catch (err) {}
        if (!link) return;
        try { Solar360Host.postMessage('preview:' + link); } catch (err2) {}
      }, true);
    }
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

  /**
   * Panels must stay a uniform solar-blue in the app. The web "Sun access" heat map
   * paints each panel red→yellow→green from analysis; after analysis the designer
   * also auto-enables that toggle. Turn it off (and keep it off) so every panel
   * uses the same material colour. Heat map remains available on the web designer.
   */
  function ensureUniformPanelColors() {
    try {
      var buttons = document.querySelectorAll('button');
      for (var i = 0; i < buttons.length; i++) {
        var b = buttons[i];
        var text = (b.textContent || '').replace(/\\s+/g, ' ');
        if (text.indexOf('Sun access') === -1) continue;
        b.setAttribute('data-solar360-hide-heat', '1');
        b.style.setProperty('display', 'none', 'important');
        var on = /bg-teal-600/.test(b.className || '');
        if (on && !b.disabled) {
          try { b.click(); } catch (err) {}
        }
      }
      var nodes = document.querySelectorAll('div');
      for (var j = 0; j < nodes.length; j++) {
        var el = nodes[j];
        if (el.getAttribute('data-solar360-heat-legend') === '1') continue;
        var t = (el.textContent || '').replace(/\\s+/g, ' ').trim();
        if (t.indexOf('Sun access') !== 0) continue;
        if (!el.querySelector('[style*="linear-gradient"]')) continue;
        el.setAttribute('data-solar360-heat-legend', '1');
        el.style.setProperty('display', 'none', 'important');
      }
    } catch (e) {}
  }

  function onDomAdded(root) {
    wireBack(root);
    wirePreviewLinks(root);
    ensureFullscreenButton(root);
    ensureUniformPanelColors();
  }

  onDomAdded(document);
  // Analysis finishes async and flips heat map on — poll lightly to keep panels uniform.
  setInterval(ensureUniformPanelColors, 1200);
  var mo = new MutationObserver(function (mutations) {
    for (var i = 0; i < mutations.length; i++) {
      var nodes = mutations[i].addedNodes;
      for (var j = 0; j < nodes.length; j++) {
        if (nodes[j].nodeType === 1) onDomAdded(nodes[j]);
      }
    }
  });
  mo.observe(document.documentElement, { childList: true, subtree: true });

  window.addEventListener('popstate', function () {
    if (!/\\/solar\\/designs\\//.test(location.pathname)) notifyClose();
  });

  document.addEventListener('keydown', function (ev) {
    if (ev.key === 'Escape' && isMapFullscreen()) {
      setMapFullscreen(false);
    }
  }, true);
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

  /// Public customer preview path: `/p/<share_code>` (optional trailing slash).
  bool _isPublicPreviewPath(String path) {
    final normalized = path.replaceAll(RegExp(r'/+$'), '');
    return RegExp(r'^/p/[A-Za-z0-9_-]{6,}$').hasMatch(normalized);
  }

  NavigationDecision _handleNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;

    // Esri tiles / assets — never block.
    if (!request.isMainFrame) return NavigationDecision.navigate;

    if (uri.scheme == 'about' || uri.scheme == 'data') {
      return NavigationDecision.navigate;
    }
    // Report download uses blob: URLs — navigating there shows ERR_FILE_NOT_FOUND.
    // PDF bytes are handed to Flutter via Solar360Host (see installBlobPdfBridge).
    if (uri.scheme == 'blob') {
      return NavigationDecision.prevent;
    }

    if (_isExternalAppUrl(uri)) {
      _openExternal(uri);
      return NavigationDecision.prevent;
    }

    if (uri.scheme == 'http' || uri.scheme == 'https') {
      if (_isSameAppHost(uri)) {
        final path = uri.path;
        // Share → "Open preview" must open the in-app 3D preview, not leave.
        if (_isPublicPreviewPath(path)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _openPublicPreview(request.url);
          });
          return NavigationDecision.prevent;
        }
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

  /// Web Report calls `downloadBlob` → `<a download href="blob:…">`. Bridge that
  /// into [PdfHelper] so the full report opens like on desktop Chrome.
  Future<void> _savePdfFromWebDesigner(String payload) async {
    if (_savingPdf || !mounted) return;
    final nl = payload.indexOf('\n');
    if (nl <= 0 || nl >= payload.length - 1) {
      showAppSnackBar(context, 'Could not save the PDF report', isError: true);
      return;
    }
    final rawName = payload.substring(0, nl).trim();
    final dataUrl = payload.substring(nl + 1).trim();
    final match =
        RegExp(r'^data:([^;]+);base64,(.+)$', dotAll: true).firstMatch(dataUrl);
    if (match == null) {
      showAppSnackBar(context, 'Could not save the PDF report', isError: true);
      return;
    }
    _savingPdf = true;
    try {
      final bytes = base64Decode(match.group(2)!);
      final safe = rawName
          .replaceAll(RegExp(r'[^\w.-]+'), '-')
          .replaceAll(RegExp(r'^-+|-+$'), '');
      final filename =
          '${safe.isEmpty ? 'Solar-Design-report' : safe}${safe.toLowerCase().endsWith('.pdf') ? '' : '.pdf'}';
      await PdfHelper.saveAndOpen(
        Uint8List.fromList(bytes),
        filename: filename,
      );
      if (mounted) {
        showAppSnackBar(context, 'PDF report downloaded');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          'Could not save the PDF report',
          isError: true,
        );
      }
    } finally {
      _savingPdf = false;
    }
  }

  Future<void> _openPublicPreview(String url) async {
    if (!mounted || _openingPreview) return;
    var resolved = url.trim();
    if (resolved.isEmpty) return;
    // Relative /p/… from the WebView
    if (resolved.startsWith('/')) {
      final base = ApiConstants.webAppBaseUrl.replaceAll(RegExp(r'/+$'), '');
      resolved = '$base$resolved';
    }
    final uri = Uri.tryParse(resolved);
    if (uri == null || !_isPublicPreviewPath(uri.path)) return;

    _openingPreview = true;
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SolarDesignPreviewScreen(
            url: resolved,
            title: '3D preview',
          ),
        ),
      );
    } finally {
      _openingPreview = false;
    }
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
    // Use viewPadding: with edge-to-edge, padding.top is often 0 while the
    // status bar still covers the WebView (company name under the clock).
    // Bottom inset stays in injected CSS so the tools panel can scroll fully.
    final safePadding = EdgeInsets.only(
      top: media.viewPadding.top,
      left: media.viewPadding.left,
      right: media.viewPadding.right,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
        systemStatusBarContrastEnforced: true,
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
