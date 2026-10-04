import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

class WishJarIllustration extends StatefulWidget {
  const WishJarIllustration({super.key, this.reduceMotion = false});

  final bool reduceMotion;

  @override
  State<WishJarIllustration> createState() => _WishJarIllustrationState();
}

class _WishJarIllustrationState extends State<WishJarIllustration>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    if (!widget.reduceMotion) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant WishJarIllustration oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reduceMotion == widget.reduceMotion) return;
    widget.reduceMotion
        ? _controller.stop()
        : _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = widget.reduceMotion ? 0.35 : _controller.value;
          return CustomPaint(
            painter: _WishJarPainter(progress),
            size: const Size(220, 244),
          );
        },
      ),
    );
  }
}

class _WishJarPainter extends CustomPainter {
  const _WishJarPainter(this.progress);

  final double progress;

  static const _pixel = 7.0;

  @override
  void paint(Canvas canvas, Size size) {
    final float = math.sin(progress * math.pi) * 3;
    final outline = Paint()
      ..color = AppColors.inactive
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;

    _drawBackgroundPixels(canvas, size, float);

    final jar = Path()
      ..moveTo(72, 92)
      ..lineTo(72, 101)
      ..lineTo(58, 115)
      ..lineTo(51, 136)
      ..lineTo(51, 217)
      ..lineTo(59, 230)
      ..lineTo(72, 237)
      ..lineTo(169, 237)
      ..lineTo(183, 230)
      ..lineTo(190, 217)
      ..lineTo(190, 136)
      ..lineTo(183, 115)
      ..lineTo(169, 101)
      ..lineTo(169, 92);
    canvas.drawPath(jar, outline);

    final rim = Paint()
      ..color = const Color(0xFF655A68)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6;
    canvas.drawRect(const Rect.fromLTWH(70, 70, 101, 13), rim);
    canvas.drawLine(const Offset(76, 92), const Offset(166, 92), rim);

    final shine = Paint()
      ..color = AppColors.lavender.withValues(alpha: .7)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(const Offset(68, 127), const Offset(68, 157), shine);
    canvas.drawLine(const Offset(75, 120), const Offset(88, 108), shine);

    _drawFoldedNote(
      canvas,
      center: Offset(93, 191 + float),
      color: AppColors.lavender,
      angle: -.20,
      size: const Size(45, 34),
    );
    _drawFoldedNote(
      canvas,
      center: Offset(130, 174 - float),
      color: AppColors.coral,
      angle: .15,
      size: const Size(48, 37),
    );
    _drawFoldedNote(
      canvas,
      center: Offset(157, 199 + float * .6),
      color: AppColors.pink,
      angle: .22,
      size: const Size(42, 34),
    );
    _drawFoldedNote(
      canvas,
      center: const Offset(118, 218),
      color: AppColors.coral,
      angle: -.10,
      size: const Size(48, 31),
    );
    _drawFoldedNote(
      canvas,
      center: const Offset(161, 224),
      color: const Color(0xFF332A35),
      angle: -.20,
      size: const Size(43, 28),
    );

    _drawFallingWish(canvas, float);
  }

  void _drawBackgroundPixels(Canvas canvas, Size size, double float) {
    final muted = Paint()..color = const Color(0xFF756C78);
    final coral = Paint()..color = AppColors.coral;
    final pixels = <(double, double, Paint)>[
      (21, 147, muted),
      (12, 213, coral),
      (35, 236, muted),
      (199, 132, coral),
      (207, 205, muted),
      (194, 239, muted),
    ];
    for (final p in pixels) {
      canvas.drawRect(
          Rect.fromLTWH(p.$1, p.$2 + float * .25, _pixel, _pixel), p.$3);
    }
  }

  void _drawFallingWish(Canvas canvas, double float) {
    final paint = Paint()..color = AppColors.coral;
    const points = [
      Offset(82, 7),
      Offset(89, 14),
      Offset(96, 21),
      Offset(103, 28),
      Offset(110, 35),
      Offset(117, 42),
      Offset(124, 35),
      Offset(131, 28),
      Offset(138, 21),
      Offset(145, 14),
      Offset(152, 7),
      Offset(117, 49),
      Offset(117, 56),
    ];
    for (final point in points) {
      canvas.drawRect(
        Rect.fromLTWH(point.dx, point.dy + float, _pixel, _pixel),
        paint,
      );
    }
  }

  void _drawFoldedNote(
    Canvas canvas, {
    required Offset center,
    required Color color,
    required double angle,
    required Size size,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final rect = Rect.fromCenter(
        center: Offset.zero, width: size.width, height: size.height);
    canvas.drawRect(rect, Paint()..color = color);
    final fold = Path()
      ..moveTo(rect.right - 13, rect.top)
      ..lineTo(rect.right, rect.top)
      ..lineTo(rect.right, rect.top + 13)
      ..close();
    canvas.drawPath(
        fold, Paint()..color = AppColors.textPrimary.withValues(alpha: .45));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WishJarPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
