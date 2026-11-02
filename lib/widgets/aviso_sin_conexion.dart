import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/rtc_api.dart';
import '../data/cache_offline.dart';
import '../app/routes.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'motion/rtc_pressable.dart';

/// Pildora arriba de la pantalla cuando no hay internet. "Reintentar" vuelve
/// a abrir la pantalla actual, que repite sus peticiones.
class AvisoSinConexion extends StatelessWidget {
  const AvisoSinConexion({super.key});

  void _reintentar() {
    final nav = rtcNavigatorKey.currentState;
    if (nav == null) return;
    String? actual;
    nav.popUntil((r) {
      actual = r.settings.name;
      return true;
    });
    if (actual != null) nav.pushReplacementNamed(actual!);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: rtcSinConexion,
      builder: (context, sinConexion, _) => IgnorePointer(
        ignoring: !sinConexion,
        child: AnimatedSlide(
          offset: sinConexion ? Offset.zero : const Offset(0, -2),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Material(
                color: GrisFijo.c900,
                borderRadius: RtcRadius.brFull,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.wifiOff,
                        size: 16,
                        color: Lime.c400,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ValueListenableBuilder<bool>(
                          valueListenable: rtcMostrandoGuardado,
                          builder: (context, guardado, _) => Text(
                            guardado
                                ? 'Sin internet · viendo lo último guardado'
                                : 'Sin conexión a internet',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RtcType.sm.copyWith(
                              color: Colors.white,
                              fontWeight: RtcType.semibold,
                            ),
                          ),
                        ),
                      ),
                      RtcPressable(
                        onTap: _reintentar,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: const BoxDecoration(
                            color: Lime.c400,
                            borderRadius: RtcRadius.brFull,
                          ),
                          child: Text(
                            'Reintentar',
                            style: RtcType.xs.copyWith(
                              fontWeight: RtcType.bold,
                              color: GrisFijo.c900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
