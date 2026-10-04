import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

class WishJarEmptyIllustration extends StatelessWidget {
  const WishJarEmptyIllustration({
    super.key,
    this.size = 190,
  });

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(
        painter: _WishJarPainter(),
      ),
    );
  }
}

class _WishJarPainter extends CustomPainter {
  const _WishJarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 190;

    canvas.save();
    canvas.scale(scale);

    final outlinePaint = Paint()
      ..color = const Color(0xFF66586A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter
      ..isAntiAlias = false;

    final secondaryPaint = Paint()
      ..color = const Color(0xFF3B313E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.square
      ..isAntiAlias = false;

    final glassPaint = Paint()
      ..color = const Color(0x3029212C)
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;

    final coralPaint = Paint()
      ..color = AppColors.coral
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;

    final softPinkPaint = Paint()
      ..color = const Color(0xFFF3A8B6)
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;

    final lavenderPaint = Paint()
      ..color = const Color(0xFFAFA6BE)
      ..style = PaintingStyle.fill
      ..isAntiAlias = false;

    // Interior tenue del bote
    final jarFill = Path()
      ..moveTo(55, 53)
      ..lineTo(135, 53)
      ..lineTo(148, 70)
      ..lineTo(153, 154)
      ..lineTo(142, 171)
      ..lineTo(48, 171)
      ..lineTo(37, 154)
      ..lineTo(42, 70)
      ..close();

    canvas.drawPath(jarFill, glassPaint);

    // Tapa
    canvas.drawRect(
      const Rect.fromLTWH(57, 35, 76, 8),
      outlinePaint,
    );

    canvas.drawRect(
      const Rect.fromLTWH(52, 46, 86, 8),
      secondaryPaint,
    );

    // Contorno pixelado del bote
    final jarOutline = Path()
      ..moveTo(52, 54)
      ..lineTo(42, 67)
      ..lineTo(38, 84)
      ..lineTo(38, 150)
      ..lineTo(48, 169)
      ..lineTo(62, 176)
      ..lineTo(128, 176)
      ..lineTo(142, 169)
      ..lineTo(152, 150)
      ..lineTo(152, 84)
      ..lineTo(148, 67)
      ..lineTo(138, 54);

    canvas.drawPath(jarOutline, outlinePaint);

    // Brillo lateral
    final shinePath = Path()
      ..moveTo(54, 76)
      ..lineTo(49, 87)
      ..lineTo(49, 108);

    canvas.drawPath(shinePath, secondaryPaint);

    // Papel coral
    final coralNote = Path()
      ..moveTo(72, 112)
      ..lineTo(104, 107)
      ..lineTo(110, 134)
      ..lineTo(79, 141)
      ..close();

    canvas.drawPath(coralNote, coralPaint);

    // Papel rosado
    final pinkNote = Path()
      ..moveTo(102, 126)
      ..lineTo(130, 132)
      ..lineTo(124, 155)
      ..lineTo(96, 150)
      ..close();

    canvas.drawPath(pinkNote, softPinkPaint);

    // Papel lavanda
    final lavenderNote = Path()
      ..moveTo(59, 133)
      ..lineTo(82, 128)
      ..lineTo(89, 153)
      ..lineTo(66, 159)
      ..close();

    canvas.drawPath(lavenderNote, lavenderPaint);

    // Píxeles decorativos
    canvas.drawRect(
      const Rect.fromLTWH(24, 95, 7, 7),
      secondaryPaint..style = PaintingStyle.fill,
    );

    canvas.drawRect(
      const Rect.fromLTWH(160, 74, 7, 7),
      secondaryPaint,
    );

    canvas.drawRect(
      const Rect.fromLTWH(164, 139, 6, 6),
      coralPaint,
    );

    // Pequeño corazón coral
    final heart = Path()
      ..moveTo(95, 23)
      ..lineTo(87, 15)
      ..lineTo(78, 23)
      ..lineTo(95, 40)
      ..lineTo(112, 23)
      ..lineTo(103, 15)
      ..close();

    canvas.drawPath(heart, coralPaint);

    // Línea que conecta el corazón con el bote
    final connectionLine = Paint()
      ..color = AppColors.coral
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.square
      ..isAntiAlias = false;

    canvas.drawLine(
      const Offset(95, 38),
      const Offset(95, 49),
      connectionLine,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WishJarPainter oldDelegate) {
    return false;
  }
}
