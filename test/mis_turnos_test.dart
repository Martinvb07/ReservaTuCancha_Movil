import 'package:flutter_test/flutter_test.dart';
import 'package:reservatucancha/data/mis_turnos.dart';
import 'package:reservatucancha/models/booking.dart';

Booking reserva(String id, String fecha, String inicio, {String code = 'N/A', String status = 'confirmed', String cancha = 'c1', String nombre = 'Los Pinos'}) {
  final p = inicio.split(':');
  final fin = '${(int.parse(p[0]) + 1).toString().padLeft(2, '0')}:${p[1]}';
  return Booking.fromJson({
    '_id': id,
    'bookingCode': code,
    'date': '${fecha}T05:00:00.000Z',
    'startTime': inicio,
    'endTime': fin,
    'status': status,
    'courtId': {'_id': cancha, 'name': nombre, 'sport': 'futbol', 'location': {'city': 'Barranquilla', 'address': 'Cra 50', 'coordinates': [-74.8, 10.9]}},
  });
}

void main() {
  // "Ahora" en Bogotá: 3 de noviembre de 2030, 3:00 pm.
  final ahora = DateTime.utc(2030, 11, 3, 15);

  test('el próximo turno es el más cercano que no ha terminado', () {
    final r = resumirTurnos([
      reserva('a', '2030-11-01', '19:00'), // ya pasó
      reserva('b', '2030-11-05', '20:00'),
      reserva('c', '2030-11-03', '18:00'), // hoy, más tarde
      reserva('d', '2030-11-03', '10:00', status: 'pending'),
    ], const [], ahora);
    expect(r.proximo?.id, 'c');
    expect(r.proximo?.lat, 10.9);
  });

  test('un turno que está en juego sigue siendo el próximo', () {
    final r = resumirTurnos([reserva('a', '2030-11-03', '14:30')], const [], ahora);
    expect(r.proximo?.id, 'a');
  });

  test('la reserva guardada en el teléfono aporta el código del QR', () {
    final remota = reserva('x', '2030-11-04', '19:00');
    final local = reserva('x', '2030-11-04', '19:00', code: 'ABCD1234');
    final r = resumirTurnos([remota], [local], ahora);
    expect(r.proximo?.bookingCode, 'ABCD1234');
    expect(tieneCodigo(r.proximo!), isTrue);
    expect(tieneCodigo(remota), isFalse);
  });

  test('volver a jugar ordena por las canchas más jugadas y su hora de siempre', () {
    final r = resumirTurnos([
      reserva('1', '2030-10-01', '19:00', cancha: 'c1'),
      reserva('2', '2030-10-08', '19:00', cancha: 'c1'),
      reserva('3', '2030-10-15', '20:00', cancha: 'c1'),
      reserva('4', '2030-10-02', '09:00', cancha: 'c2', nombre: 'El Bosque'),
    ], const [], ahora);
    expect(r.frecuentes.map((f) => f.courtId), ['c1', 'c2']);
    expect(r.frecuentes.first.veces, 3);
    expect(r.frecuentes.first.horaUsual, '19:00');
    expect(r.proximo, isNull);
    expect(r.hayAlgo, isTrue);
  });

  test('sin reservas no hay nada que mostrar', () {
    expect(resumirTurnos(const [], const [], ahora).hayAlgo, isFalse);
  });
}
