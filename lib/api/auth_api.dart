/// Las dos rutas de sesion. Ver el comentario de `RtcApi.loginUrl`: NO se puede
/// pegar a `/api/auth/*` en produccion porque ahi contesta next-auth.
library;

import '../models/auth_user.dart';
import 'rtc_api.dart';

/// Lo que devuelve `auth.service.ts:38`.
class AuthSessionData {
  const AuthSessionData({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final AuthUser user;
}

class AuthApi {
  const AuthApi();

  Future<AuthSessionData> login(String email, String password) async {
    final data =
        await RtcApi.instance.postAbsolute(
              RtcApi.loginUrl,
              body: {'email': email.trim(), 'password': password},
            )
            as Map<String, dynamic>;

    final access = data['accessToken'] as String?;
    final refresh = data['refreshToken'] as String?;
    final user = data['user'];
    if (access == null || refresh == null || user is! Map<String, dynamic>) {
      throw RtcApiException('Credenciales inválidas');
    }
    return AuthSessionData(
      accessToken: access,
      refreshToken: refresh,
      user: AuthUser.fromJson(user),
    );
  }

  /// `POST /cuenta/google` — el ID token de Google por la sesión del panel.
  Future<AuthSessionData> google(String idToken) async {
    final data =
        await RtcApi.instance.post('/cuenta/google', body: {'idToken': idToken})
            as Map<String, dynamic>;
    return _sesion(data);
  }

  AuthSessionData _sesion(Map<String, dynamic> data) {
    final access = data['accessToken'] as String?;
    final refresh = data['refreshToken'] as String?;
    final user = data['user'];
    if (access == null || refresh == null || user is! Map<String, dynamic>) {
      throw RtcApiException('Credenciales inválidas');
    }
    return AuthSessionData(
      accessToken: access,
      refreshToken: refresh,
      user: AuthUser.fromJson(user),
    );
  }

  /// Devuelve el par nuevo. `auth.service.ts:82` rota tambien el refresh.
  Future<({String accessToken, String refreshToken})> refresh(
    String refreshToken,
  ) async {
    final data =
        await RtcApi.instance.postAbsolute(
              RtcApi.refreshUrl,
              body: {'refreshToken': refreshToken},
            )
            as Map<String, dynamic>;

    final access = data['accessToken'] as String?;
    final next = data['refreshToken'] as String?;
    if (access == null || next == null) {
      throw RtcApiException('Sesión expirada');
    }
    return (accessToken: access, refreshToken: next);
  }
}

const authApi = AuthApi();
