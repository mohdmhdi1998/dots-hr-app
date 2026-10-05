import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../config/app_theme.dart';

/// A box to sign in with a finger. [SignaturePadState.toDataUri] returns the drawing as a PNG data URI.
class SignaturePad extends StatefulWidget {
  final double height;
  final VoidCallback? onChanged;

  const SignaturePad({super.key, this.height = 180, this.onChanged});

  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = [];
  Size _size = Size.zero;

  bool get isEmpty => _strokes.every((s) => s.length < 2);

  void clear() {
    setState(_strokes.clear);
    widget.onChanged?.call();
  }

  Future<String?> toDataUri() async {
    if (isEmpty || _size == Size.zero) return null;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Offset.zero & _size, Paint()..color = Colors.white);
    _SignaturePainter(_strokes).paint(canvas, _size);
    final image = await recorder.endRecording().toImage(_size.width.ceil(), _size.height.ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return null;
    return 'data:image/png;base64,${base64Encode(bytes.buffer.asUint8List())}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.divider, width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LayoutBuilder(builder: (context, constraints) {
            _size = Size(constraints.maxWidth, constraints.maxHeight);
            return GestureDetector(
              onPanStart: (d) => setState(() => _strokes.add([d.localPosition])),
              onPanUpdate: (d) => setState(() => _strokes.last.add(d.localPosition)),
              onPanEnd: (_) => widget.onChanged?.call(),
              child: CustomPaint(
                size: _size,
                painter: _SignaturePainter(_strokes),
                child: isEmpty
                    ? const Center(child: Text('وقّع هنا بإصبعك', style: TextStyle(color: AppColors.textSecondary)))
                    : const SizedBox.expand(),
              ),
            );
          }),
        ),
      ),
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: TextButton.icon(onPressed: isEmpty ? null : clear, icon: const Icon(Icons.refresh, size: 18), label: const Text('مسح')),
      ),
    ]);
  }
}

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;

  _SignaturePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0F1B33)
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}
