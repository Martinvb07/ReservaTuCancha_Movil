import 'package:flutter_test/flutter_test.dart';
import 'package:reservatucancha/models/precios.dart';

void main() {
  const reglas = [
    ReglaPrecio(
      days: [1, 2, 3, 4, 5],
      from: '18:00',
      to: '00:00',
      pricePerHour: 90000,
    ),
    ReglaPrecio(days: [0, 6], from: '06:00', to: '00:00', pricePerHour: 100000),
  ];

  test('sin reglas cobra el precio base prorrateado', () {
    expect(precioTurno(60000, const [], 2, '09:00', '10:00'), 60000);
    expect(precioTurno(60000, const [], 2, '09:00', '10:30'), 90000);
  });

  test('aplica la franja del dia y la hora, igual que el backend', () {
    expect(precioTurno(60000, reglas, 2, '19:00', '20:00'), 90000);
    expect(precioTurno(60000, reglas, 2, '10:00', '11:00'), 60000);
    expect(precioTurno(60000, reglas, 6, '10:00', '11:00'), 100000);
    // Cruza de franja: media hora a 60.000 y media a 90.000.
    expect(precioTurno(60000, reglas, 2, '17:30', '18:30'), 75000);
    // "00:00" como fin es la medianoche.
    expect(precioTurno(60000, reglas, 2, '23:00', '00:00'), 90000);
  });

  test('el dia de la semana se cuenta como en JavaScript', () {
    expect(diaSemanaJs(DateTime(2030, 3, 3)), 0); // domingo
    expect(diaSemanaJs(DateTime(2030, 3, 4)), 1); // lunes
    expect(precioMinimo(60000, reglas), 60000);
  });
}
