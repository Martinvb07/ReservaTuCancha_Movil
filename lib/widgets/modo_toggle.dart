import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/routes.dart';
import '../theme/palette.dart';
import '../theme/shadows.dart';
import 'motion/rtc_pressable.dart';

/// El cambio entre Reservar y Para clubes, en un boton circular.
///
/// En modo Reservar muestra una persona; en Para clubes, un establecimiento.
/// Al tocarlo el icono gira y cambia en el mismo boton, y recien despues se
/// navega: asi la transicion se ve aunque la pantalla de destino tenga su
/// propio boton.
class ModoToggle extends StatefulWidget {
  const ModoToggle({super.key, required this.clubes, this.sobreOscuro = false});

  /// true en Para clubes.
  final bool clubes;

  /// Encima de un fondo oscuro el boton va de vidrio en vez de blanco.
  final bool sobreOscuro;

  @override
  State<ModoToggle> createState() => _ModoToggleState();
}

class _ModoToggleState extends State<ModoToggle> {
  /// El modo que se ve: cambia apenas se toca, antes de navegar.
  late bool _clubes = widget.clubes;
  bool _cambiando = false;

  @override
  void didUpdateWidget(ModoToggle old) {
    super.didUpdateWidget(old);
    if (widget.clubes != old.clubes) _clubes = widget.clubes;
  }

  Future<void> _cambiar() async {
    if (_cambiando) return;
    HapticFeedback.lightImpact();
    setState(() {
      _cambiando = true;
      _clubes = !_clubes;
    });
    await Future<void>.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;
    rtcNavigate(_clubes ? '/para-clubes' : '/');
    _cambiando = false;
  }

  @override
  Widget build(BuildContext context) {
    final fondo = _clubes
        ? Lime.c400
        : widget.sobreOscuro
        ? Colors.white.withValues(alpha: 0.12)
        : Superficie.tarjeta;
    /* Sobre el lima el ícono va oscuro en los dos modos; sobre la tarjeta
       sigue al modo (Gray.c900 se aclara en oscuro). Antes el botón era
       blanco fijo y en modo oscuro el ícono quedaba blanco sobre blanco. */
    final colorIcono = _clubes
        ? GrisFijo.c900
        : widget.sobreOscuro
        ? Colors.white
        : Gray.c900;

    return Semantics(
      button: true,
      label: _clubes ? 'Cambiar a modo Reservar' : 'Cambiar a modo Para clubes',
      child: RtcPressable(
        behavior: HitTestBehavior.opaque,
        onTap: _cambiar,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: fondo,
            shape: BoxShape.circle,
            border: widget.sobreOscuro && !_clubes
                ? Border.all(color: Colors.white.withValues(alpha: 0.25))
                : null,
            boxShadow: widget.sobreOscuro
                ? null
                : [
                    cssShadow(
                      dy: 4,
                      blur: 14,
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                  ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 380),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (hijo, animacion) => RotationTransition(
              turns: Tween(begin: -0.25, end: 0.0).animate(animacion),
              child: ScaleTransition(
                scale: animacion,
                child: FadeTransition(opacity: animacion, child: hijo),
              ),
            ),
            child: Icon(
              _clubes ? LucideIcons.store : LucideIcons.user,
              key: ValueKey(_clubes),
              size: 20,
              color: colorIcono,
            ),
          ),
        ),
      ),
    );
  }
}
