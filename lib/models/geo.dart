/// Port de `Frontend/src/lib/geo.ts`.
library;

import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../widgets/icons/city_glyph.dart' show cityKey;
import 'court.dart';

/// `COLOMBIA_CENTER`.
const colombiaCenter = LatLng(4.5709, -74.2973);

/// `CITY_COORDS`: centros de ciudad para ubicar canchas sin coordenadas.
const _cityCoords = <String, LatLng>{
  'villavicencio': LatLng(4.1420, -73.6266),
  'acacias': LatLng(3.9878, -73.7592),
  'restrepo': LatLng(4.2611, -73.5600),
  'granada': LatLng(3.5460, -73.7060),
  'puerto lopez': LatLng(4.0847, -72.9553),
  'bogota': LatLng(4.7110, -74.0721),
  'medellin': LatLng(6.2442, -75.5812),
  'cali': LatLng(3.4516, -76.5320),
  'barranquilla': LatLng(10.9685, -74.7813),
  'bucaramanga': LatLng(7.1193, -73.1227),
};

/// `cityCenter`.
LatLng? cityCenter(String? city) => _cityCoords[cityKey(city ?? '').trim()];

/// `hash01`: hash estable de un string a [0,1). Mismo id → mismo
/// desplazamiento siempre. Es FNV-1a; `Math.imul` de JS se replica quedandose
/// con los 32 bits bajos.
double _hash01(String seed) {
  var h = 2166136261;
  for (var i = 0; i < seed.length; i++) {
    h ^= seed.codeUnitAt(i);
    h = (h * 16777619) & 0xFFFFFFFF;
  }
  return (h % 10000) / 10000;
}

/// `scatter`. Sin este desplazamiento, todas las canchas sin coordenadas de una
/// ciudad quedarian apiladas en el mismo pin y solo se veria una.
/// ±0.01° ≈ 1 km.
LatLng _scatter(LatLng base, String seed) {
  final angle = _hash01(seed) * math.pi * 2;
  final radius = 0.004 + _hash01('${seed}r') * 0.008;
  return LatLng(
    base.latitude + math.sin(angle) * radius,
    base.longitude + math.cos(angle) * radius,
  );
}

/// `validCoords`: Mongo las guarda como `[lng, lat]`.
bool _validCoords(List<double>? c) =>
    c != null &&
    c.length == 2 &&
    c[0].isFinite &&
    c[1].isFinite &&
    !(c[0] == 0 && c[1] == 0) &&
    c[1].abs() <= 90 &&
    c[0].abs() <= 180;

/// Una cancha con su punto en el mapa.
class CourtPoint {
  const CourtPoint(this.court, this.position, {this.approx = false});

  final Court court;
  final LatLng position;

  /// true cuando el punto salio del centro de la ciudad y no de la cancha.
  final bool approx;
}

/// `locationPoint`: resuelve unas coordenadas de Mongo a un punto del mapa. Si
/// no hay coordenadas cae al centro de la ciudad, desplazado por `seed`.
/// `null` si no hay ni coordenadas ni ciudad reconocida.
({LatLng point, bool approx})? locationPoint(
  List<double>? coordinates,
  String? city,
  String seed,
) {
  if (_validCoords(coordinates)) {
    return (point: LatLng(coordinates![1], coordinates[0]), approx: false);
  }
  final center = cityCenter(city);
  if (center == null) return null;
  return (point: _scatter(center, seed), approx: true);
}

/// `courtPoint`. `null` si no hay ni coords ni ciudad conocida.
CourtPoint? courtPoint(Court court) {
  final at = locationPoint(court.coordinates, court.city, court.id);
  return at == null ? null : CourtPoint(court, at.point, approx: at.approx);
}

/// `courtPoints`: descarta las canchas que no se pueden ubicar.
List<CourtPoint> courtPoints(List<Court> courts) {
  final out = <CourtPoint>[];
  for (final c in courts) {
    final p = courtPoint(c);
    if (p != null) out.add(p);
  }
  return out;
}

/// `shortPrice`: 80000 -> "$80K". En el pin no cabe "$80.000".
String shortPrice(int n) {
  if (n >= 1000000) {
    final m = n / 1000000;
    final s = m == m.roundToDouble()
        ? m.toStringAsFixed(0)
        : m.toStringAsFixed(1);
    return '\$${s}M';
  }
  if (n >= 1000) return '\$${(n / 1000).round()}K';
  return '\$$n';
}

/// Tiles estandar de OpenStreetMap, las mismas de `lib/leaflet.ts`.
///
/// Antes eran las de CARTO Voyager, pero CARTO paso a exigir API key y ahora
/// devuelve las tiles con "API KEY REQUIRED" estampado encima — con HTTP 200,
/// asi que nada falla, solo se ve mal. La web se cambio a OSM y la app la
/// sigue. OSM no pide llave pero si atribucion visible (ver
/// [TileAttribution]) y no publica zoom 20: el tope es 19.
///
/// Para pasar a otro proveedor sin tocar codigo:
/// `--dart-define=RTC_TILE_URL=...`.
const tileUrl = String.fromEnvironment(
  'RTC_TILE_URL',
  defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
);

/// `maxZoom: 19` de `TILE_OPTIONS`.
const tileMaxZoom = 19.0;
