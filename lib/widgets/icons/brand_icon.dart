/// Los iconos de marca que `lucide-react` si trae y `lucide_icons_flutter` no.
///
/// La version 3 del paquete de Flutter ya no expone `Instagram` ni `Facebook`
/// (lucide los saco del set por marca registrada), pero la web los usa. Se
/// copian sus `path` tal cual del SVG original y se dibujan con flutter_svg,
/// igual que los balones de `sport_icon.dart`.
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Atributos por defecto de lucide: trazo de 2 y puntas redondeadas.
String _svg(String color, String body) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" '
    'stroke="$color" stroke-width="2" stroke-linecap="round" '
    'stroke-linejoin="round">$body</svg>';

String _hex(Color c) =>
    '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// `<Instagram />`.
String _instagram(String c) => _svg(c, '''
<rect width="20" height="20" x="2" y="2" rx="5" ry="5" />
<path d="M16 11.37A4 4 0 1 1 12.63 8 4 4 0 0 1 16 11.37z" />
<line x1="17.5" x2="17.51" y1="6.5" y2="6.5" />
''');

/// `<Facebook />`.
String _facebook(String c) => _svg(c, '''
<path d="M18 2h-3a5 5 0 0 0-5 5v3H7v4h3v8h4v-8h3l1-4h-4V7a1 1 0 0 1 1-1h3z" />
''');

enum RtcMarca { instagram, facebook }

class BrandIcon extends StatelessWidget {
  const BrandIcon({super.key, required this.marca, this.size = 16, this.color});

  final RtcMarca marca;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = _hex(
      color ?? DefaultTextStyle.of(context).style.color ?? Colors.black,
    );
    final svg = switch (marca) {
      RtcMarca.instagram => _instagram(c),
      RtcMarca.facebook => _facebook(c),
    };
    return SvgPicture.string(svg, width: size, height: size);
  }
}
