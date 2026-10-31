import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/motion.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Port de `Frontend/src/components/ui/FaqAccordion.tsx`.
///
/// Los items entran escalonados cada 60ms desde 14px abajo, el chevron gira
/// 90 grados con un resorte y la respuesta se despliega en alto (340ms) con
/// la opacidad terminando antes (220ms).
class FaqItem {
  const FaqItem(this.question, this.answer);

  final String question;
  final String answer;
}

class FaqAccordion extends StatefulWidget {
  const FaqAccordion({super.key, required this.items, this.resetKey});

  final List<FaqItem> items;

  /// Al cambiar, la lista se reanima y se cierra la pregunta abierta.
  final Object? resetKey;

  @override
  State<FaqAccordion> createState() => _FaqAccordionState();
}

class _FaqAccordionState extends State<FaqAccordion> {
  int? _open;

  @override
  void didUpdateWidget(FaqAccordion old) {
    super.didUpdateWidget(old);
    if (widget.resetKey != old.resetKey) _open = null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey(widget.resetKey),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: RtcSpace.s3), // space-y-3
            child: _FaqEntry(
              // staggerChildren: 0.06
              delay: Duration(milliseconds: i * 60),
              item: widget.items[i],
              open: _open == i,
              onTap: () => setState(() => _open = _open == i ? null : i),
            ),
          ),
      ],
    );
  }
}

class _FaqEntry extends StatefulWidget {
  const _FaqEntry({
    required this.item,
    required this.open,
    required this.onTap,
    required this.delay,
  });

  final FaqItem item;
  final bool open;
  final VoidCallback onTap;
  final Duration delay;

  @override
  State<_FaqEntry> createState() => _FaqEntryState();
}

class _FaqEntryState extends State<_FaqEntry> with TickerProviderStateMixin {
  /// Entrada del item: opacity 0 y 14 -> 0, 400ms con el ease de framer.
  late final AnimationController _in = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  /// Despliegue de la respuesta.
  late final AnimationController _panel = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
    value: widget.open ? 1 : 0,
  );

  /// Giro del chevron, con resorte (stiffness 500, damping 28).
  late final AnimationController _chevron = AnimationController.unbounded(
    vsync: this,
    value: widget.open ? 1 : 0,
  );

  static const _chevronSpring = SpringDescription(
    mass: 1,
    stiffness: 500,
    damping: 28,
  );

  bool _pressed = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.delay, () {
      if (mounted) _in.forward();
    });
  }

  @override
  void didUpdateWidget(_FaqEntry old) {
    super.didUpdateWidget(old);
    if (widget.open != old.open) {
      widget.open ? _panel.forward() : _panel.reverse();
      _chevron.animateWith(
        SpringSimulation(
          _chevronSpring,
          _chevron.value,
          widget.open ? 1 : 0,
          0,
        ),
      );
    }
  }

  @override
  void dispose() {
    _in.dispose();
    _panel.dispose();
    _chevron.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final height = CurvedAnimation(parent: _panel, curve: RtcCurves.framerExpo);
    // La opacidad termina antes que el alto: 220 de 340.
    final fade = CurvedAnimation(
      parent: _panel,
      curve: const Interval(0, 220 / 340),
    );

    final card = GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        // whileTap: { scale: 0.99 }
        scale: _pressed ? 0.99 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: RtcCurves.ease,
          padding: const EdgeInsets.all(RtcSpace.s5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: RtcRadius.brXxl,
            border: Border.all(
              color: widget.open ? const Color(0xFF86EFAC) : Gray.c100,
            ),
            // shadow-[0_14px_40px_-20px_rgba(22,163,74,0.55)]
            boxShadow: widget.open
                ? [
                    BoxShadow(
                      color: Green.c600.withValues(alpha: 0.55),
                      offset: const Offset(0, 14),
                      blurRadius: 34,
                      spreadRadius: -20,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      widget.item.question,
                      style: RtcType.sm.copyWith(
                        fontWeight: RtcType.bold,
                        color: Gray.c800,
                      ),
                    ),
                  ),
                  const SizedBox(width: RtcSpace.s3),
                  AnimatedBuilder(
                    animation: _chevron,
                    builder: (context, child) => Transform.rotate(
                      angle: _chevron.value * 1.5707963, // 90 grados
                      child: child,
                    ),
                    child: Icon(
                      LucideIcons.chevronRight,
                      size: 20,
                      color: widget.open
                          ? const Color(0xFF22C55E) // green-500
                          : Gray.c400,
                    ),
                  ),
                ],
              ),
              SizeTransition(
                sizeFactor: height,
                alignment: Alignment.topCenter,
                child: FadeTransition(
                  opacity: fade,
                  child: Padding(
                    padding: const EdgeInsets.only(top: RtcSpace.s3),
                    child: Text(
                      widget.item.answer,
                      style: RtcType.sm.copyWith(
                        color: Gray.c500,
                        height: 1.625, // leading-relaxed
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (rtcReducedMotion(context)) return card;

    return AnimatedBuilder(
      animation: _in,
      child: card,
      builder: (context, child) {
        final t = RtcCurves.framerExpo.transform(_in.value);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}
