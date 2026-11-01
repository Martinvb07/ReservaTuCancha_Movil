import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../auth/session.dart';
import '../realtime/rtc_realtime.dart';
import '../theme/motion.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../widgets/dashboard_sidebar.dart';
import 'routes.dart';
import '../widgets/motion/rtc_pressable.dart';

/// Port de `Frontend/src/components/layout/DashboardShell.tsx`, rama movil.
///
/// En telefono la sidebar no esta fija: la abre el boton de hamburguesa de la
/// cabecera y entra desde la izquierda sobre un velo negro al 50%.
///
/// El panel NO comparte el navbar publico: es otro armazon entero, igual que
/// en la web, donde `/dashboard` tiene su propio layout.
class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key, required this.route, required this.child});

  final String route;
  final Widget child;

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

/// `w-64`.
const _anchoCajon = 256.0;

class _DashboardShellState extends State<DashboardShell> {
  bool _abierta = false;

  @override
  void didUpdateWidget(DashboardShell old) {
    super.didUpdateWidget(old);
    // Al cambiar de seccion el cajon se cierra solo.
    if (widget.route != old.route && _abierta) {
      setState(() => _abierta = false);
    }
  }

  void _navegar(String href) {
    setState(() => _abierta = false);
    if (href == '__logout__') {
      RtcSession.instance.logout();
      rtcNavigate('/');
      return;
    }
    if (href == '/') {
      rtcNavigate('/');
      return;
    }
    rtcIrAlPanel(href);
  }

  @override
  Widget build(BuildContext context) {
    // El `<RealtimeNotifications />` del layout de /dashboard: el socket vive
    // solo mientras se esta en el panel.
    return RealtimeNotifications(
      child: Scaffold(
        // bg-gray-50 del contenedor
        backgroundColor: Fondo.app,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _cabecera(),
                  // p-4 del contenedor de contenido
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(RtcSpace.s4),
                      child: widget.child,
                    ),
                  ),
                ],
              ),
              if (_abierta) ..._cajon(),
            ],
          ),
        ),
      ),
    );
  }

  /// La cabecera movil: hamburguesa, logo centrado y un hueco del mismo ancho
  /// a la derecha para que el logo quede centrado de verdad.
  Widget _cabecera() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s4),
      // Sin franja blanca ni linea: la cabecera va sobre el mismo fondo de
      // la app, como en las pantallas del jugador.
      color: Fondo.app,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RtcPressable(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _abierta = !_abierta),
            child: Padding(
              padding: const EdgeInsets.all(RtcSpace.s2),
              child: Icon(
                _abierta ? LucideIcons.x : LucideIcons.menu,
                size: 20,
                color: Slate.c600,
              ),
            ),
          ),
          Image.asset('assets/images/logo.png', width: 36, height: 36),
          const SizedBox(width: 36), // el spacer de la web
        ],
      ),
    );
  }

  List<Widget> _cajon() {
    return [
      // bg-black/50
      Positioned.fill(
        child: GestureDetector(
          onTap: () => setState(() => _abierta = false),
          child: ColoredBox(color: Colors.black.withValues(alpha: 0.50)),
        ),
      ),
      Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        width: _anchoCajon,
        child: _CajonQueEntra(
          child: DashboardSidebar(route: widget.route, onNavigate: _navegar),
        ),
      ),
    ];
  }
}

/// La sidebar de la web entra con `x: -16, opacity: 0` en 300ms easeOut. En el
/// cajon movil se recorre el ancho completo, que es lo que se espera de un
/// panel lateral.
class _CajonQueEntra extends StatefulWidget {
  const _CajonQueEntra({required this.child});

  final Widget child;

  @override
  State<_CajonQueEntra> createState() => _CajonQueEntraState();
}

class _CajonQueEntraState extends State<_CajonQueEntra>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (rtcReducedMotion(context)) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = RtcCurves.easeOut.transform(_c.value);
        return Transform.translate(
          offset: Offset(-_anchoCajon * (1 - t), 0),
          child: Opacity(opacity: t, child: child),
        );
      },
    );
  }
}
