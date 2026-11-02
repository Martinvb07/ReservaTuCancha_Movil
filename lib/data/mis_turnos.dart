/// Las reservas del jugador para "Mi turno" en el inicio, sin cuenta.
///
/// Salen de dos lados:
/// - las que se pagaron desde este teléfono, que la app guarda al confirmarse
///   el pago, con su código (el QR funciona hasta sin internet);
/// - las que encuentra la búsqueda por el correo guardado del jugador (las de
///   la web u otro teléfono). Esa búsqueda no trae el código, así que esas
///   se ven sin QR.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/booking.dart';

class MisTurnos {
  MisTurnos._();

  static final MisTurnos instance = MisTurnos._();

  static const _k = 'rtc.misTurnos';

  /// Avisa al inicio que hay un turno nuevo para recargar "Mi turno".
  final cambios = ValueNotifier<int>(0);
  static const _max = 40;

  Future<List<Booking>> locales() async {
    try {
      final p = await SharedPreferences.getInstance();
      return (p.getStringList(_k) ?? const [])
          .map((t) => Booking.fromJson(jsonDecode(t) as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Se llama al confirmarse el pago de una reserva hecha en este teléfono.
  Future<void> guardar(Booking b) async {
    try {
      final p = await SharedPreferences.getInstance();
      final lista = (p.getStringList(_k) ?? [])
        ..removeWhere((t) => (jsonDecode(t) as Map)['_id'] == b.id)
        ..add(jsonEncode(b.toJson()));
      while (lista.length > _max) {
        lista.removeAt(0);
      }
      await p.setStringList(_k, lista);
      cambios.value++;
    } catch (_) {}
  }
}

/// Una cancha donde ya jugó, para "Volver a jugar".
class CanchaFrecuente {
  const CanchaFrecuente({
    required this.courtId,
    required this.nombre,
    required this.deporte,
    required this.veces,
    required this.horaUsual,
  });

  final String courtId;
  final String nombre;
  final String deporte;
  final int veces;

  /// La hora a la que más reserva ahí ("19:00").
  final String horaUsual;
}

class ResumenTurnos {
  const ResumenTurnos({this.proximo, this.frecuentes = const []});

  final Booking? proximo;
  final List<CanchaFrecuente> frecuentes;

  bool get hayAlgo => proximo != null || frecuentes.isNotEmpty;
}

const _activas = {'confirmed', 'reagendada'};

/// Junta las dos fuentes (sin repetir; la local gana porque trae el código)
/// y calcula el próximo turno y las canchas a las que vuelve.
ResumenTurnos resumirTurnos(
  List<Booking> remotas,
  List<Booking> locales,
  DateTime ahoraBogota,
) {
  final porId = <String, Booking>{for (final b in remotas) b.id: b};
  for (final b in locales) {
    final remota = porId[b.id];
    // La remota trae el estado al día (pudo moverse de horario); la local el código.
    porId[b.id] = remota == null ? b : _conCodigo(remota, b.bookingCode);
  }
  final todas = porId.values.toList();

  final pendientes =
      todas
          .where(
            (b) => _activas.contains(b.status) && b.fin.isAfter(ahoraBogota),
          )
          .toList()
        ..sort((a, b) => a.inicio.compareTo(b.inicio));

  final grupos = <String, List<Booking>>{};
  for (final b in todas.where(
    (b) => b.courtId.isNotEmpty && b.status != 'pending',
  )) {
    grupos.putIfAbsent(b.courtId, () => []).add(b);
  }
  final frecuentes = grupos.entries.map((e) {
    final horas = <String, int>{};
    for (final b in e.value) {
      horas[b.startTime] = (horas[b.startTime] ?? 0) + 1;
    }
    final usual =
        (horas.entries.toList()..sort((a, b) => b.value.compareTo(a.value)))
            .first
            .key;
    final una = e.value.first;
    return CanchaFrecuente(
      courtId: e.key,
      nombre: una.courtName,
      deporte: una.deporte,
      veces: e.value.length,
      horaUsual: usual,
    );
  }).toList()..sort((a, b) => b.veces.compareTo(a.veces));

  return ResumenTurnos(
    proximo: pendientes.isEmpty ? null : pendientes.first,
    frecuentes: frecuentes.take(5).toList(),
  );
}

Booking _conCodigo(Booking b, String codigo) {
  if (b.bookingCode != 'N/A' && b.bookingCode.isNotEmpty) return b;
  final json = b.toJson()..['bookingCode'] = codigo;
  return Booking.fromJson(json);
}

/// ¿Tiene QR? Las que llegan solo por la búsqueda de correo no traen código.
bool tieneCodigo(Booking b) =>
    b.bookingCode.isNotEmpty && b.bookingCode != 'N/A';
