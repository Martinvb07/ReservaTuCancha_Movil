import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/motion.dart';
import '../theme/palette.dart';
import '../theme/shadows.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'motion/rtc_motion.dart';
import 'motion/rtc_pressable.dart';

/// Port de `Frontend/src/components/ui/MobileStackSheet.tsx`.
///
/// Sheet a pantalla completa con secciones apiladas estilo Airbnb: la seccion
/// activa es una tarjeta grande con su titulo y las demas quedan como filas
/// colapsadas con su valor a la derecha. Es el mismo lenguaje de movimiento
/// que el buscador movil, extraido para que filtros y busqueda no se sientan
/// como dos cosas distintas.
class StackSection {
  const StackSection({
    required this.key,
    required this.title,
    required this.label,
    required this.value,
    required this.content,
    this.filled = false,
  });

  final String key;

  /// Titulo grande de la tarjeta cuando la seccion esta abierta.
  final String title;

  /// Etiqueta de la fila cuando esta colapsada.
  final String label;

  /// Valor que se muestra a la derecha al estar colapsada.
  final String value;

  /// Pinta el valor en oscuro (hay algo elegido) en vez de gris.
  final bool filled;

  final Widget content;
}

Future<void> showMobileStackSheet({
  required BuildContext context,
  required List<StackSection> Function(void Function(VoidCallback)) sections,
  required String? initialSection,
  Widget Function(void Function(VoidCallback) setState)? footer,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    barrierColor: Colors.transparent,
    transitionDuration: RtcDur.sheetIn,
    pageBuilder: (_, _, _) => _MobileStackSheet(
      sections: sections,
      initialSection: initialSection,
      footer: footer,
    ),
    transitionBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class _MobileStackSheet extends StatefulWidget {
  const _MobileStackSheet({
    required this.sections,
    required this.initialSection,
    required this.footer,
  });

  final List<StackSection> Function(void Function(VoidCallback)) sections;
  final String? initialSection;
  final Widget Function(void Function(VoidCallback))? footer;

  @override
  State<_MobileStackSheet> createState() => _MobileStackSheetState();
}

class _MobileStackSheetState extends State<_MobileStackSheet> {
  late String? _active = widget.initialSection;

  @override
  Widget build(BuildContext context) {
    final sections = widget.sections(setState);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // Fondo: la pagina detras, difuminada y atenuada. Tocarlo cierra.
          Positioned.fill(
            child: RtcPressable(
              onTap: () => Navigator.of(context).pop(),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s4),
              child: ListView(
                padding: const EdgeInsets.only(top: 72, bottom: 120),
                children: [
                  RtcStagger(
                    children: [
                      for (var i = 0; i < sections.length; i++) ...[
                        if (i > 0) const SizedBox(height: RtcSpace.s3),
                        StackSectionCard(
                          section: sections[i],
                          open: _active == sections[i].key,
                          onTap: () => setState(
                            () => _active = _active == sections[i].key
                                ? null
                                : sections[i].key,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (widget.footer != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: StackSheetFooter(child: widget.footer!(setState)),
            ),

          // Cerrar — circulo blanco de 44px arriba a la derecha
          Positioned(
            top: MediaQuery.paddingOf(context).top + 20,
            right: 20,
            child: RtcPressable(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Superficie.tarjeta,
                  shape: BoxShape.circle,
                  boxShadow: [
                    cssShadow(
                      dy: 4,
                      blur: 16,
                      color: Colors.black.withValues(alpha: 0.22),
                    ),
                  ],
                ),
                child: Icon(LucideIcons.x, size: 19, color: Gray.c800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Una seccion: fila colapsada con su valor, o tarjeta abierta con su titulo.
class StackSectionCard extends StatelessWidget {
  const StackSectionCard({
    super.key,
    required this.section,
    required this.open,
    required this.onTap,
  });

  final StackSection section;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!open) {
      // px-5 py-4, rounded-2xl, shadow '0 2px 16px rgba(20,14,30,.10)'
      return RtcPressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Superficie.tarjeta,
            borderRadius: RtcRadius.brXxl,
            boxShadow: [
              cssShadow(
                dy: 2,
                blur: 16,
                color: const Color(0xFF140E1E).withValues(alpha: 0.10),
              ),
            ],
          ),
          child: Row(
            children: [
              Text(
                section.label,
                style: RtcType.base.copyWith(fontSize: 15, color: Gray.c500),
              ),
              const SizedBox(width: RtcSpace.s4),
              Expanded(
                child: Text(
                  section.value,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RtcType.base.copyWith(
                    fontSize: 15,
                    fontWeight: RtcType.bold,
                    color: section.filled ? Gray.c900 : Gray.c400,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // rounded-3xl p-4, shadow '0 10px 36px rgba(20,14,30,.16)'
    return Container(
      padding: const EdgeInsets.all(RtcSpace.s4),
      decoration: BoxDecoration(
        color: Superficie.tarjeta,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          cssShadow(
            dy: 10,
            blur: 36,
            color: const Color(0xFF140E1E).withValues(alpha: 0.16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RtcPressable(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.only(left: RtcSpace.s1),
              child: Text(
                section.title,
                style: RtcType.xl2.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800, // font-extrabold
                  color: Gray.c900,
                ),
              ),
            ),
          ),
          const SizedBox(height: RtcSpace.s3),
          section.content,
        ],
      ),
    );
  }
}

/// Barra fija inferior del sheet.
class StackSheetFooter extends StatelessWidget {
  const StackSheetFooter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        14 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: Superficie.tarjeta,
        border: Border(top: BorderSide(color: Gray.c100)),
        boxShadow: [
          cssShadow(
            dy: -4,
            blur: 20,
            color: const Color(0xFF140E1E).withValues(alpha: 0.07),
          ),
        ],
      ),
      // El caller pasa la fila completa (Limpiar + accion), como en la web.
      child: child,
    );
  }
}

/// El boton verde del footer, con su sombra de marca.
class SheetPrimaryButton extends StatelessWidget {
  const SheetPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return RtcPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: Green.c600,
          borderRadius: RtcRadius.brXxl,
          boxShadow: [
            cssShadow(
              dy: 8,
              blur: 22,
              color: Green.c600.withValues(alpha: 0.42),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 17, color: Colors.white),
              const SizedBox(width: RtcSpace.s2),
            ],
            Text(
              label,
              style: RtcType.base.copyWith(
                fontSize: 15,
                fontWeight: RtcType.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// El "Limpiar" subrayado del footer.
class SheetClearButton extends StatelessWidget {
  const SheetClearButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RtcPressable(
      onTap: onTap,
      child: Text(
        'Limpiar',
        style: RtcType.base.copyWith(
          fontSize: 15,
          fontWeight: RtcType.bold,
          color: Gray.c900,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }
}
