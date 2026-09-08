import 'package:flutter/material.dart';

class ExcelDownloadButton extends StatelessWidget {
  const ExcelDownloadButton({
    super.key,
    required this.onPressed,
    this.enabled = true,
    this.busy = false,
    this.compact = false,
    this.label = 'Excel',
    this.tooltip = 'Download Excel',
  });

  final VoidCallback? onPressed;
  final bool enabled;
  final bool busy;
  final bool compact;
  final String label;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && !busy && onPressed != null;
    if (compact) {
      return IconButton(
        tooltip: busy ? 'Preparing…' : tooltip,
        onPressed: canTap ? onPressed : null,
        icon: busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_rounded),
      );
    }

    return Tooltip(
      message: tooltip,
      child: TextButton.icon(
        onPressed: canTap ? onPressed : null,
        icon: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_rounded, size: 18),
        label: Text(busy ? 'Preparing…' : label),
      ),
    );
  }
}
