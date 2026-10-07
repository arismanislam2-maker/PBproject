import 'dart:math' as math;
import 'package:flutter/material.dart';

class ChartSegment {
  final String label;
  final double amount;
  final double percentage; // e.g. 60 for 60%
  final Color color;
  final IconData? icon;

  const ChartSegment({
    required this.label,
    required this.amount,
    required this.percentage,
    required this.color,
    this.icon,
  });
}

class DonutChart extends StatelessWidget {
  final List<ChartSegment> segments;
  final String centerTitle;
  final String centerAmount;
  final double size;
  final double strokeWidth;

  const DonutChart({
    super.key,
    required this.segments,
    required this.centerTitle,
    required this.centerAmount,
    this.size = 180,
    this.strokeWidth = 26,
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
            painter: _DonutChartPainter(
              segments: segments,
              strokeWidth: strokeWidth,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centerTitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8A7E76),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                centerAmount,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E2620),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  final List<ChartSegment> segments;
  final double strokeWidth;

  _DonutChartPainter({
    required this.segments,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final totalPercentage = segments.fold<double>(
      0,
      (sum, item) => sum + item.percentage,
    );

    if (totalPercentage <= 0) return;

    double startAngle = -math.pi / 2; // start at top

    for (final segment in segments) {
      final sweepAngle = (segment.percentage / totalPercentage) * 2 * math.pi;

      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}
