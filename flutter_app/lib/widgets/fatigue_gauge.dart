import 'dart:math';
import 'package:flutter/material.dart';

/// A circular gauge widget that displays the fatigue score (0–100)
/// with an animated arc and color gradient.
class FatigueGauge extends StatefulWidget {
  final double score;

  const FatigueGauge({super.key, required this.score});

  @override
  State<FatigueGauge> createState() => _FatigueGaugeState();
}

class _FatigueGaugeState extends State<FatigueGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _previousScore = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0, end: widget.score)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
  }

  @override
  void didUpdateWidget(FatigueGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _previousScore = oldWidget.score;
      _animation = Tween<double>(begin: _previousScore, end: widget.score)
          .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _scoreColor(double score) {
    if (score < 30) return const Color(0xFF7EE787);
    if (score < 60) return const Color(0xFFFFAA5E);
    return const Color(0xFFFF6B6B);
  }

  String _scoreLabel(double score) {
    if (score < 20) return 'Alert';
    if (score < 40) return 'Mild';
    if (score < 60) return 'Moderate';
    if (score < 80) return 'High';
    return 'Severe';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final value = _animation.value;
        final color = _scoreColor(value);

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.06),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                'FATIGUE SCORE',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.5),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 160,
                height: 160,
                child: CustomPaint(
                  painter: _GaugePainter(
                    score: value,
                    color: color,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${value.toInt()}',
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                        Text(
                          _scoreLabel(value),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: color.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double score;
  final Color color;

  _GaugePainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 12;

    // Background arc
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    const startAngle = 0.75 * pi;
    const sweepAngle = 1.5 * pi;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Foreground arc
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;

    final fillSweep = (score / 100.0) * sweepAngle;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      fillSweep,
      false,
      fgPaint,
    );

    // Glow effect
    final glowPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      fillSweep,
      false,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.score != score || oldDelegate.color != color;
  }
}
