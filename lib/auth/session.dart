/// La sesion de la app. Es el equivalente del `useSession()` de next-auth, pero
/// guardando los tokens en el almacenamiento seguro del sistema (Keystore en
/// Android, Keychain en iOS) en vez de en una cookie.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/auth_api.dart';
import '../api/rtc_api.dart';
import '../data/atajos.dart';
import '../data/cache_offline.dart';
import '../data/google_login.dart';
import '../data/push.dart';
import '../models/auth_user.dart';

class RtcSession extends ChangeNotifier {
  RtcSession._();

  static final RtcSession instance = RtcSession._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _kAccess = 'rtc.accessToken';
  static const _kRefresh = 'rtc.refreshToken';
  static const _kUser = 'rtc.user';

  String? _accessToken;
  String? _refreshToken;
  AuthUser? _user;
  bool _restored = false;

  AuthUser? get user => _user;
  bool get isLoggedIn => _user != null && _accessToken != null;

  /// false hasta que se leyo el almacenamiento, para no parpadear el navbar
  /// entre "sin sesion" y "con sesion" al abrir la app.
  bool get restored => _restored;

  /// Se llama una vez desde `main()`, antes del primer frame.
  Future<void> restore() async {
    RtcApi.instance.readAccessToken = () => _accessToken;
    RtcApi.instance.renewSession = renew;

    try {
      _accessToken = await _storage.read(key: _kAccess);
      _refreshToken = await _storage.read(key: _kRefresh);
      final raw = await _storage.read(key: _kUser);
      if (raw != null) {
        _user = AuthUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {
      // Si el almacenamiento no se puede leer (llave rotada, backup restaurado
      // en otro equipo), se arranca sin sesion en vez de reventar.
      _accessToken = null;
      _refreshToken = null;
      _user = null;
    }

    _restored = true;
    notifyListeners();
  }

  Future<void> login(String email, String password) async =>
      _abrir(await authApi.login(email, password));

  /// Entrar con Google: el ID token se canjea en el backend.
  Future<void> loginConGoogle(String idToken) async =>
      _abrir(await authApi.google(idToken));

  /// Ya eligió su contraseña: deja de pedirle el cambio.
  Future<void> marcarClaveCambiada() async {
    final u = _user;
    if (u == null) return;
    _user = u.copyWith(debeCambiarClave: false);
    await _persist();
    notifyListeners();
  }

  Future<void> _abrir(AuthSessionData data) async {
    _accessToken = data.accessToken;
    _refreshToken = data.refreshToken;
    _user = data.user;
    await _persist();
    notifyListeners();
    // Este teléfono empieza a recibir los avisos del club.
    PushNotificaciones.instance.registrarEnElClub();
    AtajosIcono.mostrar();
  }

  /// La dispara el cliente HTTP cuando una request firmada vuelve 401.
  Future<bool> renew() async {
    final token = _refreshToken;
    if (token == null) return false;
    try {
      final next = await authApi.refresh(token);
      _accessToken = next.accessToken;
      _refreshToken = next.refreshToken;
      await _persist();
      notifyListeners();
      return true;
    } on RtcApiException catch (e) {
      // Solo se cierra la sesion si el servidor DICE que el refresh no vale
      // (401). Un 500 o un corte de red no significan eso: borrar la sesion
      // ahi echaria al usuario por un problema pasajero del servidor.
      if (e.statusCode == 401) await logout();
      return false;
    }
  }

  /// OJO: no le avisa al backend.
  ///
  /// `POST /auth/logout` existe en el NestJS, pero en produccion nginx manda
  /// `/api/auth` al Next y no hay ruta proxy para esa (si la hay para login y
  /// refresh). Asi que la sesion se borra del telefono y el refresh token
  /// sigue vivo en la base hasta que expira. Si eso llega a importar, la
  /// solucion es un `/api/backend-logout` en el Next, gemelo del de login.
  Future<void> logout() async {
    // Antes de borrar el token: la baja del teléfono va firmada.
    if (_accessToken != null) {
      await PushNotificaciones.instance.olvidarDelClub();
    }
    await GoogleLogin.salir();
    await CacheOffline.instance.borrarPanel();
    await AtajosIcono.quitar();
    _accessToken = null;
    _refreshToken = null;
    _user = null;
    try {
      await _storage.delete(key: _kAccess);
      await _storage.delete(key: _kRefresh);
      await _storage.delete(key: _kUser);
    } catch (_) {
      // Ya quedo fuera de sesion en memoria; no hay mas que hacer.
    }
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      await _storage.write(key: _kAccess, value: _accessToken);
      await _storage.write(key: _kRefresh, value: _refreshToken);
      await _storage.write(key: _kUser, value: jsonEncode(_user!.toJson()));
    } catch (_) {
      // La sesion sigue valida en memoria aunque no se haya podido guardar:
      // se pierde recien al cerrar la app.
    }
  }
}
