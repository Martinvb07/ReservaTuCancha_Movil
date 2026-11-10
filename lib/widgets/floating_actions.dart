import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/motion.dart';
import '../theme/palette.dart';
import '../theme/shadows.dart';
import '../theme/tokens.dart';
import 'support_chat.dart';
import 'motion/rtc_pressable.dart';

/// Port de `Frontend/src/components/layout/FloatingActions.tsx`.
///
/// Los dos flotantes y el panel del asistente. Van en el layout, no en cada
/// pantalla, igual que en la web — y por eso el chat sobrevive a la
/// navegacion: si la conversacion se remontara al cambiar de pagina se
/// perderia a mitad de camino.
///
/// En `/auth` no se montan: esas pantallas ocupan toda la ventana.
class FloatingActions extends StatefulWidget {
  const FloatingActions({
    super.key,
    this.extraAbajo = 0,
    this.botonesVisibles = true,
  });

  /// Lo que tienen que subir los botones para no quedar encima de la barra
  /// inferior de la app.
  final double extraAbajo;

  /// En la app el boton del asistente solo se muestran en Soporte:
  /// en el resto tapaban el contenido. El chat sigue montado igual, para que
  /// Soporte lo pueda abrir y no se pierda la conversacion.
  final bool botonesVisibles;

  /// El `ABRIR_SOPORTE` de la web. La pantalla /soporte no monta su propio
  /// chat: pide abrir este. Se incrementa para que cada pedido se note aunque
  /// el valor anterior fuera el mismo.
  static final abrirSoporte = ValueNotifier<int>(0);

  /// Los flotantes viven en el `MaterialApp.builder`, ENCIMA del Navigator,
  /// asi que se pintan sobre cualquier hoja modal y le tapan los botones. En
  /// la web no pasa porque la hoja va en `z-[100]` y estos en `z-50`. Aca se
  /// consigue lo mismo escondiendolos mientras haya una hoja abierta.
  static final hojaAbierta = ValueNotifier<bool>(false);

  /// Si el chat del asistente esta abierto: la barra inferior de la app se
  /// esconde mientras tanto para no taparle el campo de texto.
  static final chatAbierto = ValueNotifier<bool>(false);

  @override
  State<FloatingActions> createState() => _FloatingActionsState();
}

/// El texto que se expande al pasar el mouse es `@media (hover: hover)`: en un
/// telefono no existe, asi que los dos flotantes son circulos de 56.
const _tamano = 56.0;

const kCorreoSoporte =
    'mailto:soporte@reservatucancha.site?subject=Necesito%20ayuda%20con%20ReservaTuCancha';

class _FloatingActionsState extends State<FloatingActions> {
  bool _chatAbiertoValor = false;

  bool get _chatAbierto => _chatAbiertoValor;
  set _chatAbierto(bool v) {
    _chatAbiertoValor = v;
    FloatingActions.chatAbierto.value = v;
  }

  @override
  void initState() {
    super.initState();
    FloatingActions.abrirSoporte.addListener(_abrir);
  }

  @override
  void dispose() {
    FloatingActions.abrirSoporte.removeListener(_abrir);
    super.dispose();
  }

  void _abrir() {
    if (mounted) setState(() => _chatAbierto = true);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: FloatingActions.hojaAbierta,
      // `Offstage` y no un `if`: el panel del asistente tiene que seguir
      // montado o se pierde la conversacion. `IgnorePointer` ademas, para que
      // los toques del boton de Buscar no caigan en un flotante invisible.
      builder: (context, hoja, hijo) => Offstage(
        offstage: hoja,
        child: IgnorePointer(ignoring: hoja, child: hijo),
      ),
      child: _botones(context),
    );
  }

  Widget _botones(BuildContext context) {
    final abajo = MediaQuery.paddingOf(context).bottom + widget.extraAbajo;
    return Stack(
      children: [
        Positioned(
          right: RtcSpace.s6,
          bottom: RtcSpace.s6 + abajo, // bottom-6
          child: _Fab(
            oculto: _chatAbierto || !widget.botonesVisibles,
            background: GrisFijo.c900,
            foreground: Lime.c400,
            icon: LucideIcons.bot,
            onTap: () => setState(() => _chatAbierto = true),
          ),
        ),
        SupportChat(
          open: _chatAbierto,
          onOpenChange: (v) => setState(() => _chatAbierto = v),
        ),
      ],
    );
  }
}

/// `.fab-float`: al esconderse baja 18px y se encoge a .85 en 300ms, con la
/// opacidad saliendo en 220ms.
class _Fab extends StatelessWidget {
  const _Fab({
    required this.oculto,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.onTap,
  });

  final bool oculto;
  final Color background;
  final Color foreground;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: oculto,
      child: AnimatedOpacity(
        opacity: oculto ? 0 : 1,
        duration: const Duration(milliseconds: 220),
        child: AnimatedScale(
          scale: oculto ? 0.5 : 1,
          duration: const Duration(milliseconds: 300),
          curve: RtcCurves.expoOut,
          child: RtcPressable(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              width: _tamano,
              height: _tamano,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
                boxShadow: RtcShadows.sheetCard,
              ),
              child: Icon(icon, size: 28, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}
