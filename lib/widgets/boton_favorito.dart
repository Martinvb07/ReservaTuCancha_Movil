import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/preferencias.dart';
import '../theme/shadows.dart';
import 'motion/rtc_pressable.dart';

/// El corazon de lucide, con relleno cuando la cancha es favorita. La fuente
/// de iconos de lucide solo trae contornos, asi que se dibuja el mismo trazo
/// en SVG para poder rellenarlo.
String _corazon(String trazo, String relleno) =>
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
    'fill="$relleno" stroke="$trazo" stroke-width="2" stroke-linecap="round" '
    'stroke-linejoin="round"><path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 '
    '0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 '
    '8.5c0 2.3 1.5 4.05 3 5.5l7 7Z"/></svg>';

/// Boton circular blanco que marca o desmarca una cancha como favorita.
/// Late al marcarla.
class BotonFavorito extends StatefulWidget {
  const BotonFavorito({super.key, required this.courtId, this.tamano = 44});

  final String courtId;
  final double tamano;

  @override
  State<BotonFavorito> createState() => _BotonFavoritoState();
}

class _BotonFavoritoState extends State<BotonFavorito>
    with SingleTickerProviderStateMixin {
  late final _latido = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );

  @override
  void dispose() {
    _latido.dispose();
    super.dispose();
  }

  void _alternar() {
    final antes = Preferencias.instance.esFavorita(widget.courtId);
    HapticFeedback.lightImpact();
    if (!antes) _latido.forward(from: 0);
    Preferencias.instance.alternarFavorita(widget.courtId);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Set<String>>(
      valueListenable: Preferencias.instance.favoritos,
      builder: (context, favs, _) {
        final activa = favs.contains(widget.courtId);
        return Semantics(
          button: true,
          toggled: activa,
          label: activa ? 'Quitar de favoritas' : 'Agregar a favoritas',
          child: RtcPressable(
            behavior: HitTestBehavior.opaque,
            onTap: _alternar,
            child: Container(
              width: widget.tamano,
              height: widget.tamano,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  cssShadow(
                    dy: 4,
                    blur: 12,
                    color: Colors.black.withValues(alpha: 0.12),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: ScaleTransition(
                scale:
                    TweenSequence([
                      TweenSequenceItem(
                        tween: Tween(begin: 1.0, end: 1.3),
                        weight: 1,
                      ),
                      TweenSequenceItem(
                        tween: Tween(begin: 1.3, end: 1.0),
                        weight: 1,
                      ),
                    ]).animate(
                      CurvedAnimation(parent: _latido, curve: Curves.easeOut),
                    ),
                child: SvgPicture.string(
                  activa
                      ? _corazon('#EF4444', '#EF4444')
                      : _corazon('#111827', 'none'),
                  width: widget.tamano * 0.45,
                  height: widget.tamano * 0.45,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
