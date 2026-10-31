import 'package:flutter/material.dart';

/// `border-2 border-dashed rounded-2xl`: Flutter no trae bordes punteados.
///
/// Lo usan el dropzone de fotos y los estados vacios del panel.
class RtcBordePunteado extends OutlinedBorder {
  const RtcBordePunteado({
    required this.color,
    required this.radio,
    this.grosor = 2,
  }) : super(side: BorderSide.none);

  final Color color;
  final double radio;
  final double grosor;

  /// `border-dashed` de Tailwind: rayas de 6px con 6px de hueco.
  static const _raya = 6.0;
  static const _hueco = 6.0;

  RRect _rrect(Rect rect) =>
      RRect.fromRectAndRadius(rect.deflate(grosor / 2), Radius.circular(radio));

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(grosor);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_rrect(rect).deflate(grosor / 2));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radio)));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor
      ..color = color;

    for (final tramo in (Path()..addRRect(_rrect(rect))).computeMetrics()) {
      var d = 0.0;
      while (d < tramo.length) {
        canvas.drawPath(
          tramo.extractPath(d, (d + _raya).clamp(0.0, tramo.length)),
          pincel,
        );
        d += _raya + _hueco;
      }
    }
  }

  @override
  ShapeBorder scale(double t) =>
      RtcBordePunteado(color: color, radio: radio * t, grosor: grosor * t);

  @override
  RtcBordePunteado copyWith({BorderSide? side}) => this;
}
