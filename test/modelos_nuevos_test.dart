import 'package:flutter_test/flutter_test.dart';
import 'package:reservatucancha/api/owner_api.dart';
import 'package:reservatucancha/models/auth_user.dart';
import 'package:reservatucancha/models/booking.dart';

void main() {
  test('la reserva que anota el club se reconoce y el turno fijo trae su resumen', () {
    final manual = Booking.fromJson({
      '_id': 'b1',
      'date': '2030-03-04T05:00:00.000Z',
      'startTime': '19:00',
      'endTime': '20:00',
      'origen': 'manual',
      'serieId': 's1',
      'serie': {'semanas': 4, 'total': 248000},
    });
    expect(manual.esManual, isTrue);
    expect(manual.serieId, 's1');
    expect(manual.serieSemanas, 4);
    expect(manual.serieTotal, 248000);

    final online = Booking.fromJson({
      '_id': 'b2',
      'date': '2030-03-04T05:00:00.000Z',
      'startTime': '19:00',
      'endTime': '20:00',
    });
    expect(online.esManual, isFalse);
    expect(online.serieId, isNull);
  });

  test('el empleado del club se recuerda entre sesiones', () {
    final u = AuthUser.fromJson({'id': 'u1', 'name': 'Ana', 'email': 'a@b.co', 'role': 'owner', 'esStaff': true});
    expect(u.esStaff, isTrue);
    expect(AuthUser.fromJson(u.toJson()).esStaff, isTrue);
    expect(AuthUser.fromJson({'role': 'owner'}).esStaff, isFalse);
  });

  test('la ocupación se lee por día y hora', () {
    final o = Ocupacion.fromJson({
      'semanas': 8,
      'canchas': [{'_id': 'c1', 'name': 'Cancha 1'}],
      'celdas': [
        {'dia': 1, 'hora': 19, 'capacidad': 8, 'ocupado': 6, 'pct': 75},
        {'dia': 1, 'hora': 18, 'capacidad': 8, 'ocupado': 0, 'pct': 0},
        {'dia': 2, 'hora': 7, 'capacidad': 0, 'ocupado': 0, 'pct': 0},
      ],
      'total': {'capacidad': 16, 'ocupado': 6, 'pct': 37.5},
      'horasVacias': [{'dia': 1, 'hora': 18, 'capacidad': 8, 'ocupado': 0, 'pct': 0}],
      'horasPico': [],
    });
    expect(o.horas, [18, 19]);
    expect(o.celda(1, 19)?.pct, 75);
    expect(o.celda(3, 19), isNull);
    expect(o.pctTotal, 37.5);
    expect(o.canchas.single.nombre, 'Cancha 1');
    expect(o.horasVacias.single.hora, 18);
  });
}
