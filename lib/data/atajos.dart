/// Atajos al mantener presionado el ícono de la app (Android e iOS).
///
/// Solo con sesión del club: "Escanear QR" y "Reservas", que es lo que el
/// mostrador hace todo el día. Al cerrar sesión desaparecen.
library;

import 'package:flutter/foundation.dart';
import 'package:quick_actions/quick_actions.dart';

import '../app/routes.dart';
import '../auth/session.dart';

class AtajosIcono {
  AtajosIcono._();

  static const _qa = QuickActions();
  static bool _escuchando = false;

  static bool get _soportado =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Se llama una vez en `main()`: tocar un atajo abre esa pantalla del panel
  /// (`rtcAbrirPanel` manda al login si la sesión venció).
  static void escuchar() {
    if (!_soportado || _escuchando) return;
    _escuchando = true;
    _qa.initialize((tipo) {
      // El atajo puede llegar antes del primer frame si abre la app.
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        rtcAbrirPanel();
        // Sin sesión, rtcAbrirPanel ya llevó al login: ahí se queda.
        if (!RtcSession.instance.isLoggedIn) return;
        if (tipo == 'escanear') rtcIrAlPanel('/dashboard/propetario/escanear');
        if (tipo == 'reservas') rtcIrAlPanel('/dashboard/propetario/reservas');
      });
    });
  }

  static Future<void> mostrar() async {
    if (!_soportado) return;
    try {
      await _qa.setShortcutItems(const [
        ShortcutItem(type: 'escanear', localizedTitle: 'Escanear QR'),
        ShortcutItem(type: 'reservas', localizedTitle: 'Reservas'),
      ]);
    } catch (_) {}
  }

  static Future<void> quitar() async {
    if (!_soportado) return;
    try {
      await _qa.clearShortcutItems();
    } catch (_) {}
  }
}
