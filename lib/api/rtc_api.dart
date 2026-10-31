/// Cliente HTTP contra el backend NestJS. Es el equivalente de
/// `Frontend/src/lib/api/axios.ts`: mismo timeout, mismo mensaje de error y el
/// mismo reintento con refresh cuando vuelve 401.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Error de la API con el mensaje que manda NestJS.
///
/// NestJS devuelve `message` como string o como lista (las validaciones de
/// class-validator). La web se queda con el primero; aca igual.
class RtcApiException implements Exception {
  RtcApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  /// La confirmacion de ePayco BORRA la reserva cuando el pago se rechaza, asi que
  /// un 404 sobre una reserva que existia significa "no se pago".
  bool get notFound => statusCode == 404;

  @override
  String toString() => message;
}

class RtcApi {
  RtcApi._();

  static final RtcApi instance = RtcApi._();

  /// Por defecto pega a produccion, asi la app anda en un telefono real sin
  /// configurar nada. Para el backend local desde el emulador:
  ///   --dart-define=RTC_API_URL=http://10.0.2.2:4000/api
  static const baseUrl = String.fromEnvironment(
    'RTC_API_URL',
    defaultValue: 'https://reservatucancha.site/api',
  );

  /// OJO: el login NO va por `/api/auth/login`.
  ///
  /// En el VPS, nginx manda `/api/auth` al Next (donde vive next-auth) y no al
  /// NestJS: pegarle ahi contesta "This action with HTTP POST is not supported
  /// by NextAuth.js". El Next expone `/api/backend-login`, que reenvia a
  /// `127.0.0.1:4000/api/auth/login`. Verificado contra produccion.
  static const loginUrl = String.fromEnvironment(
    'RTC_LOGIN_URL',
    defaultValue: 'https://reservatucancha.site/api/backend-login',
  );

  static const refreshUrl = String.fromEnvironment(
    'RTC_REFRESH_URL',
    defaultValue: 'https://reservatucancha.site/api/backend-login/refresh',
  );

  /// El mismo de axios.
  static const _timeout = Duration(seconds: 10);

  final _client = http.Client();

  /// Los pone `RtcSession`. Se inyectan para que la capa de red no dependa de
  /// la sesion y no quede un import circular.
  String? Function()? readAccessToken;
  Future<bool> Function()? renewSession;

  /// Evita que dos requests en paralelo disparen dos refresh, como la cola de
  /// `axios.ts`.
  Future<bool>? _renewing;

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool auth = false,
  }) => _send('GET', path, query: query, auth: auth);

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool auth = false,
  }) => _send('POST', path, body: body, query: query, auth: auth);

  Future<dynamic> patch(String path, {Object? body, bool auth = false}) =>
      _send('PATCH', path, body: body, auth: auth);

  /// `body` porque una ruta lo pide: `DELETE /courts/:id/photos` lleva la URL
  /// de la foto en el cuerpo (axios lo manda con `{ data: { url } }`).
  Future<dynamic> delete(String path, {Object? body, bool auth = false}) =>
      _send('DELETE', path, body: body, auth: auth);

  /// Para las dos rutas de auth, que viven en el Next y no en el NestJS.
  Future<dynamic> postAbsolute(String url, {Object? body}) =>
      _request('POST', Uri.parse(url), body: body, token: null);

  Future<dynamic> _send(
    String method,
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    bool auth = false,
  }) async {
    final uri = _uri(path, query);
    final token = auth ? readAccessToken?.call() : null;

    try {
      return await _request(method, uri, body: body, token: token);
    } on RtcApiException catch (e) {
      // Mismo criterio que el interceptor de la web: solo tiene sentido
      // renovar si la request iba firmada.
      if (e.statusCode != 401 || token == null || renewSession == null) rethrow;

      final ok = await (_renewing ??= _renew());
      if (!ok) rethrow;

      return _request(method, uri, body: body, token: readAccessToken?.call());
    }
  }

  Future<bool> _renew() async {
    try {
      return await renewSession!.call();
    } finally {
      _renewing = null;
    }
  }

  Uri _uri(String path, Map<String, dynamic>? query) {
    final clean = <String, String>{};
    query?.forEach((k, v) {
      if (v == null) return;
      final s = v.toString();
      if (s.isEmpty) return;
      clean[k] = s;
    });
    final uri = Uri.parse('$baseUrl$path');
    return clean.isEmpty ? uri : uri.replace(queryParameters: clean);
  }

  Future<dynamic> _request(
    String method,
    Uri uri, {
    Object? body,
    String? token,
  }) async {
    final request = http.Request(method, uri);
    request.headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    if (token != null) request.headers['Authorization'] = 'Bearer $token';

    http.Response response;
    try {
      final streamed = await _client.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw RtcApiException('El servidor tardo demasiado en responder');
    } on SocketException {
      throw RtcApiException('Error de conexión con el servidor');
    } on http.ClientException {
      throw RtcApiException('Error de conexión con el servidor');
    }

    // `response.body` asume latin1 si la respuesta no declara charset, y los
    // nombres de las canchas vienen con tildes.
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    final decoded = text.isEmpty ? null : _tryDecode(text);

    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;

    throw RtcApiException(
      _errorMessage(decoded),
      statusCode: response.statusCode,
    );
  }

  static dynamic _tryDecode(String text) {
    try {
      return jsonDecode(text);
    } catch (_) {
      return text;
    }
  }

  /// Igual que la web: `data.message`, y si es lista el primero.
  static String _errorMessage(dynamic decoded) {
    if (decoded is Map) {
      final message = decoded['message'];
      if (message is List && message.isNotEmpty) {
        return message.first.toString();
      }
      if (message is String && message.isNotEmpty) return message;
      final error = decoded['error'];
      if (error is String && error.isNotEmpty) return error;
    }
    return 'Error de conexión con el servidor';
  }
}
