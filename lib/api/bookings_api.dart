/// Port de `Frontend/src/lib/api/bookings.api.ts` mas lo que `BookingForm.tsx`
/// pide a mano. Todo el flujo es de invitado: ninguna de estas rutas pide
/// login (`bookings.controller.ts`).
library;

import '../models/booking.dart';
import 'courts_api.dart' show BlockedSlot;
import 'rtc_api.dart';

class BookingsApi {
  const BookingsApi();

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
        'paymentMethod': 'wompi',
      },
    );
    return Booking.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /bookings/:id/payment` — devuelve la URL del checkout de Wompi.
  ///
  /// `redirectUrl` es a donde vuelve el navegador cuando termina de pagar.
  Future<String> initPayment(String bookingId, String redirectUrl) async {
    final data = await RtcApi.instance.post(
      '/bookings/$bookingId/payment',
      body: {'redirectUrl': redirectUrl},
    );
    final url = (data as Map<String, dynamic>?)?['redirectUrl'] as String?;
    if (url == null || url.isEmpty) {
      throw RtcApiException('El servidor no devolvio el link de pago');
    }
    return url;
  }

  /// `GET /bookings/:id`.
  ///
  /// Es la fuente de verdad de si el pago entro: el webhook de Wompi pone la
  /// reserva en `confirmed` cuando aprueban, y la BORRA cuando rechazan
  /// (`wompi-webhook.controller.ts:61`). Por eso un 404 aca no es un error de
  /// red: es un pago rechazado.
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
