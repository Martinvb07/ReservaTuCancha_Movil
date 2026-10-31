import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/motion.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Port de `Frontend/src/components/ui/StepWizard.tsx`.
///
/// Cabecera con stepper y contenedor animado del paso actual. Quien lo usa se
/// encarga del formulario y de los botones de navegacion.
class WizardStep {
  const WizardStep({required this.title, this.hint});

  final String title;
  final String? hint;
}

class StepWizard extends StatelessWidget {
  const StepWizard({
    super.key,
    required this.steps,
    required this.step,
    required this.dir,
    required this.child,
    this.onGoTo,
  });

  final List<WizardStep> steps;
  final int step;

  /// 1 = avanzando, -1 = retrocediendo: define hacia donde se desliza el paso.
  final int dir;

  /// Si se pasa, el stepper deja volver a un paso ya completado.
  final ValueChanged<int>? onGoTo;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Stepper ────────────────────────────────────────────────────
        Row(
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              _StepDot(
                index: i,
                done: i < step,
                current: i == step,
                onTap: i < step && onGoTo != null ? () => onGoTo!(i) : null,
              ),
              if (i < steps.length - 1)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: RtcSpace.s2),
                    decoration: BoxDecoration(
                      color: Gray.c200,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 400),
                      curve: RtcCurves.framerExpo,
                      widthFactor: i < step ? 1 : 0,
                      alignment: Alignment.centerLeft,
                      child: const ColoredBox(color: Green.c600),
                    ),
                  ),
                ),
            ],
          ],
        ),
        const SizedBox(height: RtcSpace.s6),

        Text(
          'PASO ${step + 1} DE ${steps.length}',
          style: RtcType.xs.copyWith(
            fontWeight: RtcType.bold,
            color: Green.c600,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: RtcSpace.s1),
        Text(
          steps[step].title,
          style: RtcType.xl2.copyWith(
            fontWeight: FontWeight.w900,
            color: Gray.c900,
          ),
        ),
        if (steps[step].hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              steps[step].hint!,
              style: RtcType.sm.copyWith(color: Gray.c500),
            ),
          ),
        const SizedBox(height: RtcSpace.s8),

        // ── Paso actual ────────────────────────────────────────────────
        // El alto se anima de verdad (300ms): con `layout` los campos se
        // deformarian mientras dura la transicion.
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: RtcCurves.framerExpo,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: RtcCurves.framerExpo,
            switchOutCurve: RtcCurves.framerExpo,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [...previous, ?current],
            ),
            transitionBuilder: (c, anim) {
              // El que entra viene de dir*48; el que sale se va a -dir*48.
              final incoming = (c.key as ValueKey<int>?)?.value == step;
              final dx = (incoming ? dir : -dir) * 48.0;
              return FadeTransition(
                opacity: anim,
                child: AnimatedBuilder(
                  animation: anim,
                  builder: (context, inner) => Transform.translate(
                    offset: Offset(dx * (1 - anim.value), 0),
                    child: inner,
                  ),
                  child: c,
                ),
              );
            },
            child: KeyedSubtree(key: ValueKey(step), child: child),
          ),
        ),
      ],
    );
  }
}

class _StepDot extends StatefulWidget {
  const _StepDot({
    required this.index,
    required this.done,
    required this.current,
    required this.onTap,
  });

  final int index;
  final bool done;
  final bool current;
  final VoidCallback? onTap;

  @override
  State<_StepDot> createState() => _StepDotState();
}

class _StepDotState extends State<_StepDot>
    with SingleTickerProviderStateMixin {
  /// `animate={{ scale: current ? 1.1 : 1 }}` con resorte 400/22.
  late final AnimationController _c = AnimationController.unbounded(
    vsync: this,
    value: widget.current ? 1 : 0,
  );

  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 400,
    damping: 22,
  );

  @override
  void didUpdateWidget(_StepDot old) {
    super.didUpdateWidget(old);
    if (widget.current != old.current) {
      _c.animateWith(
        SpringSimulation(_spring, _c.value, widget.current ? 1 : 0, 0),
      );
    }
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
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) =>
            Transform.scale(scale: 1 + 0.1 * _c.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.done
                ? Green.c600
                : widget.current
                ? Gray.c900
                : Colors.white,
            shape: BoxShape.circle,
            border: !widget.done && !widget.current
                ? Border.all(color: Gray.c200)
                : null,
            // ring-4 ring-gray-900/10 del paso actual
            boxShadow: widget.current
                ? [
                    BoxShadow(
                      color: Gray.c900.withValues(alpha: 0.10),
                      spreadRadius: 4,
                    ),
                  ]
                : null,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (c, anim) => ScaleTransition(
              scale: anim,
              child: FadeTransition(opacity: anim, child: c),
            ),
            child: widget.done
                ? const Icon(
                    LucideIcons.check,
                    key: ValueKey('check'),
                    size: 16,
                    color: Colors.white,
                  )
                : Text(
                    '${widget.index + 1}',
                    key: const ValueKey('num'),
                    style: RtcType.sm.copyWith(
                      fontWeight: FontWeight.w900,
                      color: widget.current ? Colors.white : Gray.c400,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
