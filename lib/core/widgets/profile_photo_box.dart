import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:solar_sales/core/utils/profile_url.dart';

class ProfilePhotoBox extends StatefulWidget {
  final String? rawProfilePicture;
  final String initial;
  final double fontSize;
  final Color textColor;

  const ProfilePhotoBox({
    super.key,
    required this.rawProfilePicture,
    required this.initial,
    required this.textColor,
    this.fontSize = 28,
  });

  @override
  State<ProfilePhotoBox> createState() => _ProfilePhotoBoxState();
}

class _ProfilePhotoBoxState extends State<ProfilePhotoBox> {
  late List<String> _urls;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _urls = resolveProfilePictureUrls(widget.rawProfilePicture);
  }

  @override
  void didUpdateWidget(covariant ProfilePhotoBox oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.rawProfilePicture != widget.rawProfilePicture) {
      setState(() {
        _urls = resolveProfilePictureUrls(widget.rawProfilePicture);
        _index = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_urls.isEmpty || _index >= _urls.length) {
      return _initialBox();
    }

    final url = _urls[_index];
    final scheme = Theme.of(context).colorScheme;

    return CachedNetworkImage(
      imageUrl: url,
      key: ValueKey(url),
      fit: BoxFit.cover,
      httpHeaders: const {'Accept': 'image/*'},
      placeholder: (context, url) => ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _index++);
        });
        return _initialBox();
      },
    );
  }

  Widget _initialBox() {
    return Center(
      child: Text(
        widget.initial,
        style: TextStyle(
          color: widget.textColor,
          fontSize: widget.fontSize,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
