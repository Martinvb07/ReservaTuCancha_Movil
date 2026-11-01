/// Espeja la reserva que devuelve `/bookings/public` del backend NestJS.
library;

import 'package:flutter/material.dart';

class Booking {
  const Booking({
    required this.id,
    required this.bookingCode,
    this.courtId = '',
    required this.courtName,
    required this.city,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.totalPrice,
    this.netoDueno,
    required this.status,
    this.guestEmail = '',
    this.guestName = '',
    this.paymentMethod = 'epayco',
    this.guestPhone = '',
    this.notes,
    this.cancelToken,
    this.origen = 'online',
    this.serieId,
    this.serieSemanas,
    this.serieTotal,
  });

  final String id;
  final String bookingCode;

  /// Para volver a la ficha ("Reservar de nuevo", "Invitar").
  final String courtId;
  final String courtName;
  final String city;
  final DateTime date;
  final String startTime;
  final String endTime;

  /// Lo que pago el jugador: precio de la cancha + tarifa de servicio.
  final int totalPrice;

  /// Lo que le llega al club: el total menos la pasarela y la parte de la
  /// plataforma. Las reservas anteriores a ePayco no lo traen.
  final int? netoDueno;

  /// Lo que se le muestra al dueno. Para las reservas viejas, sin desglose,
  /// cae al total, que es lo que el panel mostraba entonces.
  int get netoParaDueno => netoDueno ?? totalPrice;

  /// pending | confirmed | reagendada | completed
  final String status;

  final String guestEmail;

  /// Lo necesita el panel del propietario: en /mis-reservas no se muestra.
  final String guestName;

  /// 'epayco'. Quedan reservas viejas con 'wompi' o 'efectivo', de antes de
  /// que el cobro pasara a ePayco.
  final String paymentMethod;

  /// Los dos ultimos solo los usa el panel del propietario.
  final String guestPhone;
  final String? notes;

  final String? cancelToken;

  /// 'manual' si la anotó el club (teléfono, mostrador): se cobra en el club.
  final String origen;
  bool get esManual => origen == 'manual';

  /// Turno fijo: las fechas de una misma serie comparten este id.
  final String? serieId;

  /// Solo al crear o consultar un turno fijo: cuántas semanas y el total.
  final int? serieSemanas;
  final int? serieTotal;

  factory Booking.fromJson(Map<String, dynamic> json) {
    final court = json['courtId'] is Map<String, dynamic>
        ? json['courtId'] as Map<String, dynamic>
        : null;
    final location = (court?['location'] as Map<String, dynamic>?) ?? const {};
    return Booking(
      id: json['_id'] as String,
      bookingCode: (json['bookingCode'] as String?) ?? 'N/A',
      courtId: court != null
          ? (court['_id'] ?? '').toString()
          : (json['courtId'] ?? '').toString(),
      courtName: (court?['name'] as String?) ?? 'Cancha',
      city: (location['city'] as String?) ?? '',
      date: DateTime.parse(json['date'] as String),
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      totalPrice: (json['totalPrice'] as num?)?.toInt() ?? 0,
      netoDueno: (json['netoDueno'] as num?)?.toInt(),
      status: (json['status'] as String?) ?? 'pending',
      guestEmail: (json['guestEmail'] as String?) ?? '',
      guestName: (json['guestName'] as String?) ?? '',
      paymentMethod: (json['paymentMethod'] as String?) ?? 'epayco',
      guestPhone: (json['guestPhone'] as String?) ?? '',
      notes: (json['notes'] as String?)?.trim().isEmpty ?? true
          ? null
          : (json['notes'] as String).trim(),
      cancelToken: json['cancelToken'] as String?,
      origen: (json['origen'] as String?) ?? 'online',
      serieId: json['serieId'] as String?,
      serieSemanas: ((json['serie'] as Map?)?['semanas'] as num?)?.toInt(),
      serieTotal: ((json['serie'] as Map?)?['total'] as num?)?.toInt(),
    );
  }
}

/// `STATUS_STYLES` de `mis-reservas/page.tsx`.
class BookingStatusStyle {
  const BookingStatusStyle({
    required this.pillBackground,
    required this.pillForeground,
    required this.dot,
    required this.label,
  });

  final Color pillBackground;
  final Color pillForeground;
  final Color dot;
  final String label;
}

const _statusStyles = <String, BookingStatusStyle>{
  'pending': BookingStatusStyle(
    pillBackground: Color(0xFFFEF9C3), // yellow-100
    pillForeground: Color(0xFFA16207), // yellow-700
    dot: Color(0xFFFACC15), // yellow-400
    label: 'Sin pagar',
  ),
  'confirmed': BookingStatusStyle(
    pillBackground: Color(0xFFDCFCE7), // green-100
    pillForeground: Color(0xFF15803D), // green-700
    dot: Color(0xFF22C55E), // green-500
    label: 'Confirmada',
  ),
  'reagendada': BookingStatusStyle(
    pillBackground: Color(0xFFFEE2E2), // red-100
    pillForeground: Color(0xFFDC2626), // red-600
    dot: Color(0xFFF87171), // red-400
    label: 'Reagendada',
  ),
  'completed': BookingStatusStyle(
    pillBackground: Color(0xFFDBEAFE), // blue-100
    pillForeground: Color(0xFF1D4ED8), // blue-700
    dot: Color(0xFF60A5FA), // blue-400
    label: 'Completada',
  ),
};

BookingStatusStyle bookingStatusStyle(String status) =>
    _statusStyles[status] ?? _statusStyles['pending']!;
