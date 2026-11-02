import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/cuenta_api.dart';
import '../../api/rtc_api.dart';
import '../../app/routes.dart';
import '../../auth/session.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/rtc_toast.dart';
import '../cuenta/formulario_cuenta.dart';

/// Mi cuenta: cambiar la contraseña. Si entró con la temporal del correo, el
/// panel lo trae acá primero (ver `rtcIrAlPanel`).
class CuentaScreen extends StatefulWidget {
  const CuentaScreen({super.key});

  @override
  State<CuentaScreen> createState() => _CuentaScreenState();
}

class _CuentaScreenState extends State<CuentaScreen> {
  final _actual = TextEditingController();
  final _clave = TextEditingController();
  final _repetir = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _actual.dispose();
    _clave.dispose();
    _repetir.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    final obligatorio = RtcSession.instance.user?.debeCambiarClave == true;
    setState(() => _guardando = true);
    try {
      await cuentaApi.cambiarClave(_actual.text, _clave.text);
      await RtcSession.instance.marcarClaveCambiada();
      if (!mounted) return;
      rtcToast(context, 'Contraseña actualizada');
      _actual.clear();
      _clave.clear();
      _repetir.clear();
      if (obligatorio) rtcIrAlPanel('/dashboard');
    } on RtcApiException catch (e) {
      if (!mounted) return;
      rtcToast(context, e.message, tipo: RtcToastTipo.error);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = RtcSession.instance.user;
    final obligatorio = user?.debeCambiarClave == true;
    final lista = _actual.text.isNotEmpty && claveNuevaLista(_clave, _repetir);

    return ListView(
      padding: const EdgeInsets.only(bottom: RtcSpace.s12),
      children: [
        Text(
          'Mi cuenta',
          style: RtcType.xl3.copyWith(
            fontWeight: FontWeight.w900,
            color: Gray.c900,
          ),
        ),
        const SizedBox(height: 4),
        Text(user?.email ?? '', style: RtcType.sm.copyWith(color: Gray.c500)),
        const SizedBox(height: RtcSpace.s5),
        if (obligatorio) ...[
          Container(
            padding: const EdgeInsets.all(RtcSpace.s4),
            decoration: BoxDecoration(
              color: Amber.c50,
              borderRadius: RtcRadius.brXl,
              border: Border.all(color: Amber.c200),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  LucideIcons.shieldAlert,
                  color: Amber.c600,
                  size: 20,
                ),
                const SizedBox(width: RtcSpace.s3),
                Expanded(
                  child: Text(
                    'Entraste con la contraseña temporal que te llegó por correo. Elige una tuya para seguir usando el panel.',
                    style: RtcType.sm.copyWith(color: Amber.c900),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: RtcSpace.s5),
        ],
        Container(
          padding: const EdgeInsets.all(RtcSpace.s5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: RtcRadius.brXxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.keyRound, size: 18, color: Green.c600),
                  const SizedBox(width: RtcSpace.s2),
                  Text(
                    'Cambiar contraseña',
                    style: RtcType.sm.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Gray.c900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: RtcSpace.s4),
              etiquetaCuenta(
                obligatorio
                    ? 'Contraseña temporal (la del correo)'
                    : 'Contraseña actual',
              ),
              TextField(
                controller: _actual,
                obscureText: true,
                autofillHints: const [AutofillHints.password],
                onChanged: (_) => setState(() {}),
                decoration: decoCuenta(''),
              ),
              const SizedBox(height: RtcSpace.s4),
              CamposClaveNueva(
                clave: _clave,
                repetir: _repetir,
                onCambio: () => setState(() {}),
              ),
              const SizedBox(height: RtcSpace.s5),
              botonCuenta(
                _guardando ? 'Guardando…' : 'Guardar contraseña',
                lista && !_guardando ? _guardar : null,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
