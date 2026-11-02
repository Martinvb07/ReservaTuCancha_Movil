import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/motion.dart';
import '../theme/palette.dart';
import '../theme/shadows.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'motion/rtc_pressable.dart';

/// Port de `Frontend/src/components/ui/SelectField.tsx`.
///
/// El disparador es igual al de la web: caja blanca, borde gris, chevron que
/// gira 180°. Lo que cambia es lo que se abre: en el sitio es un popover de
/// Radix pegado al campo, y en telefono eso es incomodo — aca se abre una hoja
/// desde abajo, que es lo que ya usa el buscador movil de la app.
class RtcSelectField extends StatelessWidget {
  const RtcSelectField({
    super.key,
    required this.value,
    required this.opciones,
    required this.onChange,
    this.placeholder = 'Selecciona…',
    this.acento = RtcSelectAcento.verde,
    this.compacto = false,
    this.titulo,
    this.deshabilitado = false,
  });

  final String? value;

  /// (valor, etiqueta)
  final List<(String, String)> opciones;

  final ValueChanged<String> onChange;
  final String placeholder;
  final RtcSelectAcento acento;

  /// `px-3 py-2 rounded-lg` del editor de disponibilidad.
  final bool compacto;

  /// Encabezado de la hoja. Sin el, se usa el placeholder.
  final String? titulo;

  /// `disabled:opacity-60 disabled:cursor-not-allowed`: no abre la hoja.
  final bool deshabilitado;

  String get _etiqueta {
    for (final (v, l) in opciones) {
      if (v == value) return l;
    }
    return placeholder;
  }

  @override
  Widget build(BuildContext context) {
    final vacio = _etiqueta == placeholder;
    return RtcPressable(
      behavior: HitTestBehavior.opaque,
      onTap: deshabilitado ? null : () => _abrir(context),
      child: Opacity(
        opacity: deshabilitado ? 0.6 : 1,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compacto ? RtcSpace.s3 : RtcSpace.s4,
            vertical: compacto ? RtcSpace.s2 : RtcSpace.s3,
          ),
          decoration: BoxDecoration(
            color: Superficie.tarjeta,
            borderRadius: compacto ? RtcRadius.brLg : RtcRadius.brXl,
            border: Border.all(color: Gray.c200),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RtcType.sm.copyWith(
                    color: vacio ? Gray.c400 : Gray.c900,
                  ),
                ),
              ),
              const SizedBox(width: RtcSpace.s2),
              Icon(LucideIcons.chevronDown, size: 16, color: Gray.c500),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrir(BuildContext context) async {
    final elegido = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.50),
      isScrollControlled: true,
      builder: (context) => _Hoja(
        titulo: titulo ?? placeholder,
        opciones: opciones,
        value: value,
        acento: acento,
      ),
    );
    if (elegido != null) onChange(elegido);
  }
}

/// El acento del componente de la web: verde en general, naranja en bloqueos.
enum RtcSelectAcento {
  verde,
  naranja; // orange-500 / orange-50

  /* Getters y no campos: los colores cambian con el modo claro/oscuro. */
  Color get color => this == verde ? Green.c600 : Orange.c500;
  Color get fondo => this == verde ? Green.c50 : Orange.c50;
}

class _Hoja extends StatelessWidget {
  const _Hoja({
    required this.titulo,
    required this.opciones,
    required this.value,
    required this.acento,
  });

  final String titulo;
  final List<(String, String)> opciones;
  final String? value;
  final RtcSelectAcento acento;

  @override
  Widget build(BuildContext context) {
    final alto = MediaQuery.sizeOf(context).height;
    return Container(
      constraints: BoxConstraints(maxHeight: alto * 0.70),
      decoration: BoxDecoration(
        color: Superficie.tarjeta,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // El tirador de las hojas del sitio.
            Padding(
              padding: const EdgeInsets.symmetric(vertical: RtcSpace.s3),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Gray.c200,
                  borderRadius: RtcRadius.brFull,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                RtcSpace.s5,
                0,
                RtcSpace.s5,
                RtcSpace.s3,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      titulo,
                      style: RtcType.base.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Gray.c900,
                      ),
                    ),
                  ),
                  RtcPressable(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: Icon(LucideIcons.x, size: 20, color: Gray.c500),
                  ),
                ],
              ),
            ),
            Container(height: 1, color: Gray.c100),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: RtcSpace.s2),
                itemCount: opciones.length,
                itemBuilder: (context, i) {
                  final (v, l) = opciones[i];
                  final elegida = v == value;
                  return RtcPressable(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(v),
                    child: Container(
                      color: elegida ? acento.fondo : null,
                      padding: const EdgeInsets.symmetric(
                        horizontal: RtcSpace.s5,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              l,
                              style: RtcType.sm.copyWith(
                                color: elegida ? acento.color : Gray.c700,
                                fontWeight: elegida
                                    ? RtcType.semibold
                                    : RtcType.medium,
                              ),
                            ),
                          ),
                          if (elegida)
                            Icon(
                              LucideIcons.check,
                              size: 16,
                              color: acento.color,
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Port de `Frontend/src/components/ui/SettingsTabs.tsx`, rama movil: la fila
/// deslizable de arriba (en escritorio es una columna, que aca no aplica).
///
/// La pildora verde no se dibuja por seccion: es UNA que se desliza de una a
/// otra — el `layoutId` de framer, con su resorte de stiffness 420 y damping 34.
class RtcSettingsTabs extends StatelessWidget {
  const RtcSettingsTabs({
    super.key,
    required this.secciones,
    required this.activa,
    required this.onChange,
    required this.child,
  });

  /// (id, titulo, pista, icono, tieneError)
  final List<(String, String, String, IconData, bool)> secciones;

  final String activa;
  final ValueChanged<String> onChange;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final actual = secciones.firstWhere(
      (s) => s.$1 == activa,
      orElse: () => secciones.first,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            itemCount: secciones.length,
            separatorBuilder: (_, _) => const SizedBox(width: RtcSpace.s2),
            itemBuilder: (context, i) {
              final (id, titulo, _, icono, alerta) = secciones[i];
              final activaEsta = id == actual.$1;
              return RtcPressable(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChange(id),
                child: AnimatedContainer(
                  duration: RtcDur.pick,
                  curve: RtcCurves.smooth,
                  padding: const EdgeInsets.symmetric(
                    horizontal: RtcSpace.s4,
                    vertical: RtcSpace.s3,
                  ),
                  decoration: BoxDecoration(
                    color: activaEsta ? Green.c600 : null,
                    borderRadius: RtcRadius.brXxl,
                    boxShadow: activaEsta
                        ? [
                            cssShadow(
                              dy: 10,
                              blur: 15,
                              spread: -3,
                              color: Green.c600.withValues(alpha: 0.20),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icono,
                        size: 16,
                        color: activaEsta ? Colors.white : Gray.c500,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        titulo,
                        style: RtcType.sm.copyWith(
                          fontWeight: RtcType.bold,
                          color: activaEsta ? Colors.white : Gray.c500,
                        ),
                      ),
                      if (alerta) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: activaEsta ? Superficie.tarjeta : Red.c500,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: RtcSpace.s5),
        // El panel entra desde 10px abajo cada vez que cambia la seccion.
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: RtcCurves.framerExpo,
          switchOutCurve: RtcCurves.framerExpo,
          transitionBuilder: (hijo, animacion) => FadeTransition(
            opacity: animacion,
            child: SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(animacion),
              child: hijo,
            ),
          ),
          child: Container(
            key: ValueKey(actual.$1),
            padding: const EdgeInsets.all(RtcSpace.s5),
            decoration: BoxDecoration(
              color: Superficie.tarjeta,
              borderRadius: RtcRadius.brXxl,
              border: Border.all(color: Gray.c100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actual.$2,
                  style: RtcType.lg.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Gray.c900,
                  ),
                ),
                if (actual.$3.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(actual.$3, style: RtcType.sm.copyWith(color: Gray.c500)),
                ],
                const SizedBox(height: RtcSpace.s4),
                Container(height: 1, color: Gray.c100),
                const SizedBox(height: RtcSpace.s5),
                child,
              ],
            ),
          ),
        ),
      ],
    );
  }
}
