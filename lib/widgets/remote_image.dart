import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/court.dart' show placeholderFor;
import '../theme/palette.dart';

/// Foto remota con placeholder y fallback.
///
/// Las fotos del sitio viven en Cloudinary y Unsplash. Sin conexion (o con el
/// emulador sin red) `Image.network` pinta el icono roto de Flutter, que se ve
/// peor que un bloque de color. Esto siempre deja algo presentable.
class RemoteImage extends StatelessWidget {
  const RemoteImage({
    super.key,
    required this.url,
    this.sport,
    this.placeholderColor,
    this.fit = BoxFit.cover,
  });

  final String url;

  /// Cuando la foto es de una cancha, el hueco toma el color de su deporte en
  /// vez de un gris casi blanco, que parecia un bloque roto. Tiene prioridad
  /// sobre `placeholderColor`.
  final String? sport;

  /// Para las fotos que no son de una cancha (los heroes oscuros, el collage).
  final Color? placeholderColor;

  final BoxFit fit;

  Color get _color {
    final s = sport;
    if (s != null) return placeholderFor(s);
    return placeholderColor ?? Gray.c200;
  }

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _placeholder(),
      errorBuilder: (context, error, stack) => _placeholder(rota: true),
    );
  }

  Widget _placeholder({bool rota = false}) {
    final fondo = _color;
    return ColoredBox(
      color: fondo,
      child: rota
          ? Center(
              // Nada de Material Icons: es lucide, como el resto de la app.
              child: Icon(
                LucideIcons.image,
                // Sobre los heroes oscuros el icono tiene que aclarar, no
                // oscurecer.
                color:
                    ThemeData.estimateBrightnessForColor(fondo) ==
                        Brightness.dark
                    ? Colors.white.withValues(alpha: 0.35)
                    : Colors.black.withValues(alpha: 0.20),
                size: 28,
              ),
            )
          : const SizedBox.expand(),
    );
  }
}
