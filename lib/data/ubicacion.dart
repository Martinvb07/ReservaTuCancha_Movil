/// La ubicacion del jugador para "Cerca de mí". Se pide solo cuando la toca,
/// nunca al abrir la app.
library;

import 'package:geolocator/geolocator.dart';

import '../models/court.dart';

class Ubicacion {
  Ubicacion._();

  /// La ultima posicion conocida: sirve mientras la app siga abierta, para
  /// no volver a pedirla cada vez que se toca el chip.
  static Position? _ultima;

  /// Devuelve la posicion, o un mensaje si no se pudo (permiso negado, GPS
  /// apagado). Nunca lanza.
  static Future<(Position?, String?)> obtener() async {
    if (_ultima != null) return (_ultima, null);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return (
          null,
          'Activa la ubicación del teléfono para ver las canchas cercanas.',
        );
      }
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        return (
          null,
          'Sin permiso de ubicación no podemos saber qué canchas tienes cerca.',
        );
      }
      _ultima = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      return (_ultima, null);
    } catch (_) {
      return (null, 'No pudimos obtener tu ubicación. Intenta de nuevo.');
    }
  }

  /// Distancia en kilometros a una cancha, o null si la cancha no tiene
  /// coordenadas. Mongo las guarda como `[lng, lat]`.
  static double? km(Position desde, Court court) {
    final c = court.coordinates;
    if (c == null || c.length < 2) return null;
    return Geolocator.distanceBetween(
          desde.latitude,
          desde.longitude,
          c[1],
          c[0],
        ) /
        1000;
  }
}

/// "a 850 m", "a 2,3 km", "a 15 km".
String textoDistancia(double km) {
  if (km < 1) return 'a ${(km * 1000).round()} m';
  if (km < 10) return 'a ${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  return 'a ${km.round()} km';
}
