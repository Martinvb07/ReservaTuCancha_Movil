import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/cuenta_api.dart';
import '../../api/rtc_api.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'formulario_cuenta.dart';

/// "¿Olvidaste tu contraseña?": manda el enlace de recuperación al correo.
class OlvideScreen extends StatefulWidget {
  const OlvideScreen({super.key});

  @override
  State<OlvideScreen> createState() => _OlvideScreenState();
}

class _OlvideScreenState extends State<OlvideScreen> {
  final _email = TextEditingController();
  bool _enviando = false;
  bool _enviado = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_email.text.contains('@')) {
      setState(() => _error = 'Escribe el correo de tu cuenta');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    try {
      await cuentaApi.olvide(_email.text);
      if (!mounted) return;
      setState(() => _enviado = true);
    } on RtcApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MarcoCuenta(
      titulo: 'Recupera tu contraseña',
      subtitulo:
          'Escribe el correo de tu cuenta del panel y te mandamos un enlace para elegir una nueva.',
      children: _enviado
          ? [
              Container(
                padding: const EdgeInsets.all(RtcSpace.s4),
                decoration: BoxDecoration(
                  color: Green.c50,
                  borderRadius: RtcRadius.brXl,
                  border: Border.all(color: Green.c200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      LucideIcons.mailCheck,
                      color: Green.c600,
                      size: 20,
                    ),
                    const SizedBox(width: RtcSpace.s3),
                    Expanded(
                      child: Text(
                        'Te mandamos un enlace a ${_email.text.trim()} que sirve durante 1 hora. Si no lo ves, mira en spam.',
                        style: RtcType.sm.copyWith(color: Green.c900),
                      ),
                    ),
                  ],
                ),
              ),
            ]
          : [
              etiquetaCuenta('Correo'),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                decoration: decoCuenta('propietario@email.com'),
                onSubmitted: (_) => _enviar(),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _error!,
                    style: RtcType.xs.copyWith(color: Red.c600),
                  ),
                ),
              const SizedBox(height: RtcSpace.s5),
              botonCuenta(
                _enviando ? 'Enviando…' : 'Enviarme el enlace',
                _enviando ? null : _enviar,
              ),
            ],
    );
  }
}
