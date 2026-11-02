import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/geo.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'tile_attribution.dart';
import 'motion/rtc_pressable.dart';

/// Port de `Frontend/src/components/map/CourtLocationMap.tsx`.
///
/// Un solo pin, el de la cancha. Si no hay coordenadas cae al centro de la
/// ciudad desplazado por el id y lo avisa; si tampoco hay ciudad, muestra el
/// aviso gris y ni dibuja el mapa.
class CourtLocationMap extends StatelessWidget {
  const CourtLocationMap({
    super.key,
    required this.coordinates,
    required this.city,
    required this.address,
    required this.seed,
    required this.name,
  });

  /// Como las guarda Mongo: `[lng, lat]`.
  final List<double>? coordinates;
  final String city;
  final String address;

  /// El id de la cancha: mantiene estable la ubicacion aproximada por ciudad.
  final String seed;
  final String name;

  /// El pin de gota que dibuja la web a mano, con el verde de marca.
  static const _pin =
      '<svg width="34" height="46" viewBox="0 0 34 46" fill="none" '
      'xmlns="http://www.w3.org/2000/svg">'
      '<path d="M17 45s15-16.2 15-27.2C32 8.9 25.3 2 17 2S2 8.9 2 17.8C2 28.8 '
      '17 45 17 45z" fill="#16a34a" stroke="#fff" stroke-width="3"/>'
      '<circle cx="17" cy="17.5" r="5.5" fill="#fff"/></svg>';

  @override
  Widget build(BuildContext context) {
    final at = locationPoint(coordinates, city, seed);

    if (at == null) return _sinUbicacion();

    final label = [address, city].where((s) => s.isNotEmpty).join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // En movil el boton baja a su propia linea (`flex-col sm:flex-row`).
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(LucideIcons.mapPin, size: 16, color: Green.c600),
            ),
            const SizedBox(width: RtcSpace.s2),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.isEmpty ? 'Colombia' : label,
                    style: RtcType.sm.copyWith(color: Gray.c600),
                  ),
                  if (at.approx) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Ubicación aproximada: el club aún no marcó el punto exacto.',
                      // text-amber-600
                      style: RtcType.xs.copyWith(color: Amber.c600),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10), // gap-2.5
        _comoLlegar(at.point.latitude, at.point.longitude),
        const SizedBox(height: RtcSpace.s3),
        ClipRRect(
          borderRadius: RtcRadius.brXxl,
          child: Container(
            // h-60 en movil
            height: 240,
            decoration: BoxDecoration(
              color: Gray.c100,
              border: Border.all(color: Gray.c200),
              borderRadius: RtcRadius.brXxl,
            ),
            child: FlutterMap(
              options: MapOptions(
                initialCenter: at.point,
                // La web se acerca menos cuando el punto es aproximado.
                initialZoom: at.approx ? 13 : 16,
                maxZoom: tileMaxZoom,
                // Igual que en la web tactil: arrastrar con un dedo se comeria
                // el scroll de la pagina, asi que solo queda el zoom de dos
                // dedos y el boton "Cómo llegar".
                interactionOptions: const InteractionOptions(
                  flags:
                      InteractiveFlag.pinchZoom | InteractiveFlag.doubleTapZoom,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: tileUrl,
                  userAgentPackageName: 'site.reservatucancha',
                  maxZoom: tileMaxZoom,
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: at.point,
                      width: 34,
                      height: 46,
                      // `iconAnchor: [17, 45]`: la punta de la gota en el punto.
                      alignment: Alignment.topCenter,
                      child: SvgPicture.string(_pin, width: 34, height: 46),
                    ),
                  ],
                ),
                const TileAttribution(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// El aviso de cuando no hay ni coordenadas ni ciudad reconocida.
  Widget _sinUbicacion() {
    return Container(
      padding: const EdgeInsets.all(RtcSpace.s4),
      decoration: BoxDecoration(
        color: Gray.c50,
        borderRadius: RtcRadius.brXxl,
        border: Border.all(color: Gray.c100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.mapPin, size: 16, color: Gray.c500),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text:
                        'Esta cancha aún no tiene ubicación registrada en el mapa.',
                  ),
                  if (address.isNotEmpty) ...[
                    const TextSpan(text: ' Dirección: '),
                    TextSpan(
                      text: address,
                      style: RtcType.sm.copyWith(
                        color: Gray.c700,
                        fontWeight: RtcType.medium,
                      ),
                    ),
                    const TextSpan(text: '.'),
                  ],
                ],
              ),
              style: RtcType.sm.copyWith(color: Gray.c500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _comoLlegar(double lat, double lng) {
    return RtcPressable(
      behavior: HitTestBehavior.opaque,
      onTap: () => launchUrl(
        Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
        ),
        mode: LaunchMode.externalApplication,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: RtcSpace.s4,
          vertical: 10, // py-2.5
        ),
        decoration: BoxDecoration(
          borderRadius: RtcRadius.brXl,
          border: Border.all(color: Gray.c200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.navigation, size: 16, color: Gray.c700),
            const SizedBox(width: RtcSpace.s2),
            Text(
              'Cómo llegar',
              style: RtcType.sm.copyWith(
                fontWeight: RtcType.semibold,
                color: Gray.c700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
