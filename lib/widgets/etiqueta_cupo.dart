import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/bookings_api.dart';
import '../models/fechas.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// "4 libres hoy · desde 7:00 pm" o "Sin cupo hoy". Es lo que hace decidir
/// sin abrir la ficha.
class EtiquetaCupo extends StatelessWidget {
  const EtiquetaCupo({
    super.key,
    required this.disponibilidad,
    this.sobreFoto = false,
  });

  final Disponibilidad disponibilidad;

  /// Sobre la foto va en vidrio oscuro; sobre blanco, en verde claro.
  final bool sobreFoto;

  @override
  Widget build(BuildContext context) {
    final d = disponibilidad;
    final hay = d.libres > 0;
    final texto = hay
        ? '${d.libres} ${d.libres == 1 ? 'libre' : 'libres'} hoy'
              '${d.proximo == null ? '' : ' · desde ${hora12(d.proximo!)}'}'
        : 'Sin cupo hoy';

    final fondo = sobreFoto
        ? Colors.black.withValues(alpha: 0.45)
        : hay
        ? Green.c50
        : Fondo.app;
    final color = sobreFoto
        ? (hay ? Lime.c400 : Colors.white70)
        : hay
        ? Green.c700
        : Gray.c500;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: fondo, borderRadius: RtcRadius.brFull),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            hay ? LucideIcons.clock : LucideIcons.calendarX,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            texto,
            style: RtcType.xs.copyWith(
              fontWeight: RtcType.semibold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
