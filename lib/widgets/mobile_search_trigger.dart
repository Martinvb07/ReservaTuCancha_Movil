import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/palette.dart';
import '../theme/shadows.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Port de `Frontend/src/components/home/MobileSearchTrigger.tsx`.
///
/// La pildora del hero que abre el buscador completo. En la web el
/// `active:scale-[.99]` da el feedback al tocar; aca es un AnimatedScale.
class MobileSearchTrigger extends StatefulWidget {
  const MobileSearchTrigger({
    super.key,
    required this.onTap,
    this.suave = false,
  });

  final VoidCallback onTap;

  /// Sobre el fondo claro de la app la sombra fuerte (pensada para ir encima
  /// de una foto) se ve sucia: con esto queda apenas marcada.
  final bool suave;

  @override
  State<MobileSearchTrigger> createState() => _MobileSearchTriggerState();
}

class _MobileSearchTriggerState extends State<MobileSearchTrigger> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.99 : 1,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: RtcSpace.s4,
            vertical: 14, // py-3.5
          ),
          decoration: BoxDecoration(
            color: Superficie.tarjeta,
            borderRadius: RtcRadius.brXxl,
            // boxShadow: '0 10px 30px rgba(0,0,0,.24)' — inline en el TSX
            boxShadow: [
              cssShadow(
                dy: widget.suave ? 6 : 10,
                blur: widget.suave ? 20 : 30,
                color: Colors.black.withValues(
                  alpha: widget.suave ? 0.07 : 0.24,
                ),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Green.c600,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.search,
                  size: 17,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: RtcSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '¿Listo para jugar?',
                      style: RtcType.sm.copyWith(
                        fontWeight: RtcType.bold,
                        color: Gray.c900,
                        height: 1.25,
                      ),
                    ),
                    Text(
                      'Deporte · Ciudad · Fecha · Hora',
                      style: RtcType.smAlt.copyWith(
                        color: Gray.c500,
                        height: 1.25,
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
