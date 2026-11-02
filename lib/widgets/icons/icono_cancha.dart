import 'package:flutter/widgets.dart';

/// Una cancha vista desde arriba (marco, línea central, círculo y las dos
/// áreas), con el mismo trazo que los íconos de Lucide para que calce al lado
/// de la casa y el calendario de la barra.
class IconoCancha extends StatelessWidget {
  const IconoCancha({super.key, this.size = 24, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _Cancha(color)),
    );
  }
}

class _Cancha extends CustomPainter {
  _Cancha(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Se dibuja en la grilla de 24 de Lucide y se escala.
    final k = size.width / 24;
    canvas.scale(k);
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawRRect(
      RRect.fromLTRBR(2, 5, 22, 19, const Radius.circular(2.5)),
      p,
    );
    canvas.drawLine(const Offset(12, 5), const Offset(12, 19), p);
    canvas.drawCircle(const Offset(12, 12), 2.6, p);
    // Áreas
    canvas.drawPath(
      Path()
        ..moveTo(2, 9)
        ..lineTo(5, 9)
        ..lineTo(5, 15)
        ..lineTo(2, 15),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(22, 9)
        ..lineTo(19, 9)
        ..lineTo(19, 15)
        ..lineTo(22, 15),
      p,
    );
  }

  @override
  bool shouldRepaint(_Cancha old) => old.color != color;
}
