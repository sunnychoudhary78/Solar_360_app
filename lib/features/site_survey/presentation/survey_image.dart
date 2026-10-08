import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Resize to max 1600 px on the long side and encode JPEG ~quality 80.
Future<(Uint8List bytes, String mimeType)> prepareSurveyImage(Uint8List bytes) async {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return (bytes, 'image/jpeg');
  }
  final longSide = decoded.width > decoded.height ? decoded.width : decoded.height;
  final resized = longSide > 1600
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? 1600 : null,
          height: decoded.height > decoded.width ? 1600 : null,
          interpolation: img.Interpolation.linear,
        )
      : decoded;
  final jpeg = Uint8List.fromList(img.encodeJpg(resized, quality: 80));
  return (jpeg, 'image/jpeg');
}
