import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'package:solar_sales/shared/widgets/app_bar.dart';

/// Customer-facing 3D preview (`/p/<share_code>`) in a WebView for 100% web parity.
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
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFFF5F5F5))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
              _error = null;
            });
          },
          onPageFinished: (_) {
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
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
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
