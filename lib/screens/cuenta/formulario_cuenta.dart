import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/cuenta_api.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Piezas comunes de las pantallas de cuenta: campos, botón y reglas.
InputDecoration decoCuenta(String hint, {Widget? sufijo}) => InputDecoration(
  hintText: hint,
  isDense: true,
  filled: true,
  fillColor: Colors.white,
  suffixIcon: sufijo,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  border: OutlineInputBorder(
    borderRadius: RtcRadius.brXl,
    borderSide: const BorderSide(color: Gray.c200),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: RtcRadius.brXl,
    borderSide: const BorderSide(color: Gray.c200),
  ),
);

Widget etiquetaCuenta(String texto) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(
    texto,
    style: RtcType.xs.copyWith(fontWeight: RtcType.bold, color: Gray.c700),
  ),
);

Widget botonCuenta(String texto, VoidCallback? onTap) => FilledButton(
  style: FilledButton.styleFrom(
    backgroundColor: Green.c600,
    minimumSize: const Size.fromHeight(50),
    shape: RoundedRectangleBorder(borderRadius: RtcRadius.brXl),
  ),
  onPressed: onTap,
  child: Text(texto, style: const TextStyle(fontWeight: FontWeight.w700)),
);

/// Contraseña nueva + repetirla, con las reglas a la vista.
class CamposClaveNueva extends StatefulWidget {
  const CamposClaveNueva({
    super.key,
    required this.clave,
    required this.repetir,
    required this.onCambio,
  });

  final TextEditingController clave;
  final TextEditingController repetir;
  final VoidCallback onCambio;

  @override
  State<CamposClaveNueva> createState() => _CamposClaveNuevaState();
}

class _CamposClaveNuevaState extends State<CamposClaveNueva> {
  bool _ver = false;

  @override
  Widget build(BuildContext context) {
    final clave = widget.clave.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        etiquetaCuenta('Contraseña nueva'),
        TextField(
          controller: widget.clave,
          obscureText: !_ver,
          autofillHints: const [AutofillHints.newPassword],
          onChanged: (_) => widget.onCambio(),
          decoration: decoCuenta(
            '',
            sufijo: IconButton(
              tooltip: _ver ? 'Ocultar contraseña' : 'Mostrar contraseña',
              icon: Icon(
                _ver ? LucideIcons.eyeOff : LucideIcons.eye,
                size: 18,
                color: Gray.c500,
              ),
              onPressed: () => setState(() => _ver = !_ver),
            ),
          ),
        ),
        const SizedBox(height: 6),
        for (final (ok, texto) in reglasClave(clave))
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              children: [
                Icon(
                  LucideIcons.check,
                  size: 14,
                  color: ok ? Green.c600 : Gray.c300,
                ),
                const SizedBox(width: 6),
                Text(
                  texto,
                  style: RtcType.xs.copyWith(
                    color: ok ? Green.c700 : Gray.c500,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: RtcSpace.s4),
        etiquetaCuenta('Repítela'),
        TextField(
          controller: widget.repetir,
          obscureText: !_ver,
          onChanged: (_) => widget.onCambio(),
          decoration: decoCuenta(''),
        ),
        if (widget.repetir.text.isNotEmpty && widget.repetir.text != clave)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'No coinciden',
              style: RtcType.xs.copyWith(color: Red.c600),
            ),
          ),
      ],
    );
  }
}

bool claveNuevaLista(TextEditingController c, TextEditingController r) =>
    claveValida(c.text) && c.text == r.text;

/// Marco blanco con título de las pantallas de cuenta.
class MarcoCuenta extends StatelessWidget {
  const MarcoCuenta({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.children,
  });

  final String titulo;
  final String subtitulo;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(RtcSpace.s6),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(LucideIcons.arrowLeft, size: 16),
                label: const Text('Volver'),
                style: TextButton.styleFrom(foregroundColor: Gray.c600),
              ),
            ),
            const SizedBox(height: RtcSpace.s4),
            Text(
              titulo,
              style: RtcType.xl2.copyWith(
                fontWeight: FontWeight.w900,
                color: Gray.c900,
              ),
            ),
            const SizedBox(height: 6),
            Text(subtitulo, style: RtcType.sm.copyWith(color: Gray.c500)),
            const SizedBox(height: RtcSpace.s6),
            ...children,
          ],
        ),
      ),
    );
  }
}
