import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/cuenta_api.dart';
import '../../api/rtc_api.dart';
import '../../app/routes.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'formulario_cuenta.dart';

/// Se abre desde el enlace del correo (`/auth/restablecer?token=`).
class RestablecerScreen extends StatefulWidget {
  const RestablecerScreen({super.key, required this.token});

  final String token;

  @override
  State<RestablecerScreen> createState() => _RestablecerScreenState();
}

class _RestablecerScreenState extends State<RestablecerScreen> {
  final _clave = TextEditingController();
  final _repetir = TextEditingController();
  bool _guardando = false;
  bool _listo = false;
  String? _error;

  @override
  void dispose() {
    _clave.dispose();
    _repetir.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await cuentaApi.restablecer(widget.token, _clave.text);
      if (!mounted) return;
      setState(() => _listo = true);
    } on RtcApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lista = claveNuevaLista(_clave, _repetir);
    return MarcoCuenta(
      titulo: 'Elige tu contraseña nueva',
      subtitulo:
          'Al guardarla se cierran las sesiones abiertas en otros equipos.',
      children: _listo
          ? [
              Row(
                children: [
                  const Icon(LucideIcons.circleCheck, color: Green.c600),
                  const SizedBox(width: RtcSpace.s2),
                  Expanded(
                    child: Text(
                      'Listo, ya puedes entrar con tu contraseña nueva.',
                      style: RtcType.sm.copyWith(
                        color: Green.c900,
                        fontWeight: RtcType.semibold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RtcSpace.s5),
              botonCuenta('Iniciar sesión', () => rtcNavigate('/auth/login')),
            ]
          : [
              CamposClaveNueva(
                clave: _clave,
                repetir: _repetir,
                onCambio: () => setState(() {}),
              ),
              if (_error != null) ...[
                const SizedBox(height: RtcSpace.s3),
                Text(_error!, style: RtcType.sm.copyWith(color: Red.c600)),
                if (_error!.contains('venció'))
                  TextButton(
                    onPressed: () => rtcNavigate('/auth/olvide'),
                    child: const Text('Pedir un enlace nuevo'),
                  ),
              ],
              const SizedBox(height: RtcSpace.s5),
              botonCuenta(
                _guardando ? 'Guardando…' : 'Guardar contraseña',
                lista && !_guardando ? _guardar : null,
              ),
            ],
    );
  }
}
