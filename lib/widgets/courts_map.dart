import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/court.dart';
import '../models/geo.dart';
import '../theme/motion.dart';
import '../theme/palette.dart';
import '../theme/shadows.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'icons/sport_icon.dart';
import 'remote_image.dart';
import 'tile_attribution.dart';
import 'motion/rtc_pressable.dart';

/// Port de `Frontend/src/components/map/CourtsMap.tsx`.
///
/// Mismas tiles de OpenStreetMap que Leaflet en la web, y los pines son la
/// pildora de precio de `.rtc-pin`: blanca en reposo, negra al elegirse.
class CourtsMap extends StatefulWidget {
  const CourtsMap({
    super.key,
    required this.courts,
    this.onOpenCourt,
    this.onSelect,
  });

  final List<Court> courts;
  final ValueChanged<Court>? onOpenCourt;

  /// Al tocar un pin: la pantalla acomoda el scroll para que la ficha que
  /// aparece abajo no quede debajo de la barra de navegación.
  final VoidCallback? onSelect;

  @override
  State<CourtsMap> createState() => _CourtsMapState();
}

class _CourtsMapState extends State<CourtsMap> {
  CourtPoint? _selected;

  @override
  Widget build(BuildContext context) {
    final points = courtPoints(widget.courts);
    // Cuantas canchas no se pudieron ubicar, igual que `hidden` en la web.
    final hidden = widget.courts.length - points.length;

    return ClipRRect(
      borderRadius: RtcRadius.brXxl,
      child: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: points.isEmpty ? colombiaCenter : _center(points),
              initialZoom: points.isEmpty ? 6 : 11,
              maxZoom: tileMaxZoom,
              onTap: (_, _) => setState(() => _selected = null),
            ),
            children: [
              TileLayer(
                urlTemplate: tileUrl,
                userAgentPackageName: 'site.reservatucancha',
                maxZoom: tileMaxZoom,
                // `background: #eef1f5` de `.leaflet-container`.
                tileBuilder: (context, tile, _) => tile,
              ),
              MarkerLayer(
                markers: [
                  for (final p in points)
                    Marker(
                      point: p.position,
                      width: 96,
                      height: 34,
                      alignment: Alignment.center,
                      child: _PricePin(
                        label: shortPrice(p.court.pricePerHour),
                        active: _selected?.court.id == p.court.id,
                        onTap: () {
                          setState(() => _selected = p);
                          widget.onSelect?.call();
                        },
                      ),
                    ),
                ],
              ),
              const TileAttribution(),
            ],
          ),

          // Vista previa de la cancha — el popup de Leaflet, aca como
          // tarjeta abajo. Entra subiendo y se cambia con un fundido al
          // tocar otro pin.
          Positioned(
            left: RtcSpace.s3,
            right: RtcSpace.s3,
            // Encima del crédito de OpenStreetMap, que tiene que verse.
            bottom: 26,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (hijo, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.25),
                    end: Offset.zero,
                  ).animate(anim),
                  child: hijo,
                ),
              ),
              child: _selected == null
                  ? const SizedBox.shrink()
                  : _CourtPopup(
                      key: ValueKey(_selected!.court.id),
                      court: _selected!.court,
                      onTap: () => widget.onOpenCourt?.call(_selected!.court),
                      onClose: () => setState(() => _selected = null),
                    ),
            ),
          ),

          if (hidden > 0)
            Positioned(
              left: RtcSpace.s3,
              top: RtcSpace.s3,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: RtcSpace.s3,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.95),
                  borderRadius: RtcRadius.brFull,
                  boxShadow: RtcShadows.mapPin,
                ),
                child: Text(
                  '$hidden sin ubicación',
                  style: RtcType.xs.copyWith(
                    fontWeight: RtcType.semibold,
                    color: GrisFijo.c700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  LatLng _center(List<CourtPoint> points) {
    var lat = 0.0, lng = 0.0;
    for (final p in points) {
      lat += p.position.latitude;
      lng += p.position.longitude;
    }
    return LatLng(lat / points.length, lng / points.length);
  }
}

/// `.rtc-pin` — pildora de precio estilo Airbnb.
class _PricePin extends StatelessWidget {
  const _PricePin({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RtcPressable(
        onTap: onTap,
        child: AnimatedScale(
          // `.rtc-pin--active` escala a 1.09
          scale: active ? 1.09 : 1,
          duration: RtcDur.pinHover,
          curve: RtcCurves.smooth,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: active ? GrisFijo.c900 : Superficie.tarjeta,
              borderRadius: RtcRadius.brFull,
              border: Border.all(
                color: active
                    ? Gray.c900
                    : Colors.black.withValues(alpha: 0.08),
              ),
              boxShadow: RtcShadows.mapPin,
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                height: 1,
                fontWeight: RtcType.bold,
                leadingDistribution: TextLeadingDistribution.even,
                color: active ? Colors.white : Gray.c900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.rtc-map-popup` — la vista previa de la cancha sobre el mapa: foto con
/// la nota encima, deporte, ubicación, precio y una flecha que invita a
/// abrirla. Toda la tarjeta abre la ficha; la X la cierra.
class _CourtPopup extends StatelessWidget {
  const _CourtPopup({
    super.key,
    required this.court,
    required this.onTap,
    required this.onClose,
  });

  final Court court;
  final VoidCallback onTap;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final sport = getSport(court.sport);
    return RtcPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Superficie.tarjeta,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Gray.c100),
          boxShadow: RtcShadows.mapPopup,
        ),
        child: Row(
          children: [
            // ── Foto con la nota ─────────────────────────────────────
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 96,
                height: 96,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    RemoteImage(
                      url: court.photos.isNotEmpty
                          ? court.photos.first
                          : sport.image,
                      sport: court.sport,
                    ),
                    if (court.averageRating > 0)
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: GrisFijo.c900.withValues(alpha: 0.78),
                            borderRadius: RtcRadius.brFull,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.star,
                                size: 11,
                                color: Yellow.c400,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                court.averageRating.toStringAsFixed(1),
                                style: RtcType.xs.copyWith(
                                  fontSize: 11,
                                  height: 1.1,
                                  fontWeight: RtcType.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: RtcSpace.s3),

            // ── Datos ─────────────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Green.c50,
                          borderRadius: RtcRadius.brFull,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SportIcon(
                              sport: court.sport,
                              size: 12,
                              color: Green.c700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              sport.label,
                              style: RtcType.xs.copyWith(
                                fontSize: 11,
                                height: 1.1,
                                fontWeight: RtcType.bold,
                                color: Green.c700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      _Cerrar(onTap: onClose),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    court.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RtcType.base.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      color: Gray.c900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(LucideIcons.mapPin, size: 12, color: Gray.c500),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          court.locationLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RtcType.xs.copyWith(color: Gray.c500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: RtcSpace.s2),
                  Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '\$${formatCop(court.pricePerHour)}',
                                style: RtcType.base.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Green.c700,
                                ),
                              ),
                              TextSpan(
                                text: ' /hora',
                                style: RtcType.xs.copyWith(color: Gray.c500),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: Lime.c400,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          LucideIcons.arrowRight,
                          size: 17,
                          color: GrisFijo.c900,
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
    );
  }
}

/// La X chiquita para cerrar la vista previa sin tocar el mapa.
class _Cerrar extends StatelessWidget {
  const _Cerrar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Cerrar',
      child: RtcPressable(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: Fondo.suave, shape: BoxShape.circle),
          child: Icon(LucideIcons.x, size: 13, color: Gray.c600),
        ),
      ),
    );
  }
}
