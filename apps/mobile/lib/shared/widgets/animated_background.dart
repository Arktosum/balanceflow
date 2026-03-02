import 'dart:math';
import 'package:flutter/material.dart';

class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl1;
  late final AnimationController _ctrl2;
  late final AnimationController _ctrl3;

  @override
  void initState() {
    super.initState();
    _ctrl1 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _ctrl2 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _ctrl3 = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl1.dispose();
    _ctrl2.dispose();
    _ctrl3.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return SizedBox.expand(
      child: Stack(
        children: [
          // Base background
          Container(color: const Color(0xFF0F1117)),

          // Purple orb — top left
          AnimatedBuilder(
            animation: _ctrl1,
            builder: (_, __) {
              final t = _ctrl1.value;
              final dx = _lerp3(t, 0, 30, -20);
              final dy = _lerp3(t, 0, -30, 20);
              final scale = _lerp3(t, 1.0, 1.05, 0.95);
              return Positioned(
                left: size.width * -0.1 + dx,
                top: size.height * -0.2 + dy,
                child: Transform.scale(
                  scale: scale,
                  child: _Orb(
                    size: 500,
                    color: const Color(0xFF6C63FF).withOpacity(0.4),
                  ),
                ),
              );
            },
          ),

          // Cyan orb — middle right
          AnimatedBuilder(
            animation: _ctrl2,
            builder: (_, __) {
              final t = _ctrl2.value;
              final dx = _lerp3(t, 0, -40, 20);
              final dy = _lerp3(t, 0, 20, -30);
              final scale = _lerp3(t, 1.0, 1.08, 0.95);
              return Positioned(
                right: size.width * -0.1 + dx,
                top: size.height * 0.4 + dy,
                child: Transform.scale(
                  scale: scale,
                  child: _Orb(
                    size: 420,
                    color: const Color(0xFF00D2FF).withOpacity(0.3),
                  ),
                ),
              );
            },
          ),

          // Red orb — bottom center
          AnimatedBuilder(
            animation: _ctrl3,
            builder: (_, __) {
              final t = _ctrl3.value;
              final dx = _lerp3(t, 0, 20, -30);
              final dy = _lerp3(t, 0, 30, -20);
              final scale = _lerp3(t, 1.0, 1.05, 0.98);
              return Positioned(
                left: size.width * 0.3 + dx,
                bottom: size.height * -0.1 + dy,
                child: Transform.scale(
                  scale: scale,
                  child: _Orb(
                    size: 340,
                    color: const Color(0xFFFF6B6B).withOpacity(0.25),
                  ),
                ),
              );
            },
          ),

          // Grid overlay
          CustomPaint(
            size: Size(size.width, size.height),
            painter: _GridPainter(),
          ),
        ],
      ),
    );
  }

  // Interpolates across 3 keyframes (0→0.5→1.0) matching the CSS animation
  double _lerp3(double t, double a, double b, double c) {
    if (t < 0.5) return lerpDouble(a, b, t * 2)!;
    return lerpDouble(b, c, (t - 0.5) * 2)!;
  }
}

// ---------------------------------------------------------------------------
// Single radial gradient orb
// ---------------------------------------------------------------------------

class _Orb extends StatelessWidget {
  final double size;
  final Color color;
  const _Orb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0.0, 0.7],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Subtle grid overlay
// ---------------------------------------------------------------------------

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..strokeWidth = 1;

    const spacing = 40.0;

    for (double x = 0; x <= size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

double? lerpDouble(double a, double b, double t) => a + (b - a) * t;
