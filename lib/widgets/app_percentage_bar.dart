import 'package:flutter/material.dart';

class PercentageSegment {
  final String label;
  final double value;
  final Color color;

  const PercentageSegment({
    required this.label,
    required this.value,
    required this.color,
  });
}

/// Lightweight CustomPainter percentage bar for category share and payment methods.
class AppPercentageBar extends StatelessWidget {
  final List<PercentageSegment> segments;
  final double height;
  final double borderRadius;

  const AppPercentageBar({
    super.key,
    required this.segments,
    this.height = 10,
    this.borderRadius = 5,
  });

  @override
  Widget build(BuildContext context) {
    final total = segments.fold(0.0, (sum, s) => sum + s.value);
    if (total <= 0.001) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: CustomPaint(
            size: Size(double.infinity, height),
            painter: _PercentageBarPainter(segments: segments, total: total),
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: segments.where((s) => s.value > 0).map((s) {
            final pct = (s.value / total * 100).toStringAsFixed(1);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: s.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${s.label} ($pct%)',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _PercentageBarPainter extends CustomPainter {
  final List<PercentageSegment> segments;
  final double total;

  _PercentageBarPainter({required this.segments, required this.total});

  @override
  void paint(Canvas canvas, Size size) {
    if (total <= 0) return;
    double currentX = 0;
    final paint = Paint()..style = PaintingStyle.fill;

    for (final seg in segments) {
      if (seg.value <= 0) continue;
      final segWidth = (seg.value / total) * size.width;
      paint.color = seg.color;
      canvas.drawRect(Rect.fromLTWH(currentX, 0, segWidth, size.height), paint);
      currentX += segWidth;
    }
  }

  @override
  bool shouldRepaint(covariant _PercentageBarPainter oldDelegate) {
    return oldDelegate.segments != segments || oldDelegate.total != total;
  }
}
