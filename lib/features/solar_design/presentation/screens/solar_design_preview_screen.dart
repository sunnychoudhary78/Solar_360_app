import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:solar_sales/core/network/api_constants.dart';
import 'package:solar_sales/shared/utils/app_snackbar.dart';
import 'package:solar_sales/shared/widgets/app_bar.dart';

/// Customer-facing 3D preview (`/p/<share_code>`) in a WebView for 100% web parity.
///
/// Talk to us (Call / WhatsApp / Email / Website) uses `tel:`, `mailto:`,
/// `wa.me`, and external http(s). Android WebView does not open those natively
/// (and `target=_blank` is often dropped), so we bridge them to the OS apps.
class SolarDesignPreviewScreen extends StatefulWidget {
  const SolarDesignPreviewScreen({
    super.key,
    required this.url,
    required this.title,
  });

  final String url;
  final String title;

  @override
  State<SolarDesignPreviewScreen> createState() =>
      _SolarDesignPreviewScreenState();
}

class _SolarDesignPreviewScreenState extends State<SolarDesignPreviewScreen> {
  late final WebViewController _controller;
  late final Uri _webOrigin;
  var _loading = true;
  var _hostScriptInjected = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _webOrigin = Uri.parse(ApiConstants.webAppBaseUrl);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF5F5F5))
      ..addJavaScriptChannel(
        'Solar360Preview',
        onMessageReceived: (message) {
          final raw = message.message.trim();
          if (raw.isEmpty || !mounted) return;
          final uri = Uri.tryParse(raw);
          if (uri == null) return;
          _openExternal(uri);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            _hostScriptInjected = false;
            if (!mounted) return;
            setState(() {
              _loading = true;
              _error = null;
            });
          },
          onPageFinished: (url) async {
            await _injectTalkToUsBridge();
            if (!mounted) return;
            setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            setState(() {
              _loading = false;
              _error = error.description.isNotEmpty
                  ? error.description
                  : 'Could not load the 3D preview.';
            });
          },
          onNavigationRequest: _handleNavigation,
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
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
        scheme == 'sms' ||
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

    if (!request.isMainFrame) return NavigationDecision.navigate;

    if (uri.scheme == 'about' || uri.scheme == 'data') {
      return NavigationDecision.navigate;
    }

    // Call / WhatsApp / Email (and any wa.me deep link).
    if (_isExternalAppUrl(uri)) {
      _openExternal(uri);
      return NavigationDecision.prevent;
    }

    // Website button → company site must leave the preview WebView.
    if ((uri.scheme == 'http' || uri.scheme == 'https') &&
        !_isSameAppHost(uri)) {
      _openExternal(uri);
      return NavigationDecision.prevent;
    }

    return NavigationDecision.navigate;
  }

  /// Web uses `<a target="_blank">` for WhatsApp / Website — WebView often
  /// ignores that. Intercept those clicks and hand the URL to Flutter.
  Future<void> _injectTalkToUsBridge() async {
    if (_hostScriptInjected) return;
    _hostScriptInjected = true;
    try {
      await _controller.runJavaScript('''
(function () {
  if (window.__solar360PreviewTalk) return;
  window.__solar360PreviewTalk = true;

  function shouldHandOff(a) {
    if (!a) return false;
    var href = '';
    try { href = a.href || a.getAttribute('href') || ''; } catch (e) { return false; }
    if (!href) return false;
    var lower = href.toLowerCase();
    if (lower.indexOf('tel:') === 0) return true;
    if (lower.indexOf('mailto:') === 0) return true;
    if (lower.indexOf('sms:') === 0) return true;
    if (lower.indexOf('whatsapp:') === 0) return true;
    try {
      var u = new URL(href, window.location.href);
      var host = (u.hostname || '').toLowerCase();
      if (host === 'wa.me' || host.indexOf('whatsapp.com') >= 0) return true;
      if (a.target === '_blank' && u.origin !== window.location.origin) return true;
    } catch (err) {}
    return false;
  }

  document.addEventListener('click', function (ev) {
    var a = ev.target && ev.target.closest ? ev.target.closest('a[href]') : null;
    if (!shouldHandOff(a)) return;
    ev.preventDefault();
    ev.stopPropagation();
    try { Solar360Preview.postMessage(a.href); } catch (e) {}
  }, true);

  var origOpen = window.open;
  window.open = function (url) {
    if (url) {
      try { Solar360Preview.postMessage(String(url)); } catch (e) {}
      return null;
    }
    return origOpen ? origOpen.apply(window, arguments) : null;
  };
})();
''');
    } catch (_) {
      _hostScriptInjected = false;
    }
  }

  Future<void> _openExternal(Uri uri) async {
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        showAppSnackBar(context, 'Could not open link', isError: true);
      }
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context, 'Could not open link', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppAppBar(title: widget.title),
      body: Stack(
        children: [
          if (_error == null)
            WebViewWidget(controller: _controller)
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.wifi_off_outlined, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Open this link in a browser if WebGL is blocked:\n${widget.url}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () {
                        setState(() {
                          _error = null;
                          _loading = true;
                          _hostScriptInjected = false;
                        });
                        _controller.loadRequest(Uri.parse(widget.url));
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          if (_loading)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }
}
