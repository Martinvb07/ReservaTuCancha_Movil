/// Lo último que se vio, para cuando no hay internet.
///
/// Cada GET que sale bien se guarda (listado y fichas de canchas, Mis
/// reservas, el detalle con el QR, el panel). Si después la misma consulta
/// falla por falta de red, se devuelve lo guardado en vez del error: en la
/// cancha, con mala señal, el jugador puede mostrar igual su QR.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// true mientras alguna pantalla esté mostrando datos guardados.
final rtcMostrandoGuardado = ValueNotifier<bool>(false);

class CacheOffline {
  CacheOffline._();

  static final CacheOffline instance = CacheOffline._();

  static const _prefijo = 'offline:';
  static const _indice = 'offline.indice';

  /// Cuántas consultas distintas se guardan, y el tamaño máximo de cada una.
  static const _maxEntradas = 80;
  static const _maxBytes = 300 * 1024;

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _p async =>
      _prefs ??= await SharedPreferences.getInstance();

  /// Las consultas firmadas (panel) se guardan aparte para borrarlas al
  /// cerrar sesión.
  static String clave(Uri uri, {required bool firmada}) =>
      '$_prefijo${firmada ? 'panel:' : ''}$uri';

  Future<void> guardar(String clave, Object? datos) async {
    try {
      final texto = jsonEncode(datos);
      if (texto.length > _maxBytes) return;
      final p = await _p;
      await p.setString(clave, texto);
      final indice = (p.getStringList(_indice) ?? [])
        ..remove(clave)
        ..add(clave);
      while (indice.length > _maxEntradas) {
        await p.remove(indice.removeAt(0));
      }
      await p.setStringList(_indice, indice);
    } catch (_) {
      // Guardar es un extra: si falla, la app sigue igual.
    }
  }

  /// Lo guardado para esa consulta, o null si no hay.
  Future<Object?> leer(String clave) async {
    try {
      final texto = (await _p).getString(clave);
      return texto == null ? null : jsonDecode(texto);
    } catch (_) {
      return null;
    }
  }

  /// Al cerrar sesión: los datos del panel no se quedan en el teléfono.
  Future<void> borrarPanel() async {
    final p = await _p;
    final indice = p.getStringList(_indice) ?? [];
    for (final k
        in indice.where((k) => k.startsWith('${_prefijo}panel:')).toList()) {
      await p.remove(k);
      indice.remove(k);
    }
    await p.setStringList(_indice, indice);
  }
}
