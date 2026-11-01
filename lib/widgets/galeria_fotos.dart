import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/typography.dart';
import 'remote_image.dart';
import 'motion/rtc_pressable.dart';

/// Abre las fotos a pantalla completa, sobre negro: se pasan con el dedo y
/// se acercan con dos dedos.
Future<void> abrirGaleria(
  BuildContext context, {
  required List<String> fotos,
  int inicial = 0,
  String? sport,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) =>
          _Galeria(fotos: fotos, inicial: inicial, sport: sport),
      transitionsBuilder: (_, animacion, _, hijo) =>
          FadeTransition(opacity: animacion, child: hijo),
    ),
  );
}

class _Galeria extends StatefulWidget {
  const _Galeria({required this.fotos, required this.inicial, this.sport});

  final List<String> fotos;
  final int inicial;
  final String? sport;

  @override
  State<_Galeria> createState() => _GaleriaState();
}

class _GaleriaState extends State<_Galeria> {
  late final _controller = PageController(initialPage: widget.inicial);
  late int _actual = widget.inicial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arriba = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.fotos.length,
            onPageChanged: (i) => setState(() => _actual = i),
            itemBuilder: (_, i) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: RemoteImage(
                  url: widget.fotos[i],
                  sport: widget.sport,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            top: arriba + 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Semantics(
                  button: true,
                  label: 'Cerrar',
                  child: RtcPressable(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.x,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${_actual + 1} / ${widget.fotos.length}',
                  style: RtcType.sm.copyWith(
                    color: Colors.white,
                    fontWeight: RtcType.semibold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
