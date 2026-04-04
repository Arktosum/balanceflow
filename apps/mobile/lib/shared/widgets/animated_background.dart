import 'package:flutter/material.dart';


class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with TickerProviderStateMixin {
  late final AnimationController _c1, _c2, _c3;

  @override
  void initState() {
    super.initState();
    _c1 = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
    _c2 = AnimationController(vsync: this, duration: const Duration(seconds: 10))
      ..repeat();
    _c3 = AnimationController(vsync: this, duration: const Duration(seconds: 12))
      ..repeat();
  }

  @override
  void dispose() {
    _c1.dispose();
    _c2.dispose();
    _c3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: const Color(0xFF0D0F17)),
        AnimatedBuilder(
          animation: Listenable.merge([_c1, _c2, _c3]),
          builder: (_, __) => CustomPaint(
            painter: _BgPainter(_c1.value, _c2.value, _c3.value),
            size: Size.infinite,
          ),
        ),
      ],
    );
  }
}

class _BgPainter extends CustomPainter {
  final double t1, t2, t3;
  _BgPainter(this.t1, this.t2, this.t3);

  double _lerp3(double t, double a, double b, double c) {
    if (t < 0.5) return a + (b - a) * (t * 2);
    return b + (c - b) * ((t - 0.5) * 2);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    void drawOrb(double t, Color color, double baseX, double baseY,
        double radius, double dxRange, double dyRange) {
      final dx = _lerp3(t, 0, dxRange, 0);
      final dy = _lerp3(t, 0, dyRange, 0);
      final rect = Rect.fromCircle(
        center: Offset(baseX * w + dx, baseY * h + dy),
        radius: radius,
      );
      canvas.drawOval(
        rect,
        Paint()
          ..shader = RadialGradient(colors: [
            color.withOpacity(0.18),
            color.withOpacity(0.0),
          ]).createShader(rect),
      );
    }

    drawOrb(t1, const Color(0xFF6C63FF), 0.1, 0.15, 280, 60, 40);
    drawOrb(t2, const Color(0xFF00D2FF), 0.85, 0.4, 240, -50, 60);
    drawOrb(t3, const Color(0xFFFF6B6B), 0.4, 0.75, 200, 40, -50);

    // Grid
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..strokeWidth = 1;
    const step = 40.0;
    for (double x = 0; x < w; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }
    for (double y = 0; y < h; y += step) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(_BgPainter old) =>
      old.t1 != t1 || old.t2 != t2 || old.t3 != t3;
}

