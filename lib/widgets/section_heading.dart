import 'package:flutter/material.dart';

import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// El encabezado que repiten todas las secciones de la home: el titulillo
/// verde lima con asterisco, el titulo en negro pesado y la bajada gris.
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.eyebrow,
    this.subtitle,
  });

  final String title;

  /// El `* Servicios` / `* FAQ` en lime-600.
  final String? eyebrow;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (eyebrow != null) ...[
          Row(
            children: [
              Text(
                '*',
                style: RtcType.xs.copyWith(
                  color: Lime.c500,
                  fontWeight: RtcType.semibold,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                eyebrow!,
                style: RtcType.xs.copyWith(
                  color: Lime.c600,
                  fontWeight: RtcType.semibold,
                ),
              ),
            ],
          ),
          const SizedBox(height: RtcSpace.s2),
        ],
        Text(
          title,
          style: RtcType.xl2.copyWith(
            fontWeight: FontWeight.w900, // font-black
            color: Gray.c900,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: RtcSpace.s2),
          Text(subtitle!, style: RtcType.sm.copyWith(color: Gray.c500)),
        ],
      ],
    );
  }
}

/// El `SectionHeading` de `/canchas/[id]`, que NO es el de la home: una barra
/// lima vertical (`w-1.5 h-5 rounded-full`) y el titulo a su lado en
/// `text-lg font-bold`.
class BarHeading extends StatelessWidget {
  const BarHeading({super.key, required this.title, this.trailing});

  final String title;

  /// El `(3)` gris que la pagina pone al lado de "Reseñas".
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6, // w-1.5
          height: 20, // h-5
          decoration: const BoxDecoration(
            color: Lime.c400,
            borderRadius: RtcRadius.brFull,
          ),
        ),
        const SizedBox(width: 10), // gap-2.5
        Text(
          title,
          style: RtcType.lg.copyWith(
            fontWeight: RtcType.bold,
            color: Gray.c900,
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 6),
          Text(trailing!, style: RtcType.base.copyWith(color: Gray.c500)),
        ],
      ],
    );
  }
}
