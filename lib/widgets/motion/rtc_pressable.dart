import 'package:flutter/widgets.dart';

/// Un `GestureDetector` que se nota al tocarlo.
///
/// El `GestureDetector` pelado no da ninguna señal: el dedo baja y no pasa
/// nada hasta que la acción termina, y parece que el toque no entró. Este se
/// encoge y se aclara un poco mientras el dedo está encima, como los botones
/// nativos, y se anuncia como botón a los lectores de pantalla.
///
/// Mismos parámetros que el `GestureDetector` para `onTap`: es un reemplazo
/// directo. Si `onTap` es null no hay efecto (el elemento está deshabilitado).
class RtcPressable extends StatefulWidget {
  const RtcPressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.behavior,
    this.excludeFromSemantics = false,
    this.semanticLabel,
  });

  final Widget child;
  final GestureTapCallback? onTap;
  final GestureLongPressCallback? onLongPress;
  final HitTestBehavior? behavior;
  final bool excludeFromSemantics;
  final String? semanticLabel;

  @override
  State<RtcPressable> createState() => _RtcPressableState();
}

class _RtcPressableState extends State<RtcPressable> {
  bool _presionado = false;

  bool get _activo => widget.onTap != null || widget.onLongPress != null;

  void _poner(bool v) {
    if (_presionado != v && mounted) setState(() => _presionado = v);
  }

  @override
  Widget build(BuildContext context) {
    Widget hijo = AnimatedScale(
      scale: _presionado ? 0.97 : 1,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: AnimatedOpacity(
        opacity: _presionado ? 0.7 : 1,
        duration: const Duration(milliseconds: 90),
        child: widget.child,
      ),
    );

    hijo = GestureDetector(
      behavior: widget.behavior,
      excludeFromSemantics: widget.excludeFromSemantics,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: _activo ? (_) => _poner(true) : null,
      onTapUp: _activo ? (_) => _poner(false) : null,
      onTapCancel: _activo ? () => _poner(false) : null,
      child: hijo,
    );

    if (widget.excludeFromSemantics || !_activo) return hijo;
    return Semantics(button: true, label: widget.semanticLabel, child: hijo);
  }
}
