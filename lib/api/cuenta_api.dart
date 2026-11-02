/// Recuperar y cambiar la contraseña, y entrar con Google. Viven bajo
/// `/cuenta` en el NestJS (no `/auth`, que en producción contesta el Next).
library;

import 'rtc_api.dart';

class CuentaApi {
  const CuentaApi();

  /// `POST /cuenta/olvide`. Responde igual exista o no la cuenta.
  Future<void> olvide(String email) =>
      RtcApi.instance.post('/cuenta/olvide', body: {'email': email.trim()});

  /// `POST /cuenta/restablecer` — con el token del enlace del correo.
  Future<void> restablecer(String token, String clave) => RtcApi.instance.post(
    '/cuenta/restablecer',
    body: {'token': token, 'clave': clave},
  );

  /// `POST /cuenta/clave` — desde el panel, con la contraseña actual.
  Future<void> cambiarClave(String actual, String nueva) =>
      RtcApi.instance.post(
        '/cuenta/clave',
        body: {'actual': actual, 'nueva': nueva},
        auth: true,
      );
}

const cuentaApi = CuentaApi();

/// Las mismas reglas que valida el backend (`CuentaService.validarClave`).
List<(bool, String)> reglasClave(String clave) => [
  (clave.length >= 8, 'Al menos 8 caracteres'),
  (
    RegExp(r'[A-Za-zÁÉÍÓÚáéíóúÑñ]').hasMatch(clave) &&
        RegExp(r'\d').hasMatch(clave),
    'Letras y números',
  ),
];

bool claveValida(String clave) => reglasClave(clave).every((r) => r.$1);
