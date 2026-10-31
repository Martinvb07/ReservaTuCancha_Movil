import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/shadows.dart';

/// Port de `PriceSlider` de `empresas/page.client.tsx`.
///
/// La web superpone dos `<input type=range>` y solo el thumb recibe eventos;
/// aca es un RangeSlider con el mismo aspecto: pista de 6px gris, tramo activo
/// verde y thumbs de 20px con borde blanco y sombra de marca.
class PriceSlider extends StatelessWidget {
  const PriceSlider({
    super.key,
    required this.lo,
    required this.hi,
    required this.onChanged,
  });

  final int lo;
  final int hi;
  final void Function(int lo, int hi) onChanged;

  static const min = 0;
  static const max = 300000;
  static const step = 10000;

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 6,
        activeTrackColor: Green.c600,
        inactiveTrackColor: Gray.c200,
        rangeThumbShape: const _PriceThumb(),
        overlayShape: SliderComponentShape.noOverlay,
        rangeTrackShape: const RoundedRectRangeSliderTrackShape(),
        showValueIndicator: ShowValueIndicator.never,
      ),
      child: RangeSlider(
        min: min.toDouble(),
        max: max.toDouble(),
        divisions: (max - min) ~/ step,
        values: RangeValues(lo.toDouble(), hi.toDouble()),
        onChanged: (v) => onChanged(v.start.round(), v.end.round()),
      ),
    );
  }
}

/// `.price-thumb::-webkit-slider-thumb`: 20px, blanco de 2px alrededor del
/// verde y sombra `0 2px 8px rgba(22,163,74,.4)`.
class _PriceThumb extends RangeSliderThumbShape {
  const _PriceThumb();

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => const Size(20, 20);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    bool? isDiscrete,
    bool? isEnabled,
    bool? isOnTop,
    TextDirection? textDirection,
    required SliderThemeData sliderTheme,
    Thumb? thumb,
    bool? isPressed,
  }) {
    final canvas = context.canvas;
    final shadow = RtcShadows.priceThumb.first;

    canvas.drawCircle(
      center + shadow.offset,
      10,
      Paint()
        ..color = shadow.color
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, shadow.blurRadius),
    );
    canvas.drawCircle(center, 10, Paint()..color = Colors.white);
    canvas.drawCircle(center, 8, Paint()..color = Green.c600);
  }
}
