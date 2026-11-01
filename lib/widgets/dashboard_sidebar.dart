import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../auth/session.dart';
import '../theme/motion.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'motion/rtc_pressable.dart';

/// Port de `Frontend/src/components/layout/DashboardSidebar.tsx`, rama movil
/// (`variant="mobile"`): en el cajon la barra va siempre expandida, sin el
/// boton de contraer, que es solo de escritorio.
///
/// Solo estan las secciones del PROPIETARIO. El panel de administrador de la
/// plataforma se queda en la web (decidido el 2026-08-22).
class DashboardSidebar extends StatelessWidget {
  const DashboardSidebar({
    super.key,
    required this.route,
    required this.onNavigate,
  });

  /// La ruta actual, para marcar el activo.
  final String route;

  final ValueChanged<String> onNavigate;

  /// `OWNER_SECTIONS`.
  static const secciones = <(String?, List<(String, String, IconData)>)>[
    (
      null,
      [
        ('/dashboard', 'Inicio', LucideIcons.layoutDashboard),
        ('/dashboard/propetario/canchas', 'Mis canchas', LucideIcons.building2),
        (
          '/dashboard/propetario/reservas',
          'Reservas',
          LucideIcons.calendarDays,
        ),
        ('/dashboard/propetario/escanear', 'Escanear QR', LucideIcons.scanLine),
      ],
    ),
    (
      'Operación',
      [
        (
          '/dashboard/propetario/analytics',
          'Analytics',
          LucideIcons.chartColumn,
        ),
        ('/dashboard/propetario/pagos', 'Pagos', LucideIcons.creditCard),
        ('/dashboard/propetario/bloqueos', 'Bloqueos', LucideIcons.ban),
        ('/dashboard/propetario/fotos', 'Fotos', LucideIcons.image),
      ],
    ),
    (
      'Cuenta',
      [
        ('/dashboard/propetario/mi-club', 'Mi Club', LucideIcons.building2),
        ('/dashboard/propetario/equipo', 'Equipo', LucideIcons.usersRound),
        ('/dashboard/propetario/soporte', 'Soporte', LucideIcons.messageSquare),
      ],
    ),
  ];

  /// Lo que ve el dueño pero no sus empleados (ver `SoloTitularGuard`).
  static const soloTitular = {
    '/dashboard/propetario/pagos',
    '/dashboard/propetario/equipo',
  };

  /// `isActive`: exacto para /dashboard, por prefijo para el resto.
  bool _activo(String href) =>
      route == href || (href != '/dashboard' && route.startsWith(href));

  @override
  Widget build(BuildContext context) {
    final user = RtcSession.instance.user;
    final nombre = user?.name ?? '';

    return ColoredBox(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _logo(),
          _perfil(nombre),
          Expanded(child: _nav()),
          _pie(),
        ],
      ),
    );
  }

  /// h-16 con borde abajo.
  Widget _logo() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Slate.c100)),
      ),
      child: RtcPressable(
        behavior: HitTestBehavior.opaque,
        onTap: () => onNavigate('/'),
        child: Row(
          children: [
            Image.asset('assets/images/logo.png', width: 40, height: 40),
            const SizedBox(width: 10), // gap-2.5
            Text.rich(
              const TextSpan(
                children: [
                  TextSpan(text: 'Reserva'),
                  TextSpan(
                    text: 'TuCancha',
                    style: TextStyle(color: Green.c600),
                  ),
                ],
              ),
              style: RtcType.sm.copyWith(
                fontWeight: FontWeight.w900,
                color: Slate.c900,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _perfil(String nombre) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s4,
        vertical: RtcSpace.s4,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Slate.c100)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              // bg-gradient-to-br from-green-500 to-green-600
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Green.c500, Green.c600],
              ),
            ),
            child: Text(
              nombre.isEmpty ? '?' : nombre.substring(0, 1).toUpperCase(),
              style: RtcType.sm.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: RtcSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RtcType.sm.copyWith(
                    fontWeight: RtcType.bold,
                    color: Slate.c900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'PROPIETARIO',
                  style: RtcType.xs.copyWith(
                    fontSize: 11,
                    color: Green.c600,
                    fontWeight: RtcType.bold,
                    letterSpacing: 1.6, // tracking-widest
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nav() {
    // `staggerChildren: .04` con `delayChildren: .06`, cada uno entrando desde
    // 10px a la izquierda en 250ms.
    var indice = 0;
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s3,
        vertical: RtcSpace.s3,
      ),
      children: [
        // Las nueve secciones del panel, como en la web.
        for (final (etiqueta, items) in secciones) ...[
          if (etiqueta != null) _etiquetaSeccion(etiqueta),
          for (final (href, label, icon) in items)
            if (!(RtcSession.instance.user?.esStaff == true &&
                soloTitular.contains(href)))
              _Enlace(
                href: href,
                label: label,
                icon: icon,
                activo: _activo(href),
                orden: indice++,
                onTap: () => onNavigate(href),
              ),
        ],
      ],
    );
  }

  Widget _etiquetaSeccion(String texto) {
    return Padding(
      padding: const EdgeInsets.only(
        top: RtcSpace.s4,
        bottom: 4,
        left: RtcSpace.s3,
        right: RtcSpace.s3,
      ),
      child: Text(
        texto.toUpperCase(),
        style: RtcType.xs.copyWith(
          fontSize: 11,
          color: Slate.c400,
          fontWeight: RtcType.bold,
          letterSpacing: 0.8, // tracking-wider
        ),
      ),
    );
  }

  Widget _pie() {
    return Container(
      padding: const EdgeInsets.all(RtcSpace.s3),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Slate.c100)),
      ),
      child: Column(
        children: [
          _accion(
            LucideIcons.house,
            'Ver sitio',
            Slate.c500,
            () => onNavigate('/'),
          ),
          const SizedBox(height: 4),
          _accion(
            LucideIcons.logOut,
            'Cerrar sesión',
            Red.c500,
            () => onNavigate('__logout__'),
          ),
        ],
      ),
    );
  }

  Widget _accion(IconData icon, String label, Color color, VoidCallback onTap) {
    return RtcPressable(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: RtcSpace.s3,
          vertical: 10, // py-2.5
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: RtcSpace.s3),
            Text(
              label,
              style: RtcType.sm.copyWith(
                fontWeight: RtcType.semibold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `SidebarLink`. El activo lleva fondo verde claro y la barrita vertical con
/// degradado pegada al borde izquierdo.
class _Enlace extends StatelessWidget {
  const _Enlace({
    required this.href,
    required this.label,
    required this.icon,
    required this.activo,
    required this.orden,
    required this.onTap,
  });

  final String href;
  final String label;
  final IconData icon;
  final bool activo;
  final int orden;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _EntradaEscalonada(
      // `delayChildren: .06` + `staggerChildren: .04`
      delay: Duration(milliseconds: 60 + orden * 40),
      child: RtcPressable(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 2), // gap-0.5
          padding: const EdgeInsets.symmetric(
            horizontal: RtcSpace.s3,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: activo ? Green.c50 : null,
            borderRadius: RtcRadius.brXl,
          ),
          child: Stack(
            children: [
              if (activo)
                Positioned(
                  left: -RtcSpace.s3,
                  top: 4,
                  bottom: 4,
                  child: Container(
                    width: 4,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Green.c500, Green.c600],
                      ),
                      borderRadius: BorderRadius.horizontal(
                        right: Radius.circular(999),
                      ),
                    ),
                  ),
                ),
              Row(
                children: [
                  Icon(icon, size: 20, color: activo ? Green.c600 : Slate.c500),
                  const SizedBox(width: RtcSpace.s3),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RtcType.sm.copyWith(
                        fontWeight: RtcType.semibold,
                        color: activo ? Green.c700 : Slate.c500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `navItem`: opacidad 0→1 y 10px desde la izquierda, 250ms con easeOut.
class _EntradaEscalonada extends StatefulWidget {
  const _EntradaEscalonada({required this.delay, required this.child});

  final Duration delay;
  final Widget child;

  @override
  State<_EntradaEscalonada> createState() => _EntradaEscalonadaState();
}

class _EntradaEscalonadaState extends State<_EntradaEscalonada>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 250),
  );

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _c.forward();
    });
  }

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
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(-10 * (1 - t), 0),
            child: child,
          ),
        );
      },
    );
  }
}
