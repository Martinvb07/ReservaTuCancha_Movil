import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Port de los avisos de `sonner` (`<Toaster richColors position="top-right" />`
/// en `app/layout.tsx`), que es lo que usa todo el panel para confirmar
/// acciones.
///
/// Los colores NO son inventados: son los de `richColors` de sonner, con sus
/// HSL convertidos. En telefono el aviso ocupa el ancho, porque a la derecha
/// no hay lugar para una columna.
enum RtcToastTipo {
  exito(
    fondo: Color(0xFFECFEF3), // hsl(143 85% 96%)
    borde: Color(0xFFD3FDE5), // hsl(145 92% 91%)
    texto: Color(0xFF008A2E), // hsl(140 100% 27%)
    icono: LucideIcons.circleCheck,
  ),
  error(
    fondo: Color(0xFFFFF0F0), // hsl(359 100% 97%)
    borde: Color(0xFFFFE0E1), // hsl(359 100% 94%)
    texto: Color(0xFFE50000), // hsl(360 100% 45%)
    icono: LucideIcons.octagonX,
  ),
  advertencia(
    fondo: Color(0xFFFFFCF0), // hsl(49 100% 97%)
    borde: Color(0xFFFDF5D3), // hsl(49 91% 91%)
    texto: Color(0xFFDC7609), // hsl(31 92% 45%)
    icono: LucideIcons.triangleAlert,
  );

  const RtcToastTipo({
    required this.fondo,
    required this.borde,
    required this.texto,
    required this.icono,
  });

  final Color fondo;
  final Color borde;
  final Color texto;
  final IconData icono;
}

/// Muestra un aviso. Se puede llamar desde cualquier parte con el context de
/// la pantalla.
///
/// `descripcion`, `icono` y `duracion` son las opciones de sonner que usan los
/// avisos del socket del panel: una segunda linea, un icono propio en vez del
/// del tipo, y cuanto dura.
void rtcToast(
  BuildContext context,
  String mensaje, {
  RtcToastTipo tipo = RtcToastTipo.exito,
  String? descripcion,
  IconData? icono,
  Color? colorIcono,
  Duration duracion = _duracion,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  rtcToastEn(
    overlay,
    mensaje,
    tipo: tipo,
    descripcion: descripcion,
    icono: icono,
    colorIcono: colorIcono,
    duracion: duracion,
  );
}

/// Igual que [rtcToast], sobre un overlay dado. Lo usa quien vive ENCIMA del
/// Navigator (el socket del panel) y por eso no tiene un overlay de ancestro.
void rtcToastEn(
  OverlayState overlay,
  String mensaje, {
  RtcToastTipo tipo = RtcToastTipo.exito,
  String? descripcion,
  IconData? icono,
  Color? colorIcono,
  Duration duracion = _duracion,
}) {
  late final OverlayEntry entrada;
  entrada = OverlayEntry(
    builder: (context) => _Aviso(
      mensaje: mensaje,
      tipo: tipo,
      descripcion: descripcion,
      icono: icono,
      colorIcono: colorIcono,
      duracion: duracion,
      alCerrar: () {
        if (entrada.mounted) entrada.remove();
      },
    ),
  );
  overlay.insert(entrada);
}

class _Aviso extends StatefulWidget {
  const _Aviso({
    required this.mensaje,
    required this.tipo,
    required this.alCerrar,
    required this.duracion,
    this.descripcion,
    this.icono,
    this.colorIcono,
  });

  final String mensaje;
  final RtcToastTipo tipo;
  final VoidCallback alCerrar;
  final Duration duracion;
  final String? descripcion;
  final IconData? icono;
  final Color? colorIcono;

  @override
  State<_Aviso> createState() => _AvisoState();
}

/// Lo que dura un toast de sonner por defecto.
const _duracion = Duration(seconds: 4);

class _AvisoState extends State<_Aviso> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  )..forward();

  Timer? _cierre;

  @override
  void initState() {
    super.initState();
    _cierre = Timer(widget.duracion, _salir);
  }

  Future<void> _salir() async {
    if (!mounted) return;
    await _c.reverse();
    widget.alCerrar();
  }

  @override
  void dispose() {
    _cierre?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.tipo;
    final arriba = MediaQuery.paddingOf(context).top;

    return Positioned(
      top: arriba + RtcSpace.s4,
      left: RtcSpace.s4,
      right: RtcSpace.s4,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final v = RtcCurves.expoOut.transform(_c.value);
          return Opacity(
            opacity: v,
            child: Transform.translate(
              offset: Offset(0, -16 * (1 - v)),
              child: child,
            ),
          );
        },
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: _salir,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: RtcSpace.s4,
                vertical: RtcSpace.s3,
              ),
              decoration: BoxDecoration(
                color: t.fondo,
                // --border-radius: var(--radius)
                borderRadius: RtcRadius.brLg,
                border: Border.all(color: t.borde),
              ),
              child: Row(
                children: [
                  // `[data-icon]` es una caja de 16px pegada a la izquierda.
                  // Un icono propio mas grande (los `h-5 w-5` de los avisos
                  // del socket) se sale de ella, igual que en sonner.
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: OverflowBox(
                      alignment: Alignment.centerLeft,
                      maxWidth: 20,
                      maxHeight: 20,
                      child: Icon(
                        widget.icono ?? t.icono,
                        size: widget.icono == null ? 16 : 20,
                        color: widget.colorIcono ?? t.texto,
                      ),
                    ),
                  ),
                  const SizedBox(width: RtcSpace.s3),
                  Expanded(
                    // `[data-content]`: columna con 2px entre titulo (500) y
                    // descripcion (400, `line-height: 1.4`).
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.mensaje,
                          style: RtcType.sm.copyWith(
                            color: t.texto,
                            fontWeight: RtcType.medium,
                          ),
                        ),
                        if (widget.descripcion != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.descripcion!,
                            style: RtcType.sm.copyWith(
                              color: t.texto,
                              fontWeight: FontWeight.w400,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
