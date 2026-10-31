/// Port de `Frontend/src/lib/geocode.ts`.
///
/// Nominatim (OpenStreetMap): sin API key ni facturacion. Su politica pide
/// como maximo una peticion por segundo, asi que quien busque tiene que ir con
/// debounce — el selector de ubicacion usa 450ms, igual que la web.
///
/// La NEXT_PUBLIC_GOOGLE_MAPS_KEY del .env quedo sin usar a proposito.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

class GeoResult {
  const GeoResult({
    required this.label,
    required this.lat,
    required this.lng,
    required this.address,
    required this.city,
    required this.department,
  });

  /// Texto completo para la lista de sugerencias.
  final String label;

  final double lat;
  final double lng;

  /// Calle + numero, ya limpio para el campo "Direccion".
  final String address;

  final String city;
  final String department;
}

const _base = 'https://nominatim.openstreetmap.org';

/// Nominatim pide identificarse; sin User-Agent propio responde 403.
const _headers = {
  'User-Agent': 'ReservaTuCancha/1.0 (app movil)',
  'Accept': 'application/json',
};

/// `pickCity`: el municipio puede venir en cualquiera de estos campos.
String _ciudad(Map<String, dynamic> a) {
  for (final k in [
    'city',
    'town',
    'village',
    'municipality',
    'city_district',
    'county',
  ]) {
    final v = a[k];
    if (v is String && v.isNotEmpty) return v;
  }
  return '';
}

/// `pickStreet`.
String _calle(Map<String, dynamic> a, String fallback) {
  String? via;
  for (final k in ['road', 'pedestrian', 'footway', 'residential']) {
    final v = a[k];
    if (v is String && v.isNotEmpty) {
      via = v;
      break;
    }
  }
  if (via == null) return fallback.split(',').first;
  final numero = a['house_number'];
  return numero is String && numero.isNotEmpty ? '$via #$numero' : via;
}

GeoResult _aResultado(Map<String, dynamic> raw) {
  final a = (raw['address'] as Map<String, dynamic>?) ?? const {};
  final display = (raw['display_name'] as String?) ?? '';
  return GeoResult(
    label: display,
    lat: double.tryParse('${raw['lat']}') ?? 0,
    lng: double.tryParse('${raw['lon']}') ?? 0,
    address: _calle(a, (raw['name'] as String?) ?? display),
    city: _ciudad(a),
    department: (a['state'] as String?) ?? '',
  );
}

/// `searchPlaces`: busca direcciones en Colombia. Lista vacia si falla.
Future<List<GeoResult>> buscarLugares(String query) async {
  final q = query.trim();
  if (q.length < 3) return const [];

  final uri = Uri.parse('$_base/search').replace(
    queryParameters: {
      'q': q,
      'format': 'jsonv2',
      'addressdetails': '1',
      'countrycodes': 'co',
      'accept-language': 'es',
      'limit': '6',
    },
  );

  try {
    final res = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return const [];
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (data is! List) return const [];
    return data.whereType<Map<String, dynamic>>().map(_aResultado).toList();
  } catch (_) {
    return const [];
  }
}

/// `reverseGeocode`: coordenada → direccion. `null` si no se pudo resolver.
Future<GeoResult?> geocodificarInverso(double lat, double lng) async {
  final uri = Uri.parse('$_base/reverse').replace(
    queryParameters: {
      'lat': '$lat',
      'lon': '$lng',
      'format': 'jsonv2',
      'addressdetails': '1',
      'accept-language': 'es',
    },
  );

  try {
    final res = await http
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) return null;
    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (data is! Map<String, dynamic> || data['error'] != null) return null;
    final r = _aResultado(data);
    // El reverse devuelve la coordenada del punto ENCONTRADO, no la que se
    // pidio: se conserva la del usuario para que el pin no salte al soltarlo.
    return GeoResult(
      label: r.label,
      lat: lat,
      lng: lng,
      address: r.address,
      city: r.city,
      department: r.department,
    );
  } catch (_) {
    return null;
  }
}
