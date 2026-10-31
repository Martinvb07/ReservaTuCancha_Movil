/// Lo que la app recuerda en el telefono, sin cuenta: los datos con los que
/// el jugador reservo la ultima vez y sus canchas favoritas.
///
/// Vive en `shared_preferences` y no en el almacenamiento cifrado: no hay
/// nada secreto aca, y se lee al abrir el formulario, que tiene que ser
/// instantaneo.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DatosJugador {
  const DatosJugador({
    required this.nombre,
    required this.email,
    required this.telefono,
  });

  final String nombre;
  final String email;
  final String telefono;

  bool get vacio => nombre.isEmpty && email.isEmpty && telefono.isEmpty;
}

class Preferencias {
  Preferencias._();

  static final instance = Preferencias._();

  static const _kNombre = 'rtc.jugador.nombre';
  static const _kEmail = 'rtc.jugador.email';
  static const _kTelefono = 'rtc.jugador.telefono';
  static const _kFavoritos = 'rtc.favoritos';

  SharedPreferences? _prefs;

  /// Ids de las canchas favoritas. Las pantallas escuchan este notifier para
  /// pintar el corazon y la seccion del inicio.
  final favoritos = ValueNotifier<Set<String>>(<String>{});

  /// Se llama una vez desde `main()`. Si el almacenamiento falla la app
  /// sigue funcionando, solo que sin recordar nada.
  Future<void> cargar() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      favoritos.value = (_prefs!.getStringList(_kFavoritos) ?? const [])
          .toSet();
    } catch (_) {
      _prefs = null;
    }
  }

  DatosJugador get jugador => DatosJugador(
    nombre: _prefs?.getString(_kNombre) ?? '',
    email: _prefs?.getString(_kEmail) ?? '',
    telefono: _prefs?.getString(_kTelefono) ?? '',
  );

  Future<void> guardarJugador(DatosJugador d) async {
    final p = _prefs;
    if (p == null) return;
    await p.setString(_kNombre, d.nombre);
    await p.setString(_kEmail, d.email);
    await p.setString(_kTelefono, d.telefono);
  }

  bool esFavorita(String courtId) => favoritos.value.contains(courtId);

  Future<void> alternarFavorita(String courtId) async {
    final nuevo = {...favoritos.value};
    if (!nuevo.remove(courtId)) nuevo.add(courtId);
    favoritos.value = nuevo;
    await _prefs?.setStringList(_kFavoritos, nuevo.toList());
  }
}
