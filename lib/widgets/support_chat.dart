import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/routes.dart';
import '../models/support_bot.dart';
import '../theme/motion.dart';
import '../theme/palette.dart';
import '../theme/shadows.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'motion/rtc_motion.dart';
import 'rtc_navbar.dart' show kNavHeight;
import 'motion/rtc_pressable.dart';

/// Port de `Frontend/src/components/layout/SupportChat.tsx`.
///
/// El arbol de la conversacion es el JSON de la web sin tocar. Lo que se porta
/// aca es el motor: la coreografia de cada turno, que es lo que hace que no
/// aparezca todo de golpe.
class SupportChat extends StatefulWidget {
  const SupportChat({
    super.key,
    required this.open,
    required this.onOpenChange,
  });

  final bool open;
  final ValueChanged<bool> onOpenChange;

  @override
  State<SupportChat> createState() => _SupportChatState();
}

const _whatsapp =
    'https://wa.me/573124352786?text=Hola%2C%20vengo%20del%20asistente%20de%20ReservaTuCancha%20y%20necesito%20ayuda';

/* Coreografia de un turno (ms). Cada paso encadena con el anterior para que
   nada aparezca ni desaparezca de golpe. */
const _cierrePanel = 220; // debe coincidir con RtcChatPanel al cerrar
const _salidaChips = 170; // debe coincidir con RtcChatChipOut
const _escritura = 620; // puntitos antes de la respuesta del bot
const _arranqueSaludo = 320; // aire entre el saludo y el primer menu

class _SupportChatState extends State<SupportChat> {
  SupportBotTree? _tree;

  bool _montado = false;
  bool _cerrando = false;

  List<SupportBotMensaje> _mensajes = const [];
  List<SupportBotOpcion> _opciones = const [];
  int _turno = 0;
  bool _chipsSaliendo = false;
  bool _escribiendo = false;

  /// Ultimo menu visitado: a el vuelve "Ver otro tema".
  String _menuActual = 'inicio';

  int _contador = 0;
  final _timers = <Timer>[];
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(SupportChat old) {
    super.didUpdateWidget(old);
    if (widget.open == old.open) return;
    if (widget.open) {
      setState(() {
        _montado = true;
        _cerrando = false;
      });
      if (_mensajes.isEmpty) _reiniciar();
      return;
    }
    // El panel sobrevive al cierre lo justo para que corra su salida.
    setState(() => _cerrando = true);
    _programar(() {
      if (mounted) setState(() => _montado = false);
    }, _cierrePanel);
  }

  @override
  void dispose() {
    _limpiarTimers();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final tree = await SupportBotTree.cargar();
    if (!mounted) return;
    setState(() {
      _tree = tree;
      _menuActual = tree.meta.nodoInicial;
    });
    if (widget.open) _reiniciar();
  }

  void _programar(VoidCallback fn, int ms) {
    _timers.add(Timer(Duration(milliseconds: ms), fn));
  }

  void _limpiarTimers() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
  }

  // ── MOTOR DEL ARBOL ──────────────────────────────────────────────────

  void _irANodo(String idNodo, {int retraso = 0}) {
    final tree = _tree;
    final nodo = tree?.nodos[idNodo];
    if (tree == null || nodo == null) return;

    /* La primera pantalla lista los temas y cada uno abre su propio menu. Al
       terminar una respuesta, "Ver otro tema" debe devolver a ese submenu y no
       al arranque, asi que se recuerda cual fue el ultimo menu. */
    if (idNodo.startsWith('menu-')) _menuActual = idNodo;

    _programar(() {
      if (!mounted) return;
      setState(() => _escribiendo = true);
      _programar(() {
        if (!mounted) return;
        setState(() {
          _escribiendo = false;
          _chipsSaliendo = false;
          _mensajes = [
            ..._mensajes,
            SupportBotMensaje(
              id: ++_contador,
              autor: 'bot',
              texto: nodo.mensaje,
            ),
          ];
          _opciones = nodo.esRespuesta
              ? [
                  ...nodo.opciones,
                  ...tree.meta.opcionesFinales.map(
                    (o) => o.destino == 'inicio'
                        ? o.copiarCon(destino: _menuActual)
                        : o,
                  ),
                ]
              : nodo.opciones;
          _turno++;
        });
        _alFinal();
      }, _escritura);
    }, retraso);
  }

  void _reiniciar() {
    final tree = _tree;
    if (tree == null) return;
    _limpiarTimers();
    setState(() {
      _escribiendo = false;
      _chipsSaliendo = false;
      _opciones = const [];
      _mensajes = [
        SupportBotMensaje(
          id: ++_contador,
          autor: 'bot',
          texto: tree.meta.saludo,
        ),
      ];
    });
    _irANodo(tree.meta.nodoInicial, retraso: _arranqueSaludo);
  }

  void _elegirOpcion(SupportBotOpcion opcion) {
    // Mientras el bot "escribe" o los chips salen, los toques se ignoran:
    // encadenar turnos a medias es justo lo que se siente tosco.
    if (_escribiendo || _chipsSaliendo) return;

    setState(() {
      _mensajes = [
        ..._mensajes,
        SupportBotMensaje(
          id: ++_contador,
          autor: 'usuario',
          texto: opcion.texto,
        ),
      ];
    });
    _alFinal();

    if (opcion.accion == 'whatsapp') {
      _abrirExterno(_whatsapp);
      return;
    }

    final url = opcion.url;
    if (url != null) {
      if (url.startsWith('/')) {
        widget.onOpenChange(false);
        _programar(() => rtcNavigate(url), _cierrePanel);
      } else {
        _abrirExterno(url);
      }
      return;
    }

    final destino = opcion.destino;
    if (destino == null) return;

    setState(() => _chipsSaliendo = true);
    _programar(() {
      if (mounted) setState(() => _opciones = const []);
    }, _salidaChips);
    _irANodo(destino, retraso: _salidaChips);
  }

  Future<void> _abrirExterno(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  /// La web deja que el navegador siga el scroll; aca hay que empujarlo.
  void _alFinal() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 240),
        curve: RtcCurves.expoOut,
      );
    });
  }

  // ── PINTADO ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tree = _tree;
    if (!_montado || tree == null) return const SizedBox.shrink();

    final abajo = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      // `inset-x-4 bottom-4 top-20` de la rama movil. El `top-20` de la web se
      // mide desde el tope de la VENTANA, y el navbar (64) ya ocupa parte de
      // eso; aca el panel vive debajo del navbar, asi que solo queda el resto.
      left: RtcSpace.s4,
      right: RtcSpace.s4,
      top: 80 - kNavHeight,
      bottom: RtcSpace.s4 + abajo,
      child: RtcChatPanel(
        cerrando: _cerrando,
        child: Material(
          color: Colors.transparent,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: Superficie.tarjeta,
              borderRadius: const BorderRadius.all(
                Radius.circular(24),
              ), // rounded-3xl
              border: Border.all(color: Gray.c100),
              boxShadow: RtcShadows.sheetCard,
            ),
            child: Column(
              children: [
                _encabezado(tree),
                Expanded(child: _conversacion()),
                _pie(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _encabezado(SupportBotTree tree) {
    return Container(
      color: GrisFijo.c900,
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s5,
        vertical: RtcSpace.s4,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Lime.c400,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.bot, size: 20, color: GrisFijo.c900),
          ),
          const SizedBox(width: RtcSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tree.meta.titulo.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RtcType.sm.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.4, // tracking-wide
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Lime.c400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tree.meta.subtitulo,
                      style: RtcType.xs.copyWith(color: GrisFijo.c500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _accion(LucideIcons.rotateCcw, 18, _reiniciar),
          _accion(LucideIcons.x, 20, () => widget.onOpenChange(false)),
        ],
      ),
    );
  }

  Widget _accion(IconData icon, double size, VoidCallback onTap) {
    return RtcPressable(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(RtcSpace.s2),
        child: Icon(icon, size: size, color: Gray.c500),
      ),
    );
  }

  Widget _conversacion() {
    return ColoredBox(
      color: Gray.c50,
      child: ListView(
        controller: _scroll,
        padding: const EdgeInsets.symmetric(
          horizontal: RtcSpace.s4,
          vertical: RtcSpace.s5,
        ),
        children: [
          for (final m in _mensajes)
            Padding(
              padding: const EdgeInsets.only(bottom: RtcSpace.s3),
              child: RtcChatBubbleIn(key: ValueKey(m.id), child: _burbuja(m)),
            ),
          if (_escribiendo)
            Padding(
              padding: const EdgeInsets.only(bottom: RtcSpace.s3),
              child: RtcChatBubbleIn(child: _puntitos()),
            ),
          if (_opciones.isNotEmpty) _chips(),
        ],
      ),
    );
  }

  Widget _burbuja(SupportBotMensaje m) {
    return Align(
      alignment: m.esBot ? Alignment.centerLeft : Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.85, // max-w-[85%]
        alignment: m.esBot ? Alignment.centerLeft : Alignment.centerRight,
        child: Align(
          alignment: m.esBot ? Alignment.centerLeft : Alignment.centerRight,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: RtcSpace.s4,
              vertical: m.esBot ? RtcSpace.s3 : 10, // py-3 / py-2.5
            ),
            decoration: BoxDecoration(
              color: m.esBot ? Superficie.tarjeta : GrisFijo.c900,
              // rounded-2xl con la esquina de arriba del lado del autor casi recta
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(m.esBot ? 2 : 16),
                topRight: Radius.circular(m.esBot ? 16 : 2),
                bottomLeft: const Radius.circular(16),
                bottomRight: const Radius.circular(16),
              ),
              border: m.esBot ? Border.all(color: Gray.c100) : null,
              boxShadow: m.esBot ? RtcShadows.card : null,
            ),
            child: Text(
              m.texto,
              style: RtcType.sm.copyWith(
                color: m.esBot ? Gray.c700 : Colors.white,
                fontWeight: m.esBot ? null : RtcType.semibold,
                height: m.esBot ? 1.625 : null, // leading-relaxed
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _puntitos() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: RtcSpace.s4,
          vertical: 14, // py-3.5
        ),
        decoration: BoxDecoration(
          color: Superficie.tarjeta,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(2),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(color: Gray.c100),
          boxShadow: RtcShadows.card,
        ),
        child: const RtcTypingDots(),
      ),
    );
  }

  Widget _chips() {
    return Padding(
      padding: const EdgeInsets.only(top: 4), // pt-1
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < _opciones.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: RtcSpace.s2),
              child: _chip(_opciones[i], i),
            ),
        ],
      ),
    );
  }

  Widget _chip(SupportBotOpcion opcion, int i) {
    final cuerpo = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.90 - RtcSpace.s4 * 4,
      ),
      child: RtcPressable(
        behavior: HitTestBehavior.opaque,
        onTap: () => _elegirOpcion(opcion),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: RtcSpace.s4,
            vertical: RtcSpace.s2,
          ),
          decoration: BoxDecoration(
            color: Superficie.tarjeta,
            borderRadius: RtcRadius.brFull,
            border: Border.all(color: Gray.c200),
            boxShadow: RtcShadows.card,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  opcion.texto,
                  style: RtcType.sm.copyWith(
                    fontWeight: RtcType.semibold,
                    color: Gray.c700,
                  ),
                ),
              ),
              const SizedBox(width: 6), // gap-1.5
              Icon(
                opcion.esExterno
                    ? LucideIcons.externalLink
                    : LucideIcons.chevronRight,
                size: 14,
                color: Gray.c500,
              ),
            ],
          ),
        ),
      ),
    );

    // El escalonado cambia de sentido: 55ms al entrar, 22ms al salir.
    return _chipsSaliendo
        ? RtcChatChipOut(
            key: ValueKey('out-$_turno-${opcion.texto}'),
            delay: Duration(milliseconds: i * 22),
            child: cuerpo,
          )
        : RtcChatChipIn(
            key: ValueKey('in-$_turno-${opcion.texto}'),
            delay: Duration(milliseconds: i * 55),
            child: cuerpo,
          );
  }

  Widget _pie() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s4,
        vertical: RtcSpace.s3,
      ),
      decoration: BoxDecoration(
        color: Superficie.tarjeta,
        border: Border(top: BorderSide(color: Gray.c100)),
      ),
      child: RtcPressable(
        behavior: HitTestBehavior.opaque,
        onTap: () => _abrirExterno(_whatsapp),
        child: Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: '¿Prefieres hablar con una persona? '),
              TextSpan(
                text: 'Escríbenos por WhatsApp',
                style: RtcType.xs.copyWith(
                  fontSize: 11,
                  color: Green.c600,
                  fontWeight: RtcType.bold,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
          style: RtcType.xs.copyWith(fontSize: 11, color: Gray.c500),
        ),
      ),
    );
  }
}
