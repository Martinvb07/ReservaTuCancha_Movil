/// Port de `Frontend/src/lib/api/courts.api.ts` (solo lo publico: el dashboard
/// de propietario esta fuera de alcance).
library;

import '../models/court.dart';
import 'rtc_api.dart';

class CourtsApi {
  const CourtsApi();

  /// `GET /courts`. Los mismos filtros que arma la web.
  Future<CourtsPage> getAll({
    String? sport,
    String? city,
    int? minPrice,
    int? maxPrice,
    int page = 1,
    int limit = 12,
  }) async {
    final data = await RtcApi.instance.get(
      '/courts',
      query: {
        'sport': sport,
        'city': city,
        'minPrice': minPrice,
        'maxPrice': maxPrice,
        'page': page,
        'limit': limit,
      },
    );
    return CourtsPage.fromJson(data as Map<String, dynamic>);
  }

  /// `GET /courts/:id`.
  Future<Court> getById(String id) async {
    final data = await RtcApi.instance.get('/courts/$id');
    return Court.fromJson(data as Map<String, dynamic>);
  }

  /// `GET /courts/:id/wompi-config` — si el club puede cobrar en linea.
  Future<WompiConfig> wompiConfig(String courtId) async {
    final data = await RtcApi.instance.get('/courts/$courtId/wompi-config');
    return WompiConfig.fromJson((data as Map<String, dynamic>?) ?? const {});
  }

  /// `GET /courts/:id/blocked-slots?date=` — los bloqueos que pone el dueno.
  Future<List<BlockedSlot>> blockedSlots(String courtId, String date) async {
    final data = await RtcApi.instance.get(
      '/courts/$courtId/blocked-slots',
      query: {'date': date},
    );
    return (data as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(BlockedSlot.fromJson)
            .toList() ??
        const [];
  }
}

/// Una franja no disponible. `/bookings/slots` devuelve la misma forma sin
/// `reason`, asi que sirve para las dos.
class BlockedSlot {
  const BlockedSlot({
    required this.startTime,
    required this.endTime,
    this.reason,
  });

  final String startTime;
  final String endTime;
  final String? reason;

  factory BlockedSlot.fromJson(Map<String, dynamic> json) => BlockedSlot(
    startTime: (json['startTime'] as String?) ?? '',
    endTime: (json['endTime'] as String?) ?? '',
    reason: json['reason'] as String?,
  );
}

const courtsApi = CourtsApi();

/// Lo que devuelve `/courts/:id/wompi-config`. Al formulario solo le importa
/// `configured`: cuando es false esconde el boton de pagar y avisa.
class WompiConfig {
  const WompiConfig({required this.configured, this.publicKey});

  final bool configured;
  final String? publicKey;

  factory WompiConfig.fromJson(Map<String, dynamic> json) => WompiConfig(
    configured: (json['configured'] as bool?) ?? false,
    publicKey: json['wompiPublicKey'] as String?,
  );
}
