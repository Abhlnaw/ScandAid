import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/scan.dart';

class ScanPhoto extends StatelessWidget {
  final Uint8List bytes;
  final int width, height;
  final List<Offset> points;
  final String? mask;
  final Calibration? calibration;
  final List<Offset> reference;
  final bool box;
  final ValueChanged<Offset>? onTap;
  const ScanPhoto({
    super.key,
    required this.bytes,
    required this.width,
    required this.height,
    this.points = const [],
    this.mask,
    this.calibration,
    this.reference = const [],
    this.box = false,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final w = math.min(constraints.maxWidth, 500 * width / height);
      final h = w * height / width;
      return Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: w,
            height: h,
            child: GestureDetector(
              onTapDown: onTap == null
                  ? null
                  : (details) => onTap!(
                      Offset(
                        (details.localPosition.dx / w).clamp(0, 1),
                        (details.localPosition.dy / h).clamp(0, 1),
                      ),
                    ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(bytes, fit: BoxFit.fill, gaplessPlayback: true),
                  if (mask != null)
                    ColorFiltered(
                      colorFilter: const ColorFilter.mode(
                        Color(0x8800DCAF),
                        BlendMode.srcIn,
                      ),
                      child: Image.memory(
                        base64Decode(mask!),
                        fit: BoxFit.fill,
                      ),
                    ),
                  CustomPaint(
                    painter: OutlinePainter(
                      points,
                      box,
                      calibration == null
                          ? reference
                          : [calibration!.start, calibration!.end],
                      mask != null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class OutlinePainter extends CustomPainter {
  final List<Offset> points, reference;
  final bool box, hasMask;
  OutlinePainter(this.points, this.box, this.reference, this.hasMask);
  @override
  void paint(Canvas canvas, Size size) {
    Offset scale(Offset p) => Offset(p.dx * size.width, p.dy * size.height);
    if (!hasMask && points.isNotEmpty) {
      final path = Path()
        ..moveTo(scale(points.first).dx, scale(points.first).dy);
      if (box && points.length == 2) {
        path.addRect(Rect.fromPoints(scale(points.first), scale(points.last)));
      } else {
        for (final p in points.skip(1)) {
          path.lineTo(scale(p).dx, scale(p).dy);
        }
        if (points.length > 2) path.close();
      }
      canvas.drawPath(path, Paint()..color = const Color(0x3342FFD0));
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF42FFD0)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      for (final p in points) {
        canvas.drawCircle(scale(p), 4, Paint()..color = Colors.white);
      }
    }
    final refPaint = Paint()
      ..color = const Color(0xFFFFD666)
      ..strokeWidth = 3;
    if (reference.length == 2) {
      canvas.drawLine(scale(reference.first), scale(reference.last), refPaint);
    }
    for (final p in reference) {
      canvas.drawCircle(scale(p), 5, refPaint);
    }
  }

  @override
  bool shouldRepaint(covariant OutlinePainter oldDelegate) => true;
}
