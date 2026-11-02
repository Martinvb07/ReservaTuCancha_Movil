/// Entrar al panel con Google.
///
/// Los IDs del cliente OAuth van en la build:
///
///   --dart-define=GOOGLE_SERVER_CLIENT_ID=ID_DEL_CLIENTE_WEB.apps.googleusercontent.com
///   --dart-define=GOOGLE_IOS_CLIENT_ID=ID_DEL_CLIENTE_IOS   (solo iPhone)
///
/// El ID token que devuelve Google lleva como audiencia el cliente Web, que es
/// el que el backend tiene en GOOGLE_CLIENT_IDS. Sin el dart-define el botón
/// no aparece.
library;

import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleLogin {
  GoogleLogin._();

  static const _serverClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );
  static const _iosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  static bool _iniciado = false;

  static bool get disponible =>
      _serverClientId.isNotEmpty &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          (defaultTargetPlatform == TargetPlatform.iOS &&
              _iosClientId.isNotEmpty));

  /// Abre el selector de cuentas de Google y devuelve el ID token, o null si
  /// la persona cerró el selector.
  static Future<String?> idToken() async {
    final google = GoogleSignIn.instance;
    if (!_iniciado) {
      await google.initialize(
        serverClientId: _serverClientId,
        clientId: _iosClientId.isEmpty ? null : _iosClientId,
      );
      _iniciado = true;
    }
    try {
      final cuenta = await google.authenticate();
      return cuenta.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  /// Al cerrar sesión, para que la próxima vez vuelva a preguntar la cuenta.
  static Future<void> salir() async {
    if (!_iniciado) return;
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}
