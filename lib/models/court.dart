import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/palette.dart';
import 'precios.dart';

/// Espeja `Court` de `Frontend/src/types/court.types.ts`.
class Court {
  const Court({
    required this.id,
    required this.name,
    required this.sport,
    required this.city,
    required this.department,
    required this.pricePerHour,
    required this.averageRating,
    required this.totalReviews,
    this.description,
    this.address = '',
    this.coordinates,
    this.currency = 'COP',
    this.isActive = true,
    this.photos = const [],
    this.amenities = const [],
    this.availability = const [],
    this.priceRules = const [],
  });

  final String id;
  final String name;
  final String sport;
  final String city;
  final String department;
  final int pricePerHour;
  final double averageRating;
  final int totalReviews;
  final String? description;
  final String address;

  /// Como las guarda Mongo: `[lng, lat]` (GeoJSON), no al reves.
  /// Ver el comentario de `Frontend/src/lib/geo.ts:3`.
  final List<double>? coordinates;

  final String currency;
  final bool isActive;
  final List<String> photos;
  final List<String> amenities;

  /// Los dias y horas que abre la cancha. Sin esto no se puede reservar.
  final List<AvailabilitySlot> availability;

  /// Franjas con otro precio (noche, fin de semana). Vacio: vale lo mismo
  /// a toda hora.
  final List<ReglaPrecio> priceRules;

  /// El precio por hora mas bajo, para las tarjetas ("Desde").
  int get precioDesde => precioMinimo(pricePerHour, priceRules);

  factory Court.fromJson(Map<String, dynamic> json) {
    final location = (json['location'] as Map<String, dynamic>?) ?? const {};
    final coords = (location['coordinates'] as List?)
        ?.whereType<num>()
        .map((n) => n.toDouble())
        .toList();
    return Court(
      id: json['_id'] as String,
      name: json['name'] as String,
      sport: json['sport'] as String,
      city: (location['city'] as String?) ?? '',
      department: (location['department'] as String?) ?? '',
      address: (location['address'] as String?) ?? '',
      coordinates: coords,
      description: json['description'] as String?,
      pricePerHour: (json['pricePerHour'] as num).toInt(),
      currency: (json['currency'] as String?) ?? 'COP',
      isActive: (json['isActive'] as bool?) ?? true,
      averageRating: (json['averageRating'] as num?)?.toDouble() ?? 0,
      totalReviews: (json['totalReviews'] as num?)?.toInt() ?? 0,
      photos:
          (json['photos'] as List?)?.whereType<String>().toList() ?? const [],
      amenities:
          (json['amenities'] as List?)?.whereType<String>().toList() ??
          const [],
      availability:
          (json['availability'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(AvailabilitySlot.fromJson)
              .toList() ??
          const [],
      priceRules:
          (json['priceRules'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(ReglaPrecio.fromJson)
              .toList() ??
          const [],
    );
  }

  String get locationLabel => department.isEmpty ? city : '$city, $department';
}

/// Espeja `AvailabilitySlot`: un dia de la semana con su horario de atencion.
class AvailabilitySlot {
  const AvailabilitySlot({
    required this.dayOfWeek,
    required this.openTime,
    required this.closeTime,
    required this.slotDurationMinutes,
  });

  /// 0 = domingo, como `getDay()` de JS.
  final int dayOfWeek;

  /// "HH:mm".
  final String openTime;
  final String closeTime;

  final int slotDurationMinutes;

  factory AvailabilitySlot.fromJson(Map<String, dynamic> json) =>
      AvailabilitySlot(
        dayOfWeek: (json['dayOfWeek'] as num).toInt(),
        openTime: json['openTime'] as String,
        closeTime: json['closeTime'] as String,
        slotDurationMinutes:
            (json['slotDurationMinutes'] as num?)?.toInt() ?? 60,
      );
}

/// Espeja `CourtsResponse`: la lista viene paginada.
class CourtsPage {
  const CourtsPage({
    required this.data,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  final List<Court> data;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  factory CourtsPage.fromJson(Map<String, dynamic> json) => CourtsPage(
    data:
        (json['data'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(Court.fromJson)
            .toList() ??
        const [],
    total: (json['total'] as num?)?.toInt() ?? 0,
    page: (json['page'] as num?)?.toInt() ?? 1,
    limit: (json['limit'] as num?)?.toInt() ?? 12,
    totalPages: (json['totalPages'] as num?)?.toInt() ?? 1,
  );
}

/// Espeja `SPORTS` de `Frontend/src/lib/constants.ts`.
class SportMeta {
  const SportMeta({
    required this.key,
    required this.label,
    required this.chipBackground,
    required this.chipForeground,
    required this.image,
  });

  final String key;
  final String label;

  /// El icono NO vive aca: es un SVG propio, se dibuja con `SportIcon`.
  final Color chipBackground;
  final Color chipForeground;
  final String image;
}

const _sports = <SportMeta>[
  SportMeta(
    key: 'futbol',
    label: 'Fútbol',
    chipBackground: Color(0xFFD1FAE5), // emerald-100
    chipForeground: Color(0xFF047857), // emerald-700
    image:
        'https://images.unsplash.com/photo-1529900748604-07564a03e7a6?w=1200&q=80',
  ),
  SportMeta(
    key: 'padel',
    label: 'Pádel',
    chipBackground: Color(0xFFE0F2FE), // sky-100
    chipForeground: Color(0xFF0369A1), // sky-700
    image:
        'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?w=1200&q=80',
  ),
  SportMeta(
    key: 'voley_playa',
    label: 'Voley Playa',
    chipBackground: Color(0xFFFEF3C7), // amber-100
    chipForeground: Color(0xFFB45309), // amber-700
    image:
        'https://images.unsplash.com/photo-1612872087720-bb876e2e67d1?w=1200&q=80',
  ),
];

List<SportMeta> get sports => _sports;

SportMeta getSport(String key) =>
    _sports.firstWhere((s) => s.key == key, orElse: () => _sports.first);

/// Las amenidades que ofrece el formulario de cancha (`AMENITIES` de la web),
/// cada una con su icono de lucide y un nombre corto para los mosaicos.
const amenityIcons = <String, IconData>{
  'Luz nocturna': LucideIcons.lightbulb,
  'Parqueadero': LucideIcons.squareParking,
  'Duchas': LucideIcons.showerHead,
  'Vestiarios': LucideIcons.shirt,
  'Cafetería': LucideIcons.coffee,
  'Graderías': LucideIcons.armchair,
  'Wi-Fi': LucideIcons.wifi,
  'Alquiler de equipos': LucideIcons.dumbbell,
};

/// Por palabra clave y sin tildes: canchas viejas o creadas a mano guardan
/// variantes ("iluminación", "parqueo", "wifi") que el mapa exacto no
/// reconocia y caian todas al mismo check.
const _amenityClaves = <(String, IconData)>[
  ('luz', LucideIcons.lightbulb),
  ('ilumin', LucideIcons.lightbulb),
  ('parque', LucideIcons.squareParking),
  ('ducha', LucideIcons.showerHead),
  ('vesti', LucideIcons.shirt),
  ('camerino', LucideIcons.shirt),
  ('cafe', LucideIcons.coffee),
  ('restaur', LucideIcons.utensils),
  ('grader', LucideIcons.armchair),
  ('tribuna', LucideIcons.armchair),
  ('wi', LucideIcons.wifi),
  ('equipo', LucideIcons.dumbbell),
  ('bano', LucideIcons.toilet),
  ('sanitario', LucideIcons.toilet),
];

String _sinTildes(String s) => s
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('é', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ñ', 'n');

IconData amenityIcon(String name) {
  final exacto = amenityIcons[name];
  if (exacto != null) return exacto;
  final n = _sinTildes(name);
  for (final (clave, icono) in _amenityClaves) {
    if (n.contains(clave)) return icono;
  }
  return LucideIcons.circleCheck;
}

/// El nombre que cabe en un mosaico de un cuarto de pantalla.
String amenityCorta(String name) => switch (name) {
  'Luz nocturna' => 'Iluminación',
  'Alquiler de equipos' => 'Equipos',
  'Parqueadero' => 'Parqueo',
  _ => name.isEmpty ? name : name[0].toUpperCase() + name.substring(1),
};

/// Formatea precios como `toLocaleString('es-CO')`: separador de miles con
/// punto. Sin `intl` para no sumar una dependencia por esto.
String formatCop(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Colores de apoyo para los placeholders mientras carga una foto remota.
Color placeholderFor(String sport) => switch (sport) {
  'padel' => const Color(0xFFE0F2FE),
  'voley_playa' => const Color(0xFFFEF3C7),
  _ => Green.c50,
};
