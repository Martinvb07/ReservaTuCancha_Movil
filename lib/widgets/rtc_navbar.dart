import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/motion.dart';
import '../theme/palette.dart';
import '../theme/shadows.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'motion/rtc_motion.dart';

/// Alto del navbar en la web (`h-16`).
const double kNavHeight = 64;

/// `TRIGGER` de useSearchDock: el navbar mas 6px de margen, para que el cambio
/// no ocurra justo en el borde y la pildora quede medio tapada.
const double kDockTrigger = kNavHeight + 6;

/// Port de `Frontend/src/components/layout/Navbar.tsx`.
///
/// Sticky, blanco, con borde inferior. Cuando el buscador grande de la pagina
/// ya paso por encima (docked), los links se reemplazan por una pildora
/// compacta de busqueda — el comportamiento tipo Airbnb de la web.
class RtcNavbar extends StatelessWidget implements PreferredSizeWidget {
  const RtcNavbar({
    super.key,
    required this.docked,
    required this.onSearchTap,
    required this.menuOpen,
    required this.onMenuTap,
  });

  final bool docked;
  final VoidCallback onSearchTap;
  final bool menuOpen;
  final VoidCallback onMenuTap;

  @override
  Size get preferredSize => const Size.fromHeight(kNavHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(bottom: BorderSide(color: Gray.c100)),
        // shadow-sm de Tailwind
        boxShadow: [
          cssShadow(
            dy: 1,
            blur: 2,
            color: Colors.black.withValues(alpha: 0.05),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: kNavHeight,
          child: Padding(
            // px-6 en la web; en movil se aprieta un poco para la pildora
            padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s4),
            child: Row(
              children: [
                // ── Logo ──────────────────────────────────────────────
                Image.asset(
                  'assets/images/logo.png',
                  width: 44, // h-11 w-11
                  height: 44,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: RtcSpace.s3),

                // Con la pildora acoplada el wordmark estorba: la web lo
                // esconde por debajo de `sm`, y en telefono estamos siempre
                // por debajo de ese breakpoint.
                if (!docked)
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Reserva'),
                          TextSpan(
                            text: 'TuCancha',
                            style: const TextStyle(color: Green.c600),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RtcType.xl.copyWith(
                        fontWeight: FontWeight.w900, // font-black
                        color: Gray.c900,
                        letterSpacing: -0.4, // tracking-tight
                      ),
                    ),
                  )
                else
                  // ── Buscador acoplado ──────────────────────────────
                  Expanded(
                    child: RtcNavSearchIn(
                      child: _NavSearchPillCompact(onTap: onSearchTap),
                    ),
                  ),

                _HamburgerButton(open: menuOpen, onTap: onMenuTap),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// El boton hamburguesa: el icono gira y se funde al alternar.
///
/// La web usa `AnimatePresence mode="wait"`, o sea el icono viejo termina de
/// salir ANTES de que entre el nuevo. Por eso no alcanza un AnimatedSwitcher,
/// que los superpone: hay que animar 1->0, cambiar el icono y animar 0->1.
class _HamburgerButton extends StatefulWidget {
  const _HamburgerButton({required this.open, required this.onTap});

  final bool open;
  final VoidCallback onTap;

  @override
  State<_HamburgerButton> createState() => _HamburgerButtonState();
}

class _HamburgerButtonState extends State<_HamburgerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: RtcDur.menuIcon,
    value: 1,
  );

  late bool _shown = widget.open;
  bool _pressed = false;

  @override
  void didUpdateWidget(_HamburgerButton old) {
    super.didUpdateWidget(old);
    if (widget.open != old.open) _swap();
  }

  Future<void> _swap() async {
    await _c.reverse();
    if (!mounted) return;
    setState(() => _shown = widget.open);
    await _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        // active:scale-95
        scale: _pressed ? 0.95 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: 36, // h-9 w-9
          height: 36,
          alignment: Alignment.center,
          decoration: const BoxDecoration(borderRadius: RtcRadius.brLg),
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = RtcCurves.framerExpo.transform(_c.value);
              // rotate: +-90 -> 0 segun a que estado va, y scale .7 -> 1
              final sign = _shown ? -1 : 1;
              return Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: Transform.rotate(
                  angle: sign * (math.pi / 2) * (1 - t),
                  child: Transform.scale(
                    scale: 0.7 + 0.3 * t,
                    child: Icon(
                      _shown ? LucideIcons.x : LucideIcons.menu,
                      size: 20,
                      color: Gray.c900,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Port de `NavSearchPillCompact` de `NavSearchPill.tsx`.
class _NavSearchPillCompact extends StatefulWidget {
  const _NavSearchPillCompact({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_NavSearchPillCompact> createState() => _NavSearchPillCompactState();
}

class _NavSearchPillCompactState extends State<_NavSearchPillCompact> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        // active:scale-[.98]
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          height: 44, // h-11
          margin: const EdgeInsets.symmetric(horizontal: RtcSpace.s1),
          padding: const EdgeInsets.only(left: RtcSpace.s2, right: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: RtcRadius.brFull,
            border: Border.all(color: Gray.c200),
            boxShadow: [
              cssShadow(
                dy: 2,
                blur: 10,
                color: const Color(0xFF141E16).withValues(alpha: 0.09),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Green.c600,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.search,
                  size: 16,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Busca tu cancha',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RtcType.sm.copyWith(
                        fontSize: 13,
                        height: 1.25, // leading-tight
                        fontWeight: RtcType.bold,
                        color: Gray.c900,
                      ),
                    ),
                    Text(
                      'Deporte · Ciudad · Fecha · Hora',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RtcType.xs.copyWith(
                        fontSize: 11,
                        height: 1.25,
                        color: Gray.c500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
