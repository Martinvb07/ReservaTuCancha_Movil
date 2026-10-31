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

  /// `GET /courts/:id/pagos-config` — si se puede pagar en linea y cuanto es
  /// la tarifa de servicio que se le suma al jugador.
  Future<PagosConfig> pagosConfig(String courtId) async {
    final data = await RtcApi.instance.get('/courts/$courtId/pagos-config');
    return PagosConfig.fromJson((data as Map<String, dynamic>?) ?? const {});
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

/// Lo que devuelve `/courts/:id/pagos-config`. Cuando `configured` es false
/// el formulario esconde el boton de pagar y avisa.
class PagosConfig {
  const PagosConfig({required this.configured, required this.tarifaServicio});

  /// Tarifa por defecto mientras llega la del servidor. El cobro nunca sale de
  /// aca: el total lo arma el backend con el precio de la cancha.
  static const tarifaPorDefecto = 2000;

  final bool configured;

  /// Lo que se le suma al jugador por reserva, sin importar el precio.
  final int tarifaServicio;

  factory PagosConfig.fromJson(Map<String, dynamic> json) => PagosConfig(
    configured: (json['configured'] as bool?) ?? false,
    tarifaServicio:
        (json['tarifaServicio'] as num?)?.toInt() ?? tarifaPorDefecto,
  );
}
