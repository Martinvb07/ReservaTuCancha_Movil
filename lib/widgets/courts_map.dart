import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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

          // Ficha de la cancha — el popup de Leaflet, aca como tarjeta abajo.
          if (_selected != null)
            Positioned(
              left: RtcSpace.s4,
              right: RtcSpace.s4,
              bottom: RtcSpace.s4,
              child: _CourtPopup(
                court: _selected!.court,
                onTap: () => widget.onOpenCourt?.call(_selected!.court),
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
                    color: Gray.c700,
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

/// `.rtc-map-popup` — la ficha de la cancha sobre el mapa.
class _CourtPopup extends StatelessWidget {
  const _CourtPopup({required this.court, required this.onTap});

  final Court court;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final sport = getSport(court.sport);
    return RtcPressable(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Superficie.tarjeta,
          borderRadius: RtcRadius.brXxl,
          boxShadow: RtcShadows.mapPopup,
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          children: [
            SizedBox(
              width: 96,
              height: 96,
              child: RemoteImage(
                url: court.photos.isNotEmpty ? court.photos.first : sport.image,
                sport: court.sport,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(RtcSpace.s3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        SportIcon(
                          sport: court.sport,
                          size: 14,
                          color: Green.c600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          sport.label,
                          style: RtcType.xs.copyWith(
                            fontWeight: RtcType.semibold,
                            color: Gray.c500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      court.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RtcType.sm.copyWith(
                        fontWeight: RtcType.semibold,
                        color: Gray.c900,
                      ),
                    ),
                    Text(
                      court.locationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RtcType.xs.copyWith(color: Gray.c500),
                    ),
                    const SizedBox(height: RtcSpace.s2),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '\$${formatCop(court.pricePerHour)}',
                            style: RtcType.sm.copyWith(
                              fontWeight: RtcType.bold,
                              color: Gray.c900,
                            ),
                          ),
                          TextSpan(
                            text: ' / hora',
                            style: RtcType.xs.copyWith(color: Gray.c500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
