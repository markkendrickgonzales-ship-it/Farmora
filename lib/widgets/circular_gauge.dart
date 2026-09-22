import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class GaugeWidget extends StatelessWidget {
  final double pct;
  final Color color;
  final double size;
  final String label;
  final String? sub;

  const GaugeWidget({
    super.key,
    required this.pct,
    required this.color,
    this.size = 108,
    required this.label,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _GaugePainter(pct: pct, color: color),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: FarmoraColors.ink,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              if (sub != null)
                Text(
                  sub!,
                  style: const TextStyle(
                    fontSize: 10,
                    color: FarmoraColors.inkFaint,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double pct;
  final Color color;

  _GaugePainter({required this.pct, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - 8;

    final bgPaint = Paint()
      ..color = FarmoraColors.line
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke;

    final fgPaint = Paint()
      ..color = color
      ..strokeWidth = 8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final sweepAngle = 2 * pi * (pct / 100);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.pct != pct || oldDelegate.color != color;
  }
}
