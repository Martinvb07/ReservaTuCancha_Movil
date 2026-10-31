/// Port de `Frontend/src/components/ui/SportIcons.tsx`.
///
/// Son SVG propios (lucide no trae balones), asi que se copian los mismos
/// `path` tal cual y se dibujan con flutter_svg. El `currentColor` del web
/// se resuelve interpolando el color en el string.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Atributos comunes del SVG original: trazo de 1.75 y puntas redondeadas.
String _svg(String color, String body) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
    'stroke="$color" stroke-width="1.75" stroke-linecap="round" '
    'stroke-linejoin="round">$body</svg>';

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Balon de futbol: pentagono central y costuras hacia el borde.
String _futbol(String c) => _svg(c, '''
<circle cx="12" cy="12" r="9.5" />
<path d="M12 7.2 15.7 9.9 14.3 14.2H9.7L8.3 9.9 12 7.2Z" />
<path d="M12 2.5v4.7" />
<path d="m15.7 9.9 4.4-1.5" />
<path d="m14.3 14.2 2.7 3.9" />
<path d="m9.7 14.2-2.7 3.9" />
<path d="M8.3 9.9 3.9 8.4" />
''');

/// Pala de padel con puño y perforaciones.
String _padel(String c) => _svg(c, '''
<path d="M12 2.5c4.1 0 7.4 3.2 7.4 7.2s-3.3 7.2-7.4 7.2-7.4-3.2-7.4-7.2S7.9 2.5 12 2.5Z" />
<path d="M12 16.9v3.4" />
<path d="M10.4 20.8h3.2" />
<circle cx="9.8" cy="8" r=".85" fill="$c" stroke="none" />
<circle cx="14.2" cy="8" r=".85" fill="$c" stroke="none" />
<circle cx="12" cy="11.4" r=".85" fill="$c" stroke="none" />
''');

/// Balon de voley con sus costuras curvas.
String _voley(String c) => _svg(c, '''
<circle cx="12" cy="12" r="9.5" />
<path d="M12 2.5a13 13 0 0 0 0 9.5 12.6 12.6 0 0 0 8.6 5" />
<path d="M12 12a12.6 12.6 0 0 1-8.7 5" />
<path d="M16.8 13.6a16.5 16.5 0 0 1-9 7.4" />
<path d="M6.5 3.9a16.5 16.5 0 0 0 1.8 11.4" />
<path d="M11.2 7.1a16.5 16.5 0 0 1 10.8 4" />
''');

/// Icono del deporte. Tolera claves sueltas ("voley_playa", "futbol_5"...),
/// igual que `getSportIcon` en la web.
class SportIcon extends StatelessWidget {
  const SportIcon({super.key, required this.sport, this.size = 24, this.color});

  final String? sport;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? DefaultTextStyle.of(context).style.color ?? Colors.black;
    final key = sport ?? '';

    String? svg;
    if (key.contains('futbol')) {
      svg = _futbol(_hex(c));
    } else if (key.contains('padel')) {
      svg = _padel(_hex(c));
    } else if (key.contains('voley')) {
      svg = _voley(_hex(c));
    }

    // Deporte desconocido: el mismo Trophy de lucide que usa la web.
    if (svg == null) {
      return Icon(LucideIcons.trophy, size: size, color: c);
    }

    return SvgPicture.string(svg, width: size, height: size);
  }
}
