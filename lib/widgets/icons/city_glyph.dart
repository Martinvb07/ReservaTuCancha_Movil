/// Port de `Frontend/src/components/ui/CityGlyph.tsx`.
///
/// Ilustraciones propias por ciudad, estilo landmark tipo Airbnb: una linea
/// del color de marca de la ciudad sobre un relleno tenue del mismo tono.
/// Los `path` son identicos a los del web; el viewBox es 48x48.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Normaliza igual que `cityKey`: minusculas y sin tildes.
String cityKey(String city) {
  const from = 'áàäâéèëêíìïîóòöôúùüûñç';
  const to = 'aaaaeeeeiiiioooouuuunc';
  final lower = city.toLowerCase();
  final buffer = StringBuffer();
  for (final ch in lower.split('')) {
    final i = from.indexOf(ch);
    buffer.write(i == -1 ? ch : to[i]);
  }
  return buffer.toString();
}

/// Cada entrada recibe el color de marca y devuelve el cuerpo del SVG.
final _glyphs = <String, String Function(String)>{
  // Villavicencio — cordillera, la puerta al llano
  'villavicencio': (c) =>
      '''
<path d="M6 34 18 16l7 10 5-7 10 15z" fill="$c" opacity=".2" />
<path d="M6 34 18 16l7 10 5-7 10 15" stroke="$c" stroke-width="2.4" stroke-linejoin="round" stroke-linecap="round" />
<path d="M15 20.5l3 2.6 2.4-1.8" stroke="$c" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" />
<path d="M6 34h34" stroke="$c" stroke-width="2.4" stroke-linecap="round" />
''',

  // Acacias — palma llanera y sol sobre el piedemonte
  'acacias': (c) =>
      '''
<circle cx="33" cy="15" r="5" fill="$c" opacity=".25" />
<path d="M20 40c0-9 1-16 2-22" stroke="$c" stroke-width="2.4" stroke-linecap="round" />
<path d="M22 17c-4-2-8-1-11 2m11-2c4-2 9-1 12 3m-12-3c-2-4-1-8 1-11m-1 11c3-3 7-4 11-3" stroke="$c" stroke-width="2.2" stroke-linecap="round" />
<path d="M8 40h32" stroke="$c" stroke-width="2.4" stroke-linecap="round" />
''',

  // Restrepo — casita del piedemonte con montaña detras
  'restrepo': (c) =>
      '''
<path d="M27 37 36 24l8 13z" fill="$c" opacity=".18" />
<path d="M27 37 36 24l8 13" stroke="$c" stroke-width="2.2" stroke-linejoin="round" stroke-linecap="round" />
<path d="M12 23v14h13V23" fill="$c" opacity=".18" />
<path d="M12 23v14h13V23" stroke="$c" stroke-width="2.4" stroke-linejoin="round" />
<path d="M9 24l9.5-8 9.5 8" stroke="$c" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" />
<path d="M16 37v-5a2.5 2.5 0 0 1 5 0v5" stroke="$c" stroke-width="2.2" stroke-linejoin="round" />
<path d="M5 37h38" stroke="$c" stroke-width="2.4" stroke-linecap="round" />
''',

  // Bogota — cerro de Monserrate y skyline
  'bogota': (c) =>
      '''
<path d="M4 38 15 21l7 11z" fill="$c" opacity=".2" />
<path d="M4 38 15 21l7 11" stroke="$c" stroke-width="2.4" stroke-linejoin="round" stroke-linecap="round" />
<path d="M15 21v-4m-2.5 1.5h5" stroke="$c" stroke-width="2" stroke-linecap="round" />
<path d="M26 38V19h8v19" fill="$c" opacity=".18" />
<path d="M26 38V19h8v19M37 38V26h7v12" stroke="$c" stroke-width="2.4" stroke-linejoin="round" />
<path d="M29.5 24h1.5m-1.5 5h1.5m-1.5 5h1.5" stroke="$c" stroke-width="2" stroke-linecap="round" />
<path d="M4 38h40" stroke="$c" stroke-width="2.4" stroke-linecap="round" />
''',

  // Medellin — flor de la Feria de las Flores
  'medellin': (c) =>
      '''
<circle cx="24" cy="10.5" r="4.5" fill="$c" opacity=".2" />
<circle cx="31.5" cy="15.5" r="4.5" fill="$c" opacity=".2" />
<circle cx="28.8" cy="24" r="4.5" fill="$c" opacity=".2" />
<circle cx="19.2" cy="24" r="4.5" fill="$c" opacity=".2" />
<circle cx="16.5" cy="15.5" r="4.5" fill="$c" opacity=".2" />
<circle cx="24" cy="17.5" r="4" stroke="$c" stroke-width="2.2" />
<path d="M24 25v13" stroke="$c" stroke-width="2.4" stroke-linecap="round" />
<path d="M24 32c-3-.5-5.5-2.5-6.5-5.5" stroke="$c" stroke-width="2.2" stroke-linecap="round" />
<path d="M14 38h20" stroke="$c" stroke-width="2.4" stroke-linecap="round" />
''',

  // Cali — sol del valle sobre las Tres Cruces
  'cali': (c) =>
      '''
<circle cx="31" cy="13" r="5" fill="$c" opacity=".25" />
<circle cx="31" cy="13" r="5" stroke="$c" stroke-width="2.2" />
<path d="M31 4v2.5M31 19.5V22m-9-9h2.5m13 0H40M24.5 6.5l1.8 1.8m11.4-1.8-1.8 1.8" stroke="$c" stroke-width="2" stroke-linecap="round" />
<path d="M4 37l11-13 8 9 6-6 15 10z" fill="$c" opacity=".18" />
<path d="M4 37l11-13 8 9 6-6 15 10" stroke="$c" stroke-width="2.4" stroke-linejoin="round" stroke-linecap="round" />
''',

  // Barranquilla — sol caribe sobre las olas
  'barranquilla': (c) =>
      '''
<path d="M15 24a9 9 0 0 1 18 0z" fill="$c" opacity=".25" />
<path d="M15 24a9 9 0 0 1 18 0" stroke="$c" stroke-width="2.2" stroke-linecap="round" />
<path d="M24 8v4M11 11l2.8 2.8M37 11l-2.8 2.8M7 20h4m26 0h4" stroke="$c" stroke-width="2" stroke-linecap="round" />
<path d="M6 31c2.5 0 2.5 2 5 2s2.5-2 5-2 2.5 2 5 2 2.5-2 5-2 2.5 2 5 2 2.5-2 5-2 2.5 2 5 2" stroke="$c" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" />
<path d="M6 38c2.5 0 2.5 2 5 2s2.5-2 5-2 2.5 2 5 2 2.5-2 5-2 2.5 2 5 2 2.5-2 5-2 2.5 2 5 2" stroke="$c" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" />
''',

  // Bucaramanga — arbol de la ciudad de los parques
  'bucaramanga': (c) =>
      '''
<circle cx="24" cy="17" r="10" fill="$c" opacity=".2" />
<circle cx="24" cy="17" r="10" stroke="$c" stroke-width="2.4" />
<path d="M24 38V22m0 5-4.5-4.5M24 24l4-4" stroke="$c" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" />
<path d="M12 38h24" stroke="$c" stroke-width="2.4" stroke-linecap="round" />
''',

  // Colombia — bandera ondeando. Usa los colores reales, ignora el de marca.
  'colombia': (_) => '''
<path d="M11 6v36" stroke="#a1887f" stroke-width="2.6" stroke-linecap="round" />
<path d="M14 9c9-3.5 17 3.5 26 0v11c-9 3.5-17-3.5-26 0z" fill="#FCD116" />
<path d="M14 20c9-3.5 17 3.5 26 0v5.5c-9 3.5-17-3.5-26 0z" fill="#003893" />
<path d="M14 25.5c9-3.5 17 3.5 26 0V31c-9 3.5-17-3.5-26 0z" fill="#CE1126" />
''',

  // Generico — pin de ubicacion
  'pin': (c) =>
      '''
<path d="M24 6c-7.2 0-13 5.6-13 12.6C11 28 24 42 24 42s13-14 13-23.4C37 11.6 31.2 6 24 6z" fill="$c" opacity=".18" />
<path d="M24 6c-7.2 0-13 5.6-13 12.6C11 28 24 42 24 42s13-14 13-23.4C37 11.6 31.2 6 24 6z" stroke="$c" stroke-width="2.4" stroke-linejoin="round" />
<circle cx="24" cy="18.5" r="4.5" stroke="$c" stroke-width="2.2" />
''',
};

/// Ilustracion de la ciudad. Si no tiene glifo propio, cae al pin.
class CityGlyph extends StatelessWidget {
  const CityGlyph({
    super.key,
    required this.city,
    required this.color,
    this.size = 26,
  });

  final String city;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final glyph = _glyphs[cityKey(city)] ?? _glyphs['pin']!;
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48" '
        'fill="none">${glyph(_hex(color))}</svg>';
    return SvgPicture.string(svg, width: size, height: size);
  }
}
