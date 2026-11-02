import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../theme/motion.dart';
import '../theme/palette.dart';
import '../theme/shadows.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Port de `Frontend/src/components/ui/PillTabs.tsx`.
///
/// La pildora verde se desliza de una pestaña a otra con el mismo resorte de
/// framer-motion (`stiffness: 420, damping: 34`). Como las pestañas tienen
/// anchos distintos y pueden ocupar dos filas, se calculan sus rectangulos a
/// mano y la pildora interpola entre ellos — que es lo que hace `layoutId`.
class PillTabs extends StatefulWidget {
  const PillTabs({
    super.key,
    required this.tabs,
    required this.active,
    required this.onChange,
  });

  final List<String> tabs;
  final String active;
  final ValueChanged<String> onChange;

  @override
  State<PillTabs> createState() => _PillTabsState();
}

class _PillTabsState extends State<PillTabs>
    with SingleTickerProviderStateMixin {
  static const _gap = RtcSpace.s2;
  static const _height = 38.0;

  late final AnimationController _c = AnimationController.unbounded(
    vsync: this,
    value: 1,
  );

  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 420,
    damping: 34,
  );

  Rect? _from;
  Rect? _to;
  String? _pressed;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _moveTo(Rect target) {
    if (_to == target) return;
    _from = _to == null ? target : _rectNow();
    _to = target;
    _c.value = 0;
    _c.animateWith(SpringSimulation(_spring, 0, 1, 0));
  }

  Rect _rectNow() {
    if (_from == null || _to == null) return _to ?? Rect.zero;
    return Rect.lerp(_from!, _to!, _c.value.clamp(0.0, 1.0))!;
  }

  TextStyle get _style => RtcType.sm.copyWith(fontWeight: RtcType.bold);

  double _tabWidth(String label) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: _style),
      textDirection: TextDirection.ltr,
    )..layout();
    // px-5 a cada lado mas el borde de 2px.
    return painter.width + RtcSpace.s5 * 2 + 4;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Reparto en filas igual que `flex-wrap`, y centro cada fila.
        final widths = {for (final t in widget.tabs) t: _tabWidth(t)};
        final rows = <List<String>>[[]];
        var used = 0.0;
        for (final t in widget.tabs) {
          final w = widths[t]!;
          final extra = rows.last.isEmpty ? w : w + _gap;
          if (used + extra > constraints.maxWidth && rows.last.isNotEmpty) {
            rows.add([t]);
            used = w;
          } else {
            rows.last.add(t);
            used += extra;
          }
        }

        final rects = <String, Rect>{};
        for (var r = 0; r < rows.length; r++) {
          final rowWidth =
              rows[r].fold<double>(0, (a, t) => a + widths[t]!) +
              _gap * (rows[r].length - 1);
          var x = (constraints.maxWidth - rowWidth) / 2;
          final y = r * (_height + _gap);
          for (final t in rows[r]) {
            rects[t] = Rect.fromLTWH(x, y, widths[t]!, _height);
            x += widths[t]! + _gap;
          }
        }

        final target = rects[widget.active];
        if (target != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _moveTo(target);
          });
        }

        return SizedBox(
          height: rows.length * _height + (rows.length - 1) * _gap,
          child: Stack(
            children: [
              // La pildora verde, detras de las etiquetas.
              AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final r = _rectNow();
                  if (r == Rect.zero) return const SizedBox.shrink();
                  // `-inset-[2px]`: sobresale 2px del boton.
                  return Positioned(
                    left: r.left - 2,
                    top: r.top - 2,
                    width: r.width + 4,
                    height: r.height + 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Green.c600,
                        borderRadius: RtcRadius.brFull,
                        boxShadow: [
                          cssShadow(
                            dy: 10,
                            blur: 15,
                            color: Green.c600.withValues(alpha: 0.25),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              for (final entry in rects.entries)
                Positioned.fromRect(
                  rect: entry.value,
                  child: _Tab(
                    label: entry.key,
                    active: entry.key == widget.active,
                    pressed: _pressed == entry.key,
                    style: _style,
                    onTapDown: () => setState(() => _pressed = entry.key),
                    onTapEnd: () => setState(() => _pressed = null),
                    onTap: () => widget.onChange(entry.key),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.active,
    required this.pressed,
    required this.style,
    required this.onTap,
    required this.onTapDown,
    required this.onTapEnd,
  });

  final String label;
  final bool active;
  final bool pressed;
  final TextStyle style;
  final VoidCallback onTap;
  final VoidCallback onTapDown;
  final VoidCallback onTapEnd;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onTapDown: (_) => onTapDown(),
      onTapUp: (_) => onTapEnd(),
      onTapCancel: onTapEnd,
      child: AnimatedScale(
        // whileTap: { scale: 0.95 }
        scale: pressed ? 0.95 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300), // duration-300
          curve: RtcCurves.ease,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // El fondo blanco solo se ve cuando la pildora no esta encima.
            color: active ? Colors.transparent : Superficie.tarjeta,
            borderRadius: RtcRadius.brFull,
            border: Border.all(
              color: active ? Green.c600 : Gray.c200,
              width: 2,
            ),
          ),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: style.copyWith(color: active ? Colors.white : Gray.c500),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}
