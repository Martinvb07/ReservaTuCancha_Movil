import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/motion.dart';
import '../theme/palette.dart';
import '../theme/shadows.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'motion/rtc_pressable.dart';

/// Alto que ocupa la barra, para que las pantallas dejen ese espacio libre
/// al final de su scroll y el contenido no quede tapado.
const kBottomNavEspacio = 96.0;

/// Una pestaña de la barra.
class RtcTab {
  const RtcTab(this.ruta, this.etiqueta, this.icono);

  final String ruta;
  final String etiqueta;
  final IconData icono;
}

const rtcTabs = [
  RtcTab('/', 'Inicio', LucideIcons.house),
  RtcTab('/empresas', 'Canchas', LucideIcons.mapPin),
  RtcTab('/mis-reservas', 'Reservas', LucideIcons.calendarCheck),
  RtcTab('menu', 'Más', LucideIcons.layoutGrid),
];

/// Barra de navegacion flotante: una pildora de vidrio esmerilado, con la
/// pestaña activa en verde y su nombre; el resto son solo iconos.
class RtcBottomNav extends StatelessWidget {
  const RtcBottomNav({
    super.key,
    required this.activa,
    required this.onTap,
    this.conBuscador = false,
    this.onBuscar,
  });

  /// La ruta de la pestaña activa, o null si la pantalla no es de ninguna.
  final String? activa;
  final ValueChanged<RtcTab> onTap;

  /// Con el buscador de la pantalla ya fuera de vista, aparece la lupa en un
  /// circulo aparte, a la derecha de la barra.
  final bool conBuscador;
  final VoidCallback? onBuscar;

  @override
  Widget build(BuildContext context) {
    final abajo = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        RtcSpace.s6,
        0,
        RtcSpace.s6,
        abajo > 0 ? abajo : RtcSpace.s4,
      ),
      child: Row(
        children: [
          Expanded(child: _pildora()),
          _Lupa(visible: conBuscador, onTap: onBuscar),
        ],
      ),
    );
  }

  Widget _pildora() {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: RtcRadius.brFull,
        boxShadow: [
          cssShadow(
            dy: 12,
            blur: 32,
            color: Colors.black.withValues(alpha: 0.16),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: RtcRadius.brFull,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: GrisFijo.c900.withValues(alpha: 0.88),
              borderRadius: RtcRadius.brFull,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final tab in rtcTabs)
                  _Item(
                    tab: tab,
                    activa: tab.ruta == activa,
                    onTap: () => onTap(tab),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// El circulo de la lupa. Entra creciendo desde la derecha de la barra.
class _Lupa extends StatelessWidget {
  const _Lupa({required this.visible, required this.onTap});

  final bool visible;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      width: visible ? 70 : 0,
      // Alto fijo: la barra va en un Positioned sin tope, y sin esto el
      // OverflowBox pedia un alto infinito y la barra entera no se pintaba.
      height: 60,
      alignment: Alignment.centerRight,
      // Sin recorte: escondida ya es invisible y no recibe toques, y un
      // ClipRect le cortaba la sombra en un cuadrado.
      child: OverflowBox(
        alignment: Alignment.centerRight,
        minWidth: 60,
        maxWidth: 60,
        child: AnimatedScale(
          scale: visible ? 1 : 0.4,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutBack,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Semantics(
              button: true,
              label: 'Buscar canchas',
              child: RtcPressable(
                behavior: HitTestBehavior.opaque,
                onTap: visible
                    ? () {
                        HapticFeedback.selectionClick();
                        onTap?.call();
                      }
                    : null,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Green.c600,
                    shape: BoxShape.circle,
                    boxShadow: [
                      cssShadow(
                        dy: 12,
                        blur: 28,
                        color: Green.c600.withValues(alpha: 0.40),
                      ),
                    ],
                  ),
                  child: const Icon(
                    LucideIcons.search,
                    size: 22,
                    color: Colors.white,
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

class _Item extends StatelessWidget {
  const _Item({required this.tab, required this.activa, required this.onTap});

  final RtcTab tab;
  final bool activa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: activa,
      label: tab.etiqueta,
      child: RtcPressable(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: RtcDur.pick,
          curve: RtcCurves.smooth,
          height: 48,
          padding: EdgeInsets.symmetric(horizontal: activa ? 18 : 0),
          constraints: const BoxConstraints(minWidth: 48),
          decoration: BoxDecoration(
            color: activa ? Lime.c400 : Colors.white.withValues(alpha: 0.08),
            borderRadius: RtcRadius.brFull,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                tab.icono,
                size: 20,
                color: activa
                    ? Gray.c900
                    : Colors.white.withValues(alpha: 0.75),
              ),
              if (activa) ...[
                const SizedBox(width: RtcSpace.s2),
                Text(
                  tab.etiqueta,
                  style: RtcType.sm.copyWith(
                    fontWeight: RtcType.bold,
                    color: Gray.c900,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
