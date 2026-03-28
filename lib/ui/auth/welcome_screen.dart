import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'login_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4300),
    )..forward();

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _goToLogin();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToLogin() {
    if (_navigated || !mounted) {
      return;
    }
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final introOpacity = _interval(t, 0.0, 0.18);
          final textOpacity = _interval(t, 0.56, 0.9);
          final buttonOpacity = _interval(t, 0.72, 1.0);

          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _BullMirrorPainter(progress: t),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 18,
                child: TextButton(
                  onPressed: _goToLogin,
                  child: const Text('Omitir'),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.2),
                        radius: 1.12,
                        colors: [
                          Colors.white.withValues(alpha: 0.05 * (1 - t)),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.82),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 78,
                left: 0,
                right: 0,
                child: Opacity(
                  opacity: introOpacity,
                  child: const Center(
                    child: Text(
                      'GYM SYSTEM',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                        letterSpacing: 7,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 24,
                right: 24,
                bottom: 42 + MediaQuery.of(context).padding.bottom,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: textOpacity,
                      child: const Text(
                        'Fuerza que rompe limites',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 29,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Opacity(
                      opacity: textOpacity * 0.9,
                      child: const Text(
                        'Control de gimnasio con una entrada mas agresiva y directa.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 14,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Opacity(
                      opacity: buttonOpacity,
                      child: ElevatedButton.icon(
                        onPressed: _goToLogin,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(220, 52),
                          backgroundColor: GymTheme.neonGreen,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: const Text('Entrar al sistema'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  double _interval(double t, double begin, double end) {
    if (t <= begin) {
      return 0;
    }
    if (t >= end) {
      return 1;
    }
    final value = (t - begin) / (end - begin);
    return Curves.easeOutCubic.transform(value);
  }
}

class _BullMirrorPainter extends CustomPainter {
  const _BullMirrorPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF111111),
          Color(0xFF050505),
          Color(0xFF000000),
        ],
      ).createShader(rect);
    canvas.drawRect(rect, bgPaint);

    final impactPhase = ((progress - 0.42) / 0.22).clamp(0.0, 1.0);
    final settlePhase = ((progress - 0.58) / 0.34).clamp(0.0, 1.0);
    final chargePhase = Curves.easeIn.transform((progress / 0.48).clamp(0.0, 1.0));
    final pulse = math.sin(impactPhase * math.pi);

    _paintAmbientGlow(canvas, size, impactPhase, settlePhase);
    final mirrorRect = _paintMirror(canvas, size, impactPhase, settlePhase);
    _paintBull(canvas, size, chargePhase, impactPhase);
    _paintCracks(canvas, mirrorRect, impactPhase);
    _paintShards(canvas, size, impactPhase, settlePhase);
    _paintDust(canvas, mirrorRect.center, impactPhase, settlePhase);
  }

  void _paintAmbientGlow(
    Canvas canvas,
    Size size,
    double impactPhase,
    double settlePhase,
  ) {
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.06),
        radius: 0.82,
        colors: [
          GymTheme.neonGreen.withValues(
            alpha: 0.06 + (impactPhase * 0.12) - (settlePhase * 0.04),
          ),
          Colors.lightBlueAccent.withValues(alpha: 0.05 * impactPhase),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, glowPaint);
  }

  Rect _paintMirror(
    Canvas canvas,
    Size size,
    double impactPhase,
    double settlePhase,
  ) {
    final mirrorWidth = size.width * 0.54;
    final mirrorHeight = math.min(size.height * 0.4, 300.0);
    final center = Offset(size.width * 0.64, size.height * 0.38);
    final shake = impactPhase > 0
        ? math.sin(impactPhase * 30) * (1 - settlePhase) * 7
        : 0.0;
    final mirrorRect = Rect.fromCenter(
      center: center.translate(shake, shake * 0.45),
      width: mirrorWidth,
      height: mirrorHeight,
    );
    final rrect = RRect.fromRectAndRadius(mirrorRect, const Radius.circular(26));

    canvas.drawRRect(
      rrect,
      Paint()
        ..color = const Color(0xFFB8E1F1).withValues(alpha: 0.08),
    );
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = Colors.white.withValues(alpha: 0.16),
    );
    canvas.drawRRect(
      rrect.deflate(8),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.08),
    );

    final reflection = Path()
      ..moveTo(mirrorRect.left + mirrorRect.width * 0.12, mirrorRect.top + 22)
      ..lineTo(mirrorRect.left + mirrorRect.width * 0.32, mirrorRect.top + 22)
      ..lineTo(mirrorRect.left + mirrorRect.width * 0.12, mirrorRect.bottom - 34)
      ..close();
    canvas.drawPath(
      reflection,
      Paint()..color = Colors.white.withValues(alpha: 0.05),
    );

    return mirrorRect;
  }

  void _paintBull(Canvas canvas, Size size, double chargePhase, double impactPhase) {
    final start = -size.width * 0.2;
    final end = size.width * 0.42;
    final x = lerpDouble(start, end, chargePhase) ?? end;
    final y = size.height * 0.46;
    final scale = lerpDouble(0.78, 1.04, chargePhase) ?? 1;
    final squash = 1 - (impactPhase * 0.12);

    canvas.save();
    canvas.translate(x, y);
    canvas.scale(scale, scale * squash);

    final shadowPath = _bullPath();
    canvas.drawPath(
      shadowPath.shift(const Offset(8, 10)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.34)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20),
    );

    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF181818),
          Color(0xFF050505),
        ],
      ).createShader(const Rect.fromLTWH(0, 0, 270, 180));

    canvas.drawPath(shadowPath, bodyPaint);
    canvas.drawPath(
      shadowPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = Colors.white.withValues(alpha: 0.05),
    );

    final eyePaint = Paint()
      ..color = Colors.redAccent.withValues(alpha: 0.9 - impactPhase * 0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(const Offset(212, 78), 4.2, eyePaint);

    canvas.restore();
  }

  Path _bullPath() {
    final path = Path()
      ..moveTo(18, 108)
      ..quadraticBezierTo(22, 78, 40, 68)
      ..quadraticBezierTo(62, 49, 104, 50)
      ..quadraticBezierTo(154, 46, 178, 62)
      ..quadraticBezierTo(196, 48, 220, 54)
      ..quadraticBezierTo(240, 58, 248, 74)
      ..quadraticBezierTo(260, 74, 268, 66)
      ..quadraticBezierTo(252, 52, 248, 38)
      ..quadraticBezierTo(234, 22, 216, 26)
      ..quadraticBezierTo(224, 36, 218, 48)
      ..quadraticBezierTo(206, 34, 186, 38)
      ..quadraticBezierTo(174, 20, 156, 16)
      ..quadraticBezierTo(134, 10, 118, 18)
      ..quadraticBezierTo(82, 12, 56, 28)
      ..quadraticBezierTo(30, 44, 20, 74)
      ..quadraticBezierTo(6, 86, 0, 102)
      ..lineTo(18, 108)
      ..lineTo(28, 160)
      ..lineTo(48, 160)
      ..lineTo(58, 112)
      ..lineTo(104, 112)
      ..lineTo(96, 160)
      ..lineTo(116, 160)
      ..lineTo(126, 112)
      ..lineTo(170, 112)
      ..lineTo(162, 160)
      ..lineTo(182, 160)
      ..lineTo(196, 112)
      ..lineTo(230, 112)
      ..lineTo(222, 160)
      ..lineTo(242, 160)
      ..lineTo(254, 104)
      ..quadraticBezierTo(236, 114, 208, 116)
      ..quadraticBezierTo(144, 120, 108, 122)
      ..quadraticBezierTo(54, 124, 18, 108)
      ..close();
    return path;
  }

  void _paintCracks(Canvas canvas, Rect mirrorRect, double impactPhase) {
    if (impactPhase <= 0) {
      return;
    }

    final center = Offset(mirrorRect.left + mirrorRect.width * 0.23, mirrorRect.center.dy);
    final crackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.22 + impactPhase * 0.32)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final rays = <double>[
      -1.28,
      -0.96,
      -0.72,
      -0.34,
      -0.08,
      0.22,
      0.58,
      0.92,
      1.18,
    ];

    for (var i = 0; i < rays.length; i++) {
      final angle = rays[i];
      final length = mirrorRect.width * (0.2 + (i % 3) * 0.12) * impactPhase;
      crackPaint.strokeWidth = i.isEven ? 2.0 : 1.2;
      final end = center + Offset(math.cos(angle) * length, math.sin(angle) * length);
      final path = Path()..moveTo(center.dx, center.dy);

      final segments = 3 + (i % 3);
      for (var step = 1; step <= segments; step++) {
        final segmentT = step / segments;
        final offset = Offset(
          math.cos(angle) * length * segmentT,
          math.sin(angle) * length * segmentT,
        );
        final jag = Offset(
          math.sin(angle) * (step.isEven ? 6 : -6) * impactPhase,
          -math.cos(angle) * (step.isEven ? 6 : -6) * impactPhase,
        );
        final point = center + offset + jag;
        path.lineTo(point.dx, point.dy);
      }
      path.lineTo(end.dx, end.dy);
      canvas.drawPath(path, crackPaint);
    }

    canvas.drawCircle(
      center,
      10 + 28 * impactPhase,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
  }

  void _paintShards(
    Canvas canvas,
    Size size,
    double impactPhase,
    double settlePhase,
  ) {
    if (impactPhase <= 0) {
      return;
    }

    final origin = Offset(size.width * 0.45, size.height * 0.39);
    final shardCount = 14;
    for (var i = 0; i < shardCount; i++) {
      final angle = -0.95 + (i * 0.18);
      final spread = 40 + (i % 4) * 16;
      final distance = (impactPhase * 130) + (settlePhase * spread);
      final drift = Offset(
        math.cos(angle) * distance,
        math.sin(angle) * distance + (settlePhase * 18 * (i.isEven ? 1 : -1)),
      );
      final center = origin + drift;
      final rotation = angle + impactPhase * 2.8 + i * 0.14;
      final scale = 0.8 + (i % 3) * 0.2;
      final alpha = (0.42 - settlePhase * 0.22).clamp(0.08, 0.42);

      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(rotation);

      final path = Path()
        ..moveTo(-6 * scale, -10 * scale)
        ..lineTo(10 * scale, -4 * scale)
        ..lineTo(3 * scale, 9 * scale)
        ..lineTo(-9 * scale, 5 * scale)
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: alpha)
          ..style = PaintingStyle.fill,
      );
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = Colors.lightBlueAccent.withValues(alpha: alpha + 0.08),
      );
      canvas.restore();
    }
  }

  void _paintDust(
    Canvas canvas,
    Offset center,
    double impactPhase,
    double settlePhase,
  ) {
    if (impactPhase <= 0) {
      return;
    }

    for (var i = 0; i < 18; i++) {
      final angle = -1.4 + (i * 0.17);
      final distance = 18 + (impactPhase * 78) + (i % 5) * 6;
      final point = center +
          Offset(
            math.cos(angle) * distance,
            math.sin(angle) * distance * 0.7,
          );
      final radius = (3.5 - settlePhase * 1.8).clamp(1.0, 3.5);
      canvas.drawCircle(
        point,
        radius,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.12 - settlePhase * 0.05),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BullMirrorPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

double? lerpDouble(num a, num b, double t) {
  return a + (b - a) * t;
}
