import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/motion.dart';
import '../theme/palette.dart';
import '../theme/shadows.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'motion/rtc_pressable.dart';

/// `USER_LINKS` del Navbar.
const userLinks = <(String, String)>[
  ('/', 'Inicio'),
  ('/empresas', 'Canchas'),
  ('/mis-reservas', 'Mis reservas'),
  ('/soporte', 'Soporte'),
];

/// `BIZ_LINKS` del Navbar.
const bizLinks = <(String, String)>[
  ('/para-clubes#beneficios', 'Beneficios'),
  ('/para-clubes#como-funciona', 'Cómo funciona'),
  ('/para-clubes#faq', 'Preguntas'),
];

/// Port del menu movil de `Frontend/src/components/layout/Navbar.tsx`.
///
/// Se despliega en alto (320ms) mientras hace fade (200ms), y los enlaces
/// entran escalonados. Arriba lleva el switch Reservar / Para clubes, que
/// cambia el juego de enlaces con un cruce corto.
class RtcMobileMenu extends StatefulWidget {
  const RtcMobileMenu({
    super.key,
    required this.open,
    required this.onNavigate,
    required this.onModeChange,
    this.isBiz = false,
    this.signedIn = false,
    this.onSignOut,
    this.onDashboard,
  });

  final bool open;

  /// Un enlace de la lista: cierra el menu y navega.
  final ValueChanged<String> onNavigate;

  /// El switch Reservar / Para clubes: navega pero DEJA EL MENU ABIERTO, para
  /// que se vea la transicion (el `keepOpenRef` de la web).
  final ValueChanged<String> onModeChange;

  /// `isBiz` sale de la RUTA, no del menu:
  /// `pathname.startsWith('/para-clubes') || startsWith('/solicitar-acceso')`.
  final bool isBiz;

  /// Sale de `RtcSession`, como el `useSession()` del Navbar.
  final bool signedIn;

  /// Abre el panel del propietario. Va aparte de `onNavigate` porque el panel
  /// no es una ruta del sitio publico: tiene su propio armazon y su guardia.
  final VoidCallback? onDashboard;

  /// Borra la sesion y vuelve al inicio, como el `logout('/')` de la web.
  final VoidCallback? onSignOut;

  @override
  State<RtcMobileMenu> createState() => _RtcMobileMenuState();
}

class _RtcMobileMenuState extends State<RtcMobileMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: RtcDur.menuHeight,
    value: widget.open ? 1 : 0,
  );

  /// Estado optimista del switch: la pildora se mueve apenas se toca, sin
  /// esperar a que termine la navegacion. Es el `pending` del ModeToggle.
  bool? _pending;

  bool get _isBiz => _pending ?? widget.isBiz;

  @override
  void didUpdateWidget(RtcMobileMenu old) {
    super.didUpdateWidget(old);
    if (widget.open != old.open) {
      widget.open ? _c.forward() : _c.reverse();
    }
    // `useEffect(() => setPending(null), [isBiz])`: cuando la ruta confirma el
    // modo, se suelta el estado optimista.
    if (widget.isBiz != old.isBiz) _pending = null;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // La altura usa el ease de framer; la opacidad termina antes (200 de 320).
    final height = CurvedAnimation(parent: _c, curve: RtcCurves.framerExpo);
    final fade = CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 200 / 320),
    );

    final links = _isBiz ? bizLinks : userLinks;

    return SizeTransition(
      sizeFactor: height,
      // Crece hacia abajo, anclado al borde superior.
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: fade,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Gray.c100)),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: RtcSpace.s4,
            vertical: RtcSpace.s4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: _ModeToggle(
                  isBiz: _isBiz,
                  onChanged: (v) {
                    setState(() => _pending = v);
                    widget.onModeChange(v ? '/para-clubes' : '/');
                  },
                ),
              ),
              const SizedBox(height: RtcSpace.s3),

              // Los enlaces cambian con el modo: se cruzan con un fade corto.
              AnimatedSwitcher(
                duration: RtcDur.menuLinksSwap,
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeOut,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.15),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: Column(
                  key: ValueKey(_isBiz),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < links.length; i++) ...[
                      if (i > 0)
                        const SizedBox(height: RtcSpace.s1), // space-y-1
                      _MenuLink(
                        label: links[i].$2,
                        // delay: 0.04 + i * 0.045
                        delay: RtcDur.menuLinkDelay + RtcDur.menuLinkStep * i,
                        onTap: () => widget.onNavigate(links[i].$1),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: RtcSpace.s3),
              const Divider(height: 1, thickness: 1, color: Gray.c100),

              // El separador es el ultimo hijo cuando no hay botones debajo:
              // ahi el aire lo pone el padding del panel, no un espaciador.
              if (_isBiz || widget.signedIn)
                const SizedBox(height: RtcSpace.s3),

              if (_isBiz && !widget.signedIn) ...[
                _MenuButton(
                  label: 'Ingresar',
                  onTap: () => widget.onNavigate('/auth/login'),
                  foreground: Gray.c700,
                  border: Gray.c200,
                ),
                const SizedBox(height: RtcSpace.s3),
              ],
              if (_isBiz)
                _MenuButton(
                  label: 'Solicitar acceso',
                  onTap: () => widget.onNavigate('/solicitar-acceso'),
                  background: Green.c600,
                  foreground: Colors.white,
                  bold: true,
                ),

              if (widget.signedIn) ...[
                // La pantalla de /dashboard todavia no existe: `rtcNavigate`
                // ignora las rutas que no estan en el mapa, asi que el boton no
                // rompe nada mientras tanto. Queda puesto a proposito, el panel
                // del propietario se hace mas adelante.
                _MenuButton(
                  label: 'Dashboard',
                  icon: LucideIcons.layoutDashboard,
                  onTap: () => widget.onDashboard?.call(),
                  background: Blue.c50,
                  foreground: Blue.c600,
                ),
                const SizedBox(height: RtcSpace.s2),
                _MenuButton(
                  label: 'Cerrar sesión',
                  icon: LucideIcons.logOut,
                  onTap: () => widget.onSignOut?.call(),
                  background: Red.c50,
                  foreground: Red.c600,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Un enlace del menu. Entra desde 8px abajo con el ease de framer, con el
/// retraso que le toca por posicion.
class _MenuLink extends StatefulWidget {
  const _MenuLink({
    required this.label,
    required this.delay,
    required this.onTap,
  });

  final String label;
  final Duration delay;
  final VoidCallback onTap;

  @override
  State<_MenuLink> createState() => _MenuLinkState();
}

class _MenuLinkState extends State<_MenuLink>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: RtcDur.menuLinkIn,
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
    final row = RtcPressable(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: RtcSpace.s4,
          vertical: 10, // py-2.5
        ),
        child: Text(
          widget.label,
          style: RtcType.sm.copyWith(
            fontWeight: RtcType.semibold,
            color: Gray.c700,
          ),
        ),
      ),
    );

    if (rtcReducedMotion(context)) return row;

    return AnimatedBuilder(
      animation: _c,
      child: row,
      builder: (context, child) {
        final t = RtcCurves.framerExpo.transform(_c.value);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.label,
    required this.onTap,
    required this.foreground,
    this.background,
    this.border,
    this.icon,
    this.bold = false,
  });

  final String label;
  final VoidCallback onTap;
  final Color foreground;
  final Color? background;
  final Color? border;
  final IconData? icon;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return RtcPressable(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: RtcSpace.s4,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: RtcRadius.brXl,
          border: border != null ? Border.all(color: border!) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: foreground),
              const SizedBox(width: RtcSpace.s2),
            ],
            Text(
              label,
              style: RtcType.sm.copyWith(
                fontWeight: bold ? RtcType.bold : RtcType.semibold,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Port de `ModeToggle`. La pildora blanca se mueve con el MISMO resorte de
/// framer-motion (`stiffness: 420, damping: 34`), no con una curva aproximada.
class _ModeToggle extends StatefulWidget {
  const _ModeToggle({required this.isBiz, required this.onChanged});

  final bool isBiz;
  final ValueChanged<bool> onChanged;

  @override
  State<_ModeToggle> createState() => _ModeToggleState();
}

class _ModeToggleState extends State<_ModeToggle>
    with SingleTickerProviderStateMixin {
  static const _options = [('Reservar', false), ('Para clubes', true)];

  late final AnimationController _c = AnimationController.unbounded(
    vsync: this,
    value: widget.isBiz ? 1 : 0,
  );

  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 34,
  );

  @override
  void didUpdateWidget(_ModeToggle old) {
    super.didUpdateWidget(old);
    if (widget.isBiz != old.isBiz) {
      _c.animateWith(
        SpringSimulation(_spring, _c.value, widget.isBiz ? 1 : 0, 0),
      );
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// El ancho real de cada opcion: px-4 a cada lado del texto. Se mide con un
  /// TextPainter para que la pildora calce exacto, como el `layoutId` del web.
  double _optionWidth(String label, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.width + RtcSpace.s4 * 2;
  }

  @override
  Widget build(BuildContext context) {
    final style = RtcType.sm.copyWith(fontWeight: RtcType.semibold);
    final widths = [for (final o in _options) _optionWidth(o.$1, style)];

    return Container(
      padding: const EdgeInsets.all(RtcSpace.s1), // p-1
      decoration: const BoxDecoration(
        color: Gray.c100,
        borderRadius: RtcRadius.brFull,
      ),
      child: SizedBox(
        height: 34, // py-1.5 sobre text-sm
        width: widths[0] + widths[1],
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            // Sin clamp: el resorte sobrepasa un poco el destino y vuelve,
            // igual que el layoutId de framer. Y sin recorte, para que ese
            // sobrepaso se vea.
            final t = _c.value;
            return Stack(
              clipBehavior: Clip.none,
              children: [
                // La pildora blanca se desplaza Y cambia de ancho, igual que
                // el layoutId de framer entre dos opciones de distinto largo.
                Positioned(
                  left: widths[0] * t,
                  top: 0,
                  bottom: 0,
                  width: widths[0] + (widths[1] - widths[0]) * t,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: RtcRadius.brFull,
                      boxShadow: [
                        cssShadow(
                          dy: 1,
                          blur: 2,
                          color: Colors.black.withValues(alpha: 0.05),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < _options.length; i++)
                      SizedBox(
                        width: widths[i],
                        child: RtcPressable(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onChanged(_options[i].$2),
                          child: Center(
                            child: Text(
                              _options[i].$1,
                              style: style.copyWith(
                                color: widget.isBiz == _options[i].$2
                                    ? Gray.c900
                                    : Gray.c500,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
