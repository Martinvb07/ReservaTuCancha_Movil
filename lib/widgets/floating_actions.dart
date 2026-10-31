import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/motion.dart';
import '../theme/palette.dart';
import '../theme/shadows.dart';
import '../theme/tokens.dart';
import 'support_chat.dart';

/// Port de `Frontend/src/components/layout/FloatingActions.tsx`.
///
/// Los dos flotantes y el panel del asistente. Van en el layout, no en cada
/// pantalla, igual que en la web — y por eso el chat sobrevive a la
/// navegacion: si la conversacion se remontara al cambiar de pagina se
/// perderia a mitad de camino.
///
/// En `/auth` no se montan: esas pantallas ocupan toda la ventana.
class FloatingActions extends StatefulWidget {
  const FloatingActions({super.key});

  /// El `ABRIR_SOPORTE` de la web. La pantalla /soporte no monta su propio
  /// chat: pide abrir este. Se incrementa para que cada pedido se note aunque
  /// el valor anterior fuera el mismo.
  static final abrirSoporte = ValueNotifier<int>(0);

  /// Los flotantes viven en el `MaterialApp.builder`, ENCIMA del Navigator,
  /// asi que se pintan sobre cualquier hoja modal y le tapan los botones. En
  /// la web no pasa porque la hoja va en `z-[100]` y estos en `z-50`. Aca se
  /// consigue lo mismo escondiendolos mientras haya una hoja abierta.
  static final hojaAbierta = ValueNotifier<bool>(false);

  @override
  State<FloatingActions> createState() => _FloatingActionsState();
}

/// El texto que se expande al pasar el mouse es `@media (hover: hover)`: en un
/// telefono no existe, asi que los dos flotantes son circulos de 56.
const _tamano = 56.0;

const _whatsapp =
    'https://wa.me/573124352786?text=Hola%2C%20necesito%20ayuda%20con%20ReservaTuCancha';

class _FloatingActionsState extends State<FloatingActions> {
  bool _chatAbierto = false;

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
    final abajo = MediaQuery.paddingOf(context).bottom;
    return Stack(
      children: [
        // Con el chat abierto el FAB de WhatsApp queda debajo del panel: se
        // desvanece en vez de desmontarse, que se ve como un parpadeo.
        Positioned(
          right: RtcSpace.s6,
          bottom: RtcSpace.s6 + abajo,
          child: _Fab(
            oculto: _chatAbierto,
            background: const Color(0xFF22C55E), // green-500
            foreground: Colors.white,
            icon: LucideIcons.messageCircle,
            onTap: () => launchUrl(
              Uri.parse(_whatsapp),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ),
        Positioned(
          right: RtcSpace.s6,
          bottom: RtcSpace.s6 + _tamano + RtcSpace.s4 + abajo, // bottom-24
          child: _Fab(
            oculto: _chatAbierto,
            background: Gray.c900,
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
          child: GestureDetector(
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
