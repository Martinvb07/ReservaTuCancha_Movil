import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/version_app.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'motion/rtc_pressable.dart';

/// Si hay una version nueva: obligatoria tapa la app con un unico boton a la
/// tienda; sugerida es una tarjeta abajo que se puede cerrar.
class AvisoActualizacion extends StatefulWidget {
  const AvisoActualizacion({super.key});

  @override
  State<AvisoActualizacion> createState() => _AvisoActualizacionState();
}

class _AvisoActualizacionState extends State<AvisoActualizacion> {
  InfoVersion? _info;
  bool _cerrado = false;

  @override
  void initState() {
    super.initState();
    consultarVersion().then((i) {
      if (mounted) setState(() => _info = i);
    });
  }

  void _abrirTienda() {
    final url = _info?.tienda ?? '';
    if (url.isEmpty) return;
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final info = _info;
    if (info == null || info.estado == EstadoVersion.alDia || _cerrado) {
      return const SizedBox.shrink();
    }
    final obligatoria = info.estado == EstadoVersion.obligatoria;

    final tarjeta = Material(
      color: Superficie.tarjeta,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Lime.c400,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.download,
                size: 24,
                color: GrisFijo.c900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              obligatoria ? 'Actualiza la app' : 'Hay una versión nueva',
              style: RtcType.lg.copyWith(
                fontWeight: FontWeight.w800,
                color: GrisFijo.c900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              obligatoria
                  ? 'Esta versión ya no es compatible. Actualízala para seguir '
                        'reservando.'
                  : 'Trae mejoras y correcciones. Tarda menos de un minuto.',
              textAlign: TextAlign.center,
              style: RtcType.sm.copyWith(color: GrisFijo.c500),
            ),
            const SizedBox(height: 16),
            RtcPressable(
              onTap: _abrirTienda,
              child: Container(
                height: 50,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Green.c600,
                  borderRadius: RtcRadius.brFull,
                ),
                child: Text(
                  'Actualizar',
                  style: RtcType.base.copyWith(
                    fontWeight: RtcType.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            if (!obligatoria)
              TextButton(
                onPressed: () => setState(() => _cerrado = true),
                child: Text(
                  'Ahora no',
                  style: RtcType.sm.copyWith(color: GrisFijo.c500),
                ),
              ),
          ],
        ),
      ),
    );

    if (obligatoria) {
      return ColoredBox(
        color: Colors.black.withValues(alpha: 0.6),
        child: Center(
          child: Padding(padding: const EdgeInsets.all(24), child: tarjeta),
        ),
      );
    }
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        child: Padding(padding: const EdgeInsets.all(16), child: tarjeta),
      ),
    );
  }
}
