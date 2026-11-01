/// Port de `Frontend/src/lib/api/bookings.api.ts` mas lo que `BookingForm.tsx`
/// pide a mano. Todo el flujo es de invitado: ninguna de estas rutas pide
/// login (`bookings.controller.ts`).
library;

import '../models/booking.dart';
import 'courts_api.dart' show BlockedSlot;
import 'rtc_api.dart';

class BookingsApi {
  const BookingsApi();

  /// `GET /bookings/disponibilidad` — cuantos turnos quedan libres en cada
  /// cancha una fecha, y cual es el proximo. Si falla devuelve un mapa vacio:
  /// es un dato de ayuda en las tarjetas y no vale romper el listado.
  Future<Map<String, Disponibilidad>> disponibilidad(
    List<String> ids,
    String fecha, {
    String? desde,
  }) async {
    if (ids.isEmpty) return const {};
    try {
      final data = await RtcApi.instance.get(
        '/bookings/disponibilidad',
        query: {'ids': ids.join(','), 'fecha': fecha, 'desde': desde},
      );
      final mapa = (data as Map<String, dynamic>?) ?? const {};
      return {
        for (final e in mapa.entries)
          if (e.value is Map<String, dynamic>)
            e.key: Disponibilidad.fromJson(e.value as Map<String, dynamic>),
      };
    } on RtcApiException {
      return const {};
    }
  }

  /// `GET /bookings/slots?courtId&date` — las franjas ya tomadas.
  Future<List<BlockedSlot>> takenSlots(String courtId, String date) async {
    final data = await RtcApi.instance.get(
      '/bookings/slots',
      query: {'courtId': courtId, 'date': date},
    );
    return (data as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(BlockedSlot.fromJson)
            .toList() ??
        const [];
  }

  /// `POST /bookings` — crear la reserva. Devuelve la reserva con su `_id`,
  /// que es lo que despues necesita `initPayment`.
  Future<Booking> create({
    required String courtId,
    required String guestName,
    required String guestEmail,
    required String guestPhone,
    required String date,
    required String startTime,
    required String endTime,
    required int totalPrice,
    String? notes,
    int semanas = 1,
    String? pushToken,
  }) async {
    final data = await RtcApi.instance.post(
      '/bookings',
      body: {
        'courtId': courtId,
        'guestName': guestName,
        'guestEmail': guestEmail,
        'guestPhone': guestPhone,
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'totalPrice': totalPrice,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        'paymentMethod': 'epayco',
        // Turno fijo: la misma hora varias semanas, pagado en un solo cobro.
        if (semanas > 1) 'semanas': semanas,
        // Para avisar la confirmación y el recordatorio en este teléfono.
        'pushToken': ?pushToken,
      },
    );
    return Booking.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /bookings/lista-espera` — avisar si un turno ocupado se libera.
  /// Devuelve cuántas personas están esperando ese turno.
  Future<int> listaEspera({
    required String courtId,
    required String date,
    required String startTime,
    required String endTime,
    required String email,
    String? nombre,
    String? pushToken,
  }) async {
    final data = await RtcApi.instance.post(
      '/bookings/lista-espera',
      body: {
        'courtId': courtId,
        'date': date,
        'startTime': startTime,
        'endTime': endTime,
        'email': email.trim(),
        if (nombre != null && nombre.trim().isNotEmpty) 'nombre': nombre.trim(),
        'pushToken': ?pushToken,
      },
    );
    return ((data as Map<String, dynamic>?)?['enEspera'] as num?)?.toInt() ?? 1;
  }

  /// `POST /bookings/:id/payment` — crea la sesion de ePayco y devuelve el
  /// link a `/pagar` de la web, que abre el checkout con esa sesion (el
  /// checkout es un script de navegador y la app no lo puede cargar).
  ///
  /// `redirectUrl` es a donde vuelve el navegador cuando termina de pagar.
  Future<String> initPayment(String bookingId, String redirectUrl) async {
    final data = await RtcApi.instance.post(
      '/bookings/$bookingId/payment',
      body: {'redirectUrl': redirectUrl},
    );
    final json = data as Map<String, dynamic>?;
    final url =
        (json?['checkoutUrl'] as String?) ?? (json?['redirectUrl'] as String?);
    if (url == null || url.isEmpty) {
      throw RtcApiException('El servidor no devolvio el link de pago');
    }
    return url;
  }

  /// `GET /bookings/:id`.
  ///
  /// Es la fuente de verdad de si el pago entro: la confirmacion de ePayco
  /// pone la reserva en `confirmed` cuando aprueban, y la BORRA cuando
  /// rechazan (`epayco-confirmation.controller.ts`). Por eso un 404 aca no es
  /// un error de red: es un pago rechazado.
  Future<Booking> getById(String id) async {
    final data = await RtcApi.instance.get('/bookings/$id');
    return Booking.fromJson(data as Map<String, dynamic>);
  }

  /// `GET /bookings/public?guestEmail=` o `?code=` — como busca /mis-reservas.
  Future<List<Booking>> search({String? guestEmail, String? code}) async {
    final data = await RtcApi.instance.get(
      '/bookings/public',
      query: {'guestEmail': guestEmail, 'code': code},
    );
    return (data as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(Booking.fromJson)
            .toList() ??
        const [];
  }

  /// `GET /bookings/cancel-info?token=` — se entra por el link del correo.
  Future<Booking> cancelInfo(String token) async {
    final data = await RtcApi.instance.get(
      '/bookings/cancel-info',
      query: {'token': token},
    );
    return Booking.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /bookings/reprogramar?token=` — tambien con el token del correo.
  Future<void> reprogramar({
    required String token,
    required String date,
    required String startTime,
    required String endTime,
  }) => RtcApi.instance.post(
    '/bookings/reprogramar',
    query: {'token': token},
    body: {'date': date, 'startTime': startTime, 'endTime': endTime},
  );
}

const bookingsApi = BookingsApi();

/// Turnos libres de una cancha en un dia.
class Disponibilidad {
  const Disponibilidad({required this.libres, this.proximo});

  final int libres;

  /// "HH:mm" del primer turno libre, o null si no queda ninguno.
  final String? proximo;

  factory Disponibilidad.fromJson(Map<String, dynamic> json) => Disponibilidad(
    libres: (json['libres'] as num?)?.toInt() ?? 0,
    proximo: json['proximo'] as String?,
  );
}
