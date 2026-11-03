import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/palette.dart';
import '../theme/tokens.dart';
import 'motion/rtc_pressable.dart';

/// La estrella de lucide, dibujada a mano porque la web la pinta con
/// `fill-*` y el icono del paquete es solo contorno.
///
/// El relleno y el trazo se piden por separado: la web los usa distintos
/// (`fill-gray-100 text-gray-200` en las vacias de una resena).
class RtcStar extends StatelessWidget {
  const RtcStar({
    super.key,
    required this.size,
    required this.fill,
    required this.stroke,
  });

  final double size;
  final Color fill;
  final Color stroke;

  static String _hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

  @override
  Widget build(BuildContext context) {
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
        'fill="${_hex(fill)}" stroke="${_hex(stroke)}" stroke-width="1.5" '
        'stroke-linejoin="round"><polygon points="12 2 15.09 8.26 22 9.27 '
        '17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 '
        '12 2"/></svg>';
    return SvgPicture.string(svg, width: size, height: size);
  }
}

/// Port de `Frontend/src/components/reviews/StarRating.tsx`.
///
/// Llenas: `fill-yellow-400 text-yellow-400`. Vacias: `fill-muted
/// text-muted-foreground`, o sea los tokens de shadcn y no la escala gray.
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.value,
    this.size = StarSize.md,
    this.emptyFill,
    this.emptyStroke,
    this.onChanged,
  });

  /// Cuantas estrellas van llenas, de 0 a 5.
  final num value;

  final StarSize size;

  /// Para la variante de las resenas, que usa `fill-gray-100 text-gray-200`
  /// en vez de los tokens.
  final Color? emptyFill;
  final Color? emptyStroke;

  /// Si es null la fila es de solo lectura (`readonly` en la web).
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 5; i++)
          Padding(
            padding: EdgeInsets.only(right: i == 4 ? 0 : 2), // gap-0.5
            child: RtcPressable(
              onTap: onChanged == null ? null : () => onChanged!(i + 1),
              child: value > i
                  ? RtcStar(
                      size: size.px,
                      fill: Yellow.c400,
                      stroke: Yellow.c400,
                    )
                  : RtcStar(
                      size: size.px,
                      fill:
                          emptyFill ??
                          (RtcModo.oscuro ? RtcDark.muted : RtcLight.muted),
                      stroke:
                          emptyStroke ??
                          (RtcModo.oscuro
                              ? RtcDark.mutedForeground
                              : RtcLight.mutedForeground),
                    ),
            ),
          ),
      ],
    );
  }
}

/// `sizes` de la web: sm = h-4, md = h-5, lg = h-7.
enum StarSize {
  sm(16),
  md(20),
  lg(28),

  /// La de las resenas, que van a `h-3.5`.
  review(14);

  const StarSize(this.px);

  final double px;
}
