import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/court.dart';
import 'icons/sport_icon.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'remote_image.dart';
import 'boton_favorito.dart';

/// Port de `Frontend/src/components/courts/CourtCard.tsx`.
///
/// El `:hover` de la web (elevar la tarjeta y agrandar la foto) no existe en
/// tactil, asi que va como estado PRESIONADO: la tarjeta se hunde apenas.
class CourtCard extends StatefulWidget {
  const CourtCard({super.key, required this.court, this.onTap});

  final Court court;
  final VoidCallback? onTap;

  @override
  State<CourtCard> createState() => _CourtCardState();
}

class _CourtCardState extends State<CourtCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final court = widget.court;
    final sport = getSport(court.sport);

    // Solo amenidades con icono, maximo 4 — igual que en la web.
    final known = court.amenities.where(amenityIcons.containsKey).toList();
    final shown = known.take(4).toList();
    final extra = known.length - shown.length;

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.985 : 1,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: Container(
          // Tarjeta blanca sobre el fondo gris de la app, sin borde ni
          // sombra; la foto va adentro con su propio redondeo.
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Foto con los dos badges ──────────────────────────────
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: AspectRatio(
                  aspectRatio: 16 / 11,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RemoteImage(
                        url: court.photos.isNotEmpty
                            ? court.photos.first
                            : sport.image,
                        sport: court.sport,
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: _Badge(
                          background: Colors.white.withValues(alpha: 0.95),
                          foreground: Gray.c800,
                          leading: SportIcon(
                            sport: court.sport,
                            size: 14,
                            color: Gray.c800,
                          ),
                          label: sport.label,
                        ),
                      ),
                      if (court.totalReviews > 0)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: _Badge(
                            background: Gray.c900.withValues(alpha: 0.80),
                            foreground: Colors.white,
                            // `fill-yellow-400` del web: una estrella RELLENA,
                            // y el icono de lucide es solo contorno.
                            leading: SvgPicture.string(
                              _filledStar,
                              width: 12,
                              height: 12,
                            ),
                            label: court.averageRating.toStringAsFixed(1),
                          ),
                        ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: BotonFavorito(courtId: court.id, tamano: 40),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Contenido ───────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  RtcSpace.s3,
                  RtcSpace.s4,
                  RtcSpace.s3,
                  RtcSpace.s2,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      court.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RtcType.lg.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Gray.c900,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: RtcSpace.s1),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.mapPin,
                          size: 14,
                          color: Gray.c400,
                        ),
                        const SizedBox(width: RtcSpace.s1),
                        Expanded(
                          child: Text(
                            court.locationLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RtcType.sm.copyWith(color: Gray.c500),
                          ),
                        ),
                      ],
                    ),

                    if (shown.isNotEmpty) ...[
                      const SizedBox(height: RtcSpace.s3),
                      Row(
                        children: [
                          for (final a in shown) ...[
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Fondo.app,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                amenityIcon(a),
                                size: 16,
                                color: Gray.c800,
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (extra > 0)
                            Text(
                              '+$extra',
                              style: RtcType.xs.copyWith(
                                fontWeight: RtcType.semibold,
                                color: Gray.c400,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: RtcSpace.s4),
                    ] else
                      const SizedBox(height: RtcSpace.s3),

                    // ── Precio + boton de reservar ──
                    Row(
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '\$${formatCop(court.pricePerHour)}',
                                style: RtcType.lg.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Gray.c900,
                                ),
                              ),
                              TextSpan(
                                text: ' /hora',
                                style: RtcType.xs.copyWith(color: Gray.c500),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: RtcSpace.s5,
                            vertical: 10,
                          ),
                          decoration: const BoxDecoration(
                            color: Green.c600,
                            borderRadius: RtcRadius.brFull,
                          ),
                          child: Text(
                            'Reservar',
                            style: RtcType.sm.copyWith(
                              fontWeight: RtcType.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Estrella rellena de lucide — el web la pinta con `fill-yellow-400`.
const _filledStar =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
    'fill="#FACC15" stroke="#FACC15" stroke-width="1.5" '
    'stroke-linejoin="round"><polygon points="12 2 15.09 8.26 22 9.27 '
    '17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 '
    '12 2"/></svg>';

class _Badge extends StatelessWidget {
  const _Badge({
    required this.background,
    required this.foreground,
    required this.leading,
    required this.label,
  });

  final Color background;
  final Color foreground;
  final Widget leading;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: RtcRadius.brFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 5),
          Text(
            label,
            style: RtcType.xs.copyWith(
              fontWeight: RtcType.semibold,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }
}
