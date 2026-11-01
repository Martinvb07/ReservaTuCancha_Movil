/// Notificaciones push con Firebase Cloud Messaging.
///
/// El proyecto de Firebase se pasa en la build con --dart-define (no hace
/// falta google-services.json):
///
///   --dart-define=FIREBASE_API_KEY=...
///   --dart-define=FIREBASE_APP_ID=...            (el de la app Android o iOS)
///   --dart-define=FIREBASE_SENDER_ID=...
///   --dart-define=FIREBASE_PROJECT_ID=...
///
/// Sin esos valores el push queda apagado y la app funciona igual: las
/// reservas y los avisos siguen llegando por correo.
library;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../api/rtc_api.dart';
import '../app/routes.dart';
import '../widgets/rtc_toast.dart';

class PushNotificaciones {
  PushNotificaciones._();

  static final PushNotificaciones instance = PushNotificaciones._();

  static const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const _appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const _senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const _projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');

  static bool get configurado =>
      _apiKey.isNotEmpty &&
      _appId.isNotEmpty &&
      _senderId.isNotEmpty &&
      _projectId.isNotEmpty;

  bool _listo = false;
  String? _token;

  /// El token de este teléfono, o null si el push está apagado o el usuario
  /// no dio permiso. Viaja en las reservas para avisar la confirmación y el
  /// recordatorio.
  String? get token => _token;

  /// Se llama desde `main()`. Nunca lanza: si Firebase no arranca, la app
  /// sigue sin push.
  Future<void> iniciar() async {
    if (!configurado || _listo || kIsWeb) return;
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: _apiKey,
          appId: _appId,
          messagingSenderId: _senderId,
          projectId: _projectId,
        ),
      );
      _listo = true;
      final fcm = FirebaseMessaging.instance;
      // El token llega (y se renueva) por onRegistered.
      fcm.onRegistered.listen((t) {
        final cambio = t != _token;
        _token = t;
        if (cambio) _alCambiarToken?.call(t);
      });
      await fcm.register();

      // Con la app abierta Android no muestra la notificación: va como aviso.
      FirebaseMessaging.onMessage.listen(_mostrarEnPrimerPlano);
      // Tocar la notificación abre la pantalla que corresponde.
      FirebaseMessaging.onMessageOpenedApp.listen((m) => _abrir(m.data));
      final inicial = await fcm.getInitialMessage();
      if (inicial != null) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _abrir(inicial.data),
        );
      }
    } catch (e) {
      debugPrint('Push apagado: $e');
    }
  }

  /// Pide permiso de notificaciones (Android 13+ e iOS). Se llama en un
  /// momento con sentido (al reservar o al entrar al panel), no al abrir.
  Future<String?> pedirPermiso() async {
    if (!_listo) return null;
    try {
      final ajustes = await FirebaseMessaging.instance.requestPermission();
      if (ajustes.authorizationStatus == AuthorizationStatus.denied) {
        return null;
      }
      if (_token == null) {
        await FirebaseMessaging.instance.register();
        _token ??= await FirebaseMessaging.instance.onRegistered.first.timeout(
          const Duration(seconds: 10),
          onTimeout: () => '',
        );
        if (_token!.isEmpty) _token = null;
      }
      return _token;
    } catch (_) {
      return null;
    }
  }

  void Function(String token)? _alCambiarToken;

  /// Registra este teléfono para recibir los avisos del club (nueva reserva
  /// pagada). Lo llama la sesión al entrar al panel.
  Future<void> registrarEnElClub() async {
    final t = await pedirPermiso();
    if (t == null) return;
    _alCambiarToken = (nuevo) => _registrar(nuevo);
    await _registrar(t);
  }

  Future<void> _registrar(String t) async {
    try {
      await RtcApi.instance.post(
        '/push/dispositivos',
        body: {
          'token': t,
          'plataforma': defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android',
        },
        auth: true,
      );
    } catch (_) {
      // Sin push del club no se pierde nada: el correo y el socket siguen.
    }
  }

  /// Al cerrar sesión el teléfono deja de recibir los avisos del club.
  Future<void> olvidarDelClub() async {
    _alCambiarToken = null;
    final t = _token;
    if (t == null) return;
    try {
      await RtcApi.instance.delete(
        '/push/dispositivos',
        body: {'token': t},
        auth: true,
      );
    } catch (_) {}
  }

  void _mostrarEnPrimerPlano(RemoteMessage m) {
    final ctx = rtcNavigatorKey.currentContext;
    final n = m.notification;
    if (ctx == null || n == null) return;
    rtcToast(ctx, n.title ?? 'ReservaTuCancha', descripcion: n.body);
  }

  void _abrir(Map<String, dynamic> datos) {
    switch (datos['tipo']) {
      case 'nueva-reserva':
        rtcNavigatorKey.currentState?.pushNamed(
          '/dashboard/propetario/reservas',
        );
      case 'turno-liberado':
        final id = datos['courtId'] as String?;
        if (id != null) {
          rtcOpenCourt(
            id,
            date: datos['fecha'] as String?,
            start: datos['startTime'] as String?,
          );
        }
      case 'reserva-confirmada' || 'recordatorio':
        rtcNavigatorKey.currentState?.pushNamed('/mis-reservas');
    }
  }
}
