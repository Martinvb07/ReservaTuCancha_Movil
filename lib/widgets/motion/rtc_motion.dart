/// Las animaciones de globals.css, una por una, como widgets reusables.
///
/// Todas respetan prefers-reduced-motion igual que el CSS: si el sistema pide
/// menos movimiento, se pinta el estado final sin animar.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/motion.dart';
import '../../theme/shadows.dart';
import '../../theme/tokens.dart';

// ---------------------------------------------------------------------------
// Base compartida para las animaciones de ENTRADA (se disparan al montar).
// ---------------------------------------------------------------------------

typedef _EntranceBuilder = Widget Function(double t, Widget child);

class _Entrance extends StatefulWidget {
  const _Entrance({
    required this.duration,
    required this.curve,
    required this.builder,
    required this.child,
    this.delay = Duration.zero,
  });

  final Duration duration;
  final Duration delay;
  final Curve curve;
  final _EntranceBuilder builder;
  final Widget child;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    // Sin esto el controller sigue vivo. En CSS el navegador pausa las
    // animaciones fuera de pantalla; aca no hay nadie que lo haga por vos.
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
        final t = widget.curve.transform(_c.value);
        return widget.builder(t, child!);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// .rtc-fade  --  @keyframes rtc-fadeUp
// opacity 0 -> 1, translateY(16px) -> 0, .55s cubic-bezier(.2,.7,.3,1)
// ---------------------------------------------------------------------------

class RtcFadeUp extends StatelessWidget {
  const RtcFadeUp({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return _Entrance(
      duration: RtcDur.fadeUp,
      curve: RtcCurves.fadeUp,
      delay: delay,
      builder: (t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// .rtc-drop  --  @keyframes rtc-dropIn
// Tres keyframes con overshoot: baja de -12px, se pasa 2px y vuelve.
// ---------------------------------------------------------------------------

class RtcDropIn extends StatefulWidget {
  const RtcDropIn({
    super.key,
    required this.child,
    this.alignment = Alignment.topCenter, // transform-origin: top center
  });

  final Widget child;
  final Alignment alignment;

  @override
  State<RtcDropIn> createState() => _RtcDropInState();
}

class _RtcDropInState extends State<RtcDropIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: RtcDur.dropIn,
  )..forward();

  // El 60% del keyframe es el punto de overshoot.
  static final _dy = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: -12.0,
        end: 2.0,
      ).chain(CurveTween(curve: RtcCurves.smooth)),
      weight: 60,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 2.0,
        end: 0.0,
      ).chain(CurveTween(curve: RtcCurves.smooth)),
      weight: 40,
    ),
  ]);

  static final _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.96,
        end: 1.01,
      ).chain(CurveTween(curve: RtcCurves.smooth)),
      weight: 60,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.01,
        end: 1.0,
      ).chain(CurveTween(curve: RtcCurves.smooth)),
      weight: 40,
    ),
  ]);

  static final _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 60),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
  ]);

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
      builder: (context, child) => Opacity(
        opacity: _opacity.evaluate(_c),
        child: Transform.translate(
          offset: Offset(0, _dy.evaluate(_c)),
          child: Transform.scale(
            scale: _scale.evaluate(_c),
            alignment: widget.alignment,
            child: child,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// .rtc-item  --  @keyframes rtc-itemIn
// opacity 0 -> 1, translateX(-8px) -> 0, .24s. Para listas escalonadas.
// ---------------------------------------------------------------------------

class RtcItemIn extends StatelessWidget {
  const RtcItemIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return _Entrance(
      duration: RtcDur.itemIn,
      curve: RtcCurves.smooth,
      delay: delay,
      builder: (t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(-8 * (1 - t), 0),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// .mobile-search-stack > *  --  @keyframes rtc-mobileFieldIn
// Entrada escalonada. En CSS son nth-child con animation-delay; aca se calcula
// el retraso por indice.
// ---------------------------------------------------------------------------

class RtcStagger extends StatelessWidget {
  const RtcStagger({
    super.key,
    required this.children,
    this.step = const Duration(milliseconds: 60),
    this.first = const Duration(milliseconds: 50),
  });

  final List<Widget> children;

  /// Separacion entre hijos. El sitio usa 50/110/170/230ms => 60ms de paso.
  final Duration step;

  /// Retraso del primer hijo.
  final Duration first;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < children.length; i++)
          _MobileFieldIn(delay: first + step * i, child: children[i]),
      ],
    );
  }
}

class _MobileFieldIn extends StatelessWidget {
  const _MobileFieldIn({required this.child, required this.delay});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return _Entrance(
      duration: RtcDur.mobileFieldIn,
      curve: RtcCurves.expoOut,
      delay: delay,
      builder: (t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// .rtc-sheet-up  --  @keyframes rtc-sheetUp
// ---------------------------------------------------------------------------

class RtcSheetUp extends StatelessWidget {
  const RtcSheetUp({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return _Entrance(
      duration: RtcDur.sheetUp,
      curve: RtcCurves.expoOut,
      delay: delay,
      builder: (t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 48 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// .rtc-chat-bubble  --  @keyframes rtc-chatBubbleIn
// ---------------------------------------------------------------------------

class RtcChatBubbleIn extends StatelessWidget {
  const RtcChatBubbleIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return _Entrance(
      duration: RtcDur.chatBubbleIn,
      curve: RtcCurves.expoOut,
      delay: delay,
      builder: (t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - t)),
          child: Transform.scale(scale: 0.96 + 0.04 * t, child: child),
        ),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// .check-in  --  @keyframes rtc-checkIn
// scale(0) rotate(-45deg) -> scale(1) rotate(0), .2s con rebote.
// ---------------------------------------------------------------------------

class RtcCheckIn extends StatelessWidget {
  const RtcCheckIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return _Entrance(
      duration: RtcDur.checkIn,
      curve: RtcCurves.backOut,
      delay: delay,
      builder: (t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: -(math.pi / 4) * (1 - t), // -45deg -> 0
          child: Transform.scale(scale: t, child: child),
        ),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// .rtc-pick  --  @keyframes rtc-calPick
// La celda late al elegirse: scale 1 -> 1.18 -> 1. Se dispara con [trigger].
// ---------------------------------------------------------------------------

class RtcPick extends StatefulWidget {
  const RtcPick({super.key, required this.child, required this.trigger});

  final Widget child;

  /// Cada vez que cambia de valor, late. Pasale el valor seleccionado.
  final Object? trigger;

  @override
  State<RtcPick> createState() => _RtcPickState();
}

class _RtcPickState extends State<RtcPick> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: RtcDur.pick,
  );

  static final _scale = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 1.18,
      ).chain(CurveTween(curve: RtcCurves.pickOut)),
      weight: 50,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.18,
        end: 1.0,
      ).chain(CurveTween(curve: RtcCurves.pickOut)),
      weight: 50,
    ),
  ]);

  @override
  void didUpdateWidget(RtcPick old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _c.forward(from: 0);
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
      builder: (context, child) =>
          Transform.scale(scale: _scale.evaluate(_c), child: child),
    );
  }
}

// ---------------------------------------------------------------------------
// .rtc-ready  --  @keyframes rtc-searchReady
// El boton de buscar respira cuando ya hay deporte, ciudad, fecha y hora.
// 2.2s infinita: sombra verde que crece y scale 1.015 en el pico.
// ---------------------------------------------------------------------------

class RtcReadyPulse extends StatefulWidget {
  const RtcReadyPulse({
    super.key,
    required this.child,
    required this.active,
    this.borderRadius = RtcRadius.brFull,
  });

  final Widget child;

  /// Solo respira cuando el formulario esta completo, igual que en la web.
  final bool active;
  final BorderRadius borderRadius;

  @override
  State<RtcReadyPulse> createState() => _RtcReadyPulseState();
}

class _RtcReadyPulseState extends State<RtcReadyPulse>
    with SingleTickerProviderStateMixin {
  // reverse:true hace el viaje de ida y vuelta => medio ciclo cada tramo.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: RtcDur.ready ~/ 2,
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(RtcReadyPulse old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.active && _c.isAnimating) {
      _c.stop();
      _c.value = 0;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active || rtcReducedMotion(context)) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: widget.borderRadius,
          boxShadow: RtcShadows.readyLow,
        ),
        child: widget.child,
      );
    }
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final t = RtcCurves.easeInOut.transform(_c.value);
        final shadow = BoxShadow.lerp(
          RtcShadows.readyLow.first,
          RtcShadows.readyHigh.first,
          t,
        )!;
        return Transform.scale(
          scale: 1 + 0.015 * t,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              boxShadow: [shadow],
            ),
            child: child,
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// .rtc-live  --  @keyframes rtc-pulseDot
// El punto "en vivo": un anillo verde que se expande 7px y se desvanece.
// En CSS es un box-shadow con spread animado; aca es literalmente lo mismo.
// ---------------------------------------------------------------------------

class RtcLiveDot extends StatefulWidget {
  const RtcLiveDot({super.key, this.size = 8, this.color = RtcBrand.green600});

  final double size;
  final Color color;

  @override
  State<RtcLiveDot> createState() => _RtcLiveDotState();
}

class _RtcLiveDotState extends State<RtcLiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: RtcDur.live,
  )..repeat();

  // 0% -> 70%: spread 0 -> 7px, alpha .55 -> 0. 70% -> 100%: invisible.
  static final _spread = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 7.0), weight: 70),
    TweenSequenceItem(tween: ConstantTween(0.0), weight: 30),
  ]);
  static final _alpha = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.55, end: 0.0), weight: 70),
    TweenSequenceItem(tween: ConstantTween(0.0), weight: 30),
  ]);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
    );
    if (rtcReducedMotion(context)) return dot;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: _alpha.evaluate(_c)),
              spreadRadius: _spread.evaluate(_c),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// .rtc-chat-typing  --  @keyframes rtc-chatTyping
// Onda suave de tres puntos, no el rebote duro de Tailwind.
// ---------------------------------------------------------------------------

class RtcTypingDots extends StatefulWidget {
  const RtcTypingDots({super.key, this.size = 6, this.color});

  final double size;
  final Color? color;

  @override
  State<RtcTypingDots> createState() => _RtcTypingDotsState();
}

class _RtcTypingDotsState extends State<RtcTypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: RtcDur.chatTyping,
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// El keyframe: 0%/65%/100% en reposo, pico en 32%.
  double _phase(double t) {
    if (t >= 0.65) return 0;
    final x = (t / 0.65).clamp(0.0, 1.0);
    return math.sin(x * math.pi);
  }

  @override
  Widget build(BuildContext context) {
    final color =
        widget.color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    if (rtcReducedMotion(context)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) SizedBox(width: widget.size * 0.66),
            _dot(color, 0.3, 0),
          ],
        ],
      );
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) SizedBox(width: widget.size * 0.66),
            // Cada punto va 1/6 de ciclo detras del anterior.
            () {
              final t = (_c.value + i / 6) % 1.0;
              final p = RtcCurves.easeInOut.transform(_phase(t));
              return _dot(color, 0.3 + 0.7 * p, -3 * p);
            }(),
          ],
        ],
      ),
    );
  }

  Widget _dot(Color color, double opacity, double dy) => Transform.translate(
    offset: Offset(0, dy),
    child: Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: opacity),
        shape: BoxShape.circle,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// .nav-search-in  --  @keyframes rtc-navSearchIn
// La pildora compacta que aparece en el navbar cuando el buscador grande ya
// se fue hacia arriba: baja 8px y crece de .96 a 1 en 280ms.
// ---------------------------------------------------------------------------

class RtcNavSearchIn extends StatelessWidget {
  const RtcNavSearchIn({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _Entrance(
      duration: RtcDur.navSearchIn,
      curve: RtcCurves.smooth,
      builder: (t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, -8 * (1 - t)),
          child: Transform.scale(scale: 0.96 + 0.04 * t, child: child),
        ),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// .animate-pulse  --  el esqueleto de carga de Tailwind
//
//   @keyframes pulse { 0%, 100% { opacity: 1 } 50% { opacity: .5 } }
//   animation: pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite;
//
// Es lo que usan los skeletonGrid de /empresas y el fallback de Suspense.
// ---------------------------------------------------------------------------

class RtcSkeletonPulse extends StatefulWidget {
  const RtcSkeletonPulse({super.key, required this.child});

  final Widget child;

  @override
  State<RtcSkeletonPulse> createState() => _RtcSkeletonPulseState();
}

class _RtcSkeletonPulseState extends State<RtcSkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  /// El ciclo de CSS va 1 → .5 → 1, o sea ida y vuelta dentro de los 2s.
  static const _curve = Cubic(0.4, 0, 0.6, 1);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // 0 → .5 baja, .5 → 1 sube: el triangulo del keyframe.
        final phase = t <= 0.5 ? t * 2 : (1 - t) * 2;
        return Opacity(
          opacity: 1 - 0.5 * _curve.transform(phase),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// fade(delay)  --  la entrada escalonada de /auth/login
//
//   initial:    { opacity: 0, y: 12 }
//   animate:    { opacity: 1, y: 0 }
//   transition: { duration: 0.45, ease: [0.22, 1, 0.36, 1], delay }
//
// No es la misma que RtcFadeUp (.rtc-fade): esa sube 16px en su propia
// duracion y con el ease del reveal on scroll.
// ---------------------------------------------------------------------------

class RtcFormFadeIn extends StatelessWidget {
  const RtcFormFadeIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return _Entrance(
      duration: const Duration(milliseconds: 450),
      curve: RtcCurves.framerExpo,
      delay: delay,
      builder: (t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------------------
// .rtc-chat-chip / .rtc-chat-chip-out  --  las opciones del asistente
//
//   @keyframes rtc-chatChipIn  { from { opacity:0; translateY(10px) } }
//   @keyframes rtc-chatChipOut { to { opacity:0; translateY(-6px) scale(.96) } }
//   .rtc-chat-chip     { .3s cubic-bezier(.16,1,.3,1) backwards }
//   .rtc-chat-chip-out { .16s ease-in both }
//
// El escalonado tambien es distinto segun el sentido: 55ms al entrar y 22ms al
// salir (`animationDelay` en SupportChat.tsx).
// ---------------------------------------------------------------------------

class RtcChatChipIn extends StatelessWidget {
  const RtcChatChipIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    return _Entrance(
      duration: const Duration(milliseconds: 300),
      curve: RtcCurves.expoOut,
      delay: delay,
      builder: (t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

class RtcChatChipOut extends StatefulWidget {
  const RtcChatChipOut({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  State<RtcChatChipOut> createState() => _RtcChatChipOutState();
}

class _RtcChatChipOutState extends State<RtcChatChipOut>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
  );

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _c.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _c.forward();
      });
    }
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
        final t = Curves.easeIn.transform(_c.value);
        return Opacity(
          opacity: 1 - t,
          child: Transform.translate(
            offset: Offset(0, -6 * t),
            child: Transform.scale(scale: 1 - 0.04 * t, child: child),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// .rtc-chat-in / .rtc-chat-out  --  el panel del asistente
//
//   @keyframes rtc-chatPanelIn  { from { opacity:0; translateY(28px) scale(.92) } }
//   @keyframes rtc-chatPanelOut { to   { opacity:0; translateY(18px) scale(.94) } }
//   .rtc-chat-in  { .4s cubic-bezier(.16,1,.3,1) }
//   .rtc-chat-out { .22s cubic-bezier(.4,0,1,1) }
//
// `transform-origin: bottom right`: el panel crece desde la esquina del FAB.
// ---------------------------------------------------------------------------

class RtcChatPanel extends StatefulWidget {
  const RtcChatPanel({super.key, required this.child, required this.cerrando});

  final Widget child;

  /// Cuando pasa a true corre la salida; el que lo monta espera 220ms antes
  /// de desmontarlo.
  final bool cerrando;

  @override
  State<RtcChatPanel> createState() => _RtcChatPanelState();
}

class _RtcChatPanelState extends State<RtcChatPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )..forward();

  @override
  void didUpdateWidget(RtcChatPanel old) {
    super.didUpdateWidget(old);
    if (widget.cerrando && !old.cerrando) {
      _c.duration = const Duration(milliseconds: 220);
      _c.reverse(from: 1);
    }
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
        // La entrada usa el expo del sitio; la salida su propia curva.
        final t = widget.cerrando
            ? const Cubic(0.4, 0, 1, 1).transform(1 - _c.value)
            : RtcCurves.expoOut.transform(_c.value);
        final desplazamiento = widget.cerrando ? 18.0 * t : 28.0 * (1 - t);
        final escala = widget.cerrando ? 1 - 0.06 * t : 0.92 + 0.08 * t;
        return Opacity(
          opacity: widget.cerrando ? 1 - t : t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, desplazamiento),
            child: Transform.scale(
              scale: escala,
              // transform-origin: bottom right
              alignment: Alignment.bottomRight,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
