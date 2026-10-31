/// `GET /analytics/public`: lo que alimenta la home y las cifras de
/// /para-clubes. Ver `getPublicStats()` en `app/(public)/page.tsx`.
library;

import '../models/court.dart';
import 'rtc_api.dart';

class PublicStats {
  const PublicStats({
    required this.totalCourts,
    required this.totalBookings,
    required this.totalCities,
    required this.avgRating,
    required this.featuredCourts,
  });

  final int totalCourts;
  final int totalBookings;
  final int totalCities;
  final double avgRating;

  /// Vienen recortadas: sin `amenities` ni `availability`.
  final List<Court> featuredCourts;

  /// Los mismos valores a los que cae la web si la peticion falla.
  static const fallback = PublicStats(
    totalCourts: 0,
    totalBookings: 0,
    totalCities: 0,
    avgRating: 4.8,
    featuredCourts: [],
  );

  factory PublicStats.fromJson(Map<String, dynamic> json) => PublicStats(
    totalCourts: (json['totalCourts'] as num?)?.toInt() ?? 0,
    totalBookings: (json['totalBookings'] as num?)?.toInt() ?? 0,
    totalCities: (json['totalCities'] as num?)?.toInt() ?? 0,
    avgRating: (json['avgRating'] as num?)?.toDouble() ?? 4.8,
    featuredCourts:
        (json['featuredCourts'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(Court.fromJson)
            .toList() ??
        const [],
  );

  /// `avgRating` llega como numero: 5 tiene que verse "5" y 4.8 "4.8", igual
  /// que el `${stats.avgRating}` de la web.
  String get avgRatingLabel => avgRating == avgRating.roundToDouble()
      ? avgRating.toStringAsFixed(0)
      : avgRating.toString();
}

class AnalyticsApi {
  const AnalyticsApi();

  /// La web cachea 5 minutos y cae a valores por defecto si falla; aca igual:
  /// las cifras son decorativas y no valen romper la pantalla.
  Future<PublicStats> public() async {
    try {
      final data = await RtcApi.instance.get('/analytics/public');
      return PublicStats.fromJson(data as Map<String, dynamic>);
    } on RtcApiException {
      return PublicStats.fallback;
    }
  }
}

const analyticsApi = AnalyticsApi();
