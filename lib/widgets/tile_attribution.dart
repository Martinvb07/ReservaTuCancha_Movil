import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// El control de atribucion de Leaflet (`.leaflet-control-attribution`): una
/// cajita blanca al 80% abajo a la derecha con "© OpenStreetMap".
///
/// En la web sale sola porque Leaflet la pone por defecto. Aca va a mano, y no
/// es adorno: la politica de uso de las tiles de OSM exige atribucion visible.
/// Se deja fuera el prefijo "Leaflet" de la web porque la app no usa Leaflet.
///
/// Va como ULTIMO hijo de `FlutterMap`, para quedar encima de las capas.
class TileAttribution extends StatelessWidget {
  const TileAttribution({super.key});

  static final _copyright = Uri.parse(
    'https://www.openstreetmap.org/copyright',
  );

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () =>
            launchUrl(_copyright, mode: LaunchMode.externalApplication),
        child: Container(
          // `background: rgba(255,255,255,.8)` y `padding: 0 5px`.
          color: const Color(0xCCFFFFFF),
          padding: const EdgeInsets.symmetric(horizontal: 5),
          child: const Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '© '),
                // El color de los enlaces de Leaflet.
                TextSpan(
                  text: 'OpenStreetMap',
                  style: TextStyle(color: Color(0xFF0078A8)),
                ),
              ],
            ),
            // 12px, `line-height: 1.4` y `#333`. La fuente de `.leaflet-
            // container` es Helvetica/Arial: se usa la del sistema, no Geist.
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: 12,
              height: 1.4,
              color: Color(0xFF333333),
            ),
          ),
        ),
      ),
    );
  }
}
