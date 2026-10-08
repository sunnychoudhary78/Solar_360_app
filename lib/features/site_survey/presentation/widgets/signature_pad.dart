import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class SignaturePad extends StatefulWidget {
  const SignaturePad({super.key});

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _current;

  bool get isEmpty => _strokes.every((stroke) => stroke.length < 2);

  void clear() => setState(() {
    _strokes.clear();
    _current = null;
  });

  Future<Uint8List?> export() async {
    if (isEmpty) return null;
    const width = 640.0;
    const height = 240.0;
    final box = context.size ?? const Size(width, height);
    final scaleX = width / box.width;
    final scaleY = height / box.height;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, height),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    final paint = Paint()
      ..color = const Color(0xFF16342F)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in _strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx * scaleX, stroke.first.dy * scaleY);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx * scaleX, point.dy * scaleY);
      }
      canvas.drawPath(path, paint);
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(width.round(), height.round());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) => setState(() {
        _current = [details.localPosition];
        _strokes.add(_current!);
      }),
      onPanUpdate: (details) => setState(() {
        _current?.add(details.localPosition);
      }),
      onPanEnd: (_) => _current = null,
      child: CustomPaint(
        painter: _SignaturePainter(_strokes),
        child: const SizedBox(height: 180, width: double.infinity),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes);

  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      Paint()..color = const Color(0xFFF7FBF9),
    );
    final paint = Paint()
      ..color = const Color(0xFF16342F)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final point in stroke.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
