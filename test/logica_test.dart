import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:reservatucancha/api/bookings_api.dart';
import 'package:reservatucancha/api/courts_api.dart';
import 'package:reservatucancha/data/preferencias.dart';
import 'package:reservatucancha/data/ubicacion.dart';
import 'package:reservatucancha/data/version_app.dart';
import 'package:reservatucancha/models/booking.dart';
import 'package:reservatucancha/models/court.dart';
import 'package:reservatucancha/widgets/acciones_reserva.dart';
import 'package:reservatucancha/widgets/etiqueta_cupo.dart';
import 'package:shared_preferences/shared_preferences.dart';

Booking _reserva(Map<String, dynamic> extra) => Booking.fromJson({
  '_id': 'b1',
  'bookingCode': 'AB12CD34',
  'date': '2026-11-05T00:00:00.000Z',
  'startTime': '20:00',
  'endTime': '21:00',
  'totalPrice': 92000,
  'status': 'confirmed',
  ...extra,
});

void main() {
  group('versiones de la app', () {
    test('compara numero por numero, no como texto', () {
      expect(compararVersiones('1.2.10', '1.2.9'), greaterThan(0));
      expect(compararVersiones('1.0.0+5', '1.0.0'), 0);
      expect(compararVersiones('2.0', '2.0.1'), lessThan(0));
    });

    test(
      'obliga por debajo de la minima y sugiere por debajo de la ultima',
      () {
        expect(
          estadoPara('1.0.0', '1.1.0', '1.2.0'),
          EstadoVersion.obligatoria,
        );
        expect(estadoPara('1.1.5', '1.1.0', '1.2.0'), EstadoVersion.sugerida);
        expect(estadoPara('1.2.0', '1.1.0', '1.2.0'), EstadoVersion.alDia);
      },
    );
  });

  group('QR de la reserva', () {
    Booking reserva(String id, String codigo) => Booking.fromJson({
      '_id': id,
      'bookingCode': codigo,
      'date': '2030-03-04T05:00:00.000Z',
      'startTime': '19:00',
      'endTime': '20:00',
    });

    test('ida y vuelta del codigo', () {
      final qr = qrDeReserva(reserva('b1', 'AB12CD34'));
      expect(qr, 'https://reservatucancha.site/r/AB12CD34');
      expect(codigoDesdeQr(qr), 'AB12CD34');
      // El formato viejo sigue funcionando en el escáner.
      expect(codigoDesdeQr('RTC:ab12cd34'), 'AB12CD34');
    });

    test('sin código (búsqueda por correo) el QR lleva el identificador', () {
      final qr = qrDeReserva(reserva('665f1a2b3c4d5e6f7a8b9c0d', 'N/A'));
      expect(qr, 'https://reservatucancha.site/r/665f1a2b3c4d5e6f7a8b9c0d');
      expect(leerQr(qr), (codigo: null, id: '665f1a2b3c4d5e6f7a8b9c0d'));
      expect(leerQr('RTC:ID:665f1a2b3c4d5e6f7a8b9c0d'), (
        codigo: null,
        id: '665f1a2b3c4d5e6f7a8b9c0d',
      ));
      expect(codigoDesdeQr(qr), isNull);
    });

    test('ignora QR que no son nuestros', () {
      expect(codigoDesdeQr('https://otra-cosa.com'), isNull);
      expect(codigoDesdeQr('RTC:'), isNull);
      expect(leerQr('RTC:ID:'), isNull);
      expect(leerQr('https://reservatucancha.site/canchas/123'), isNull);
      expect(leerQr('https://otro.com/r/ABCD1234'), isNull);
      expect(codigoDesdeQr(null), isNull);
    });
  });

  test('reservar de nuevo cae el proximo mismo dia de la semana', () {
    final jueves = DateTime(2026, 10, 29);
    final hoyLunes = DateTime(2026, 11, 2);
    final d = proximoMismoDia(jueves, hoyLunes);
    expect(d.weekday, DateTime.thursday);
    expect(d, DateTime(2026, 11, 5));
    // Si hoy es jueves, la proxima es la otra semana, no hoy.
    expect(
      proximoMismoDia(jueves, DateTime(2026, 11, 5)),
      DateTime(2026, 11, 12),
    );
  });

  test('distancias legibles', () {
    expect(textoDistancia(0.85), 'a 850 m');
    expect(textoDistancia(2.34), 'a 2,3 km');
    expect(textoDistancia(15.4), 'a 15 km');
  });

  group('comodidades', () {
    test('reconoce variantes por palabra clave y sin tildes', () {
      expect(amenityIcon('Luz nocturna'), LucideIcons.lightbulb);
      expect(amenityIcon('iluminación LED'), LucideIcons.lightbulb);
      expect(amenityIcon('WIFI gratis'), LucideIcons.wifi);
      expect(amenityIcon('algo raro'), LucideIcons.circleCheck);
    });

    test('nombres cortos para los mosaicos', () {
      expect(amenityCorta('Luz nocturna'), 'Iluminación');
      expect(amenityCorta('Parqueadero'), 'Parqueo');
      expect(amenityCorta('duchas'), 'Duchas');
    });
  });

  group('montos del dueño', () {
    test('usa el neto cuando viene y el total en reservas viejas', () {
      expect(_reserva({'netoDueno': 86039}).netoParaDueno, 86039);
      expect(_reserva({}).netoParaDueno, 92000);
    });

    test('la reserva guarda el id de su cancha', () {
      final b = _reserva({
        'courtId': {'_id': 'c9', 'name': 'El Golazo'},
      });
      expect(b.courtId, 'c9');
      expect(b.courtName, 'El Golazo');
    });
  });

  test('config de pagos con tarifa por defecto', () {
    expect(PagosConfig.fromJson({}).tarifaServicio, 2000);
    expect(
      PagosConfig.fromJson({
        'configured': true,
        'tarifaServicio': 2500,
      }).tarifaServicio,
      2500,
    );
  });

  test('formato de pesos con punto de miles', () {
    expect(formatCop(1234567), '1.234.567');
    expect(formatCop(900), '900');
  });

  testWidgets('la etiqueta de cupo dice cuantos quedan o que no hay', (
    t,
  ) async {
    await t.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            EtiquetaCupo(
              disponibilidad: Disponibilidad(libres: 1, proximo: '19:00'),
            ),
            EtiquetaCupo(disponibilidad: Disponibilidad(libres: 0)),
          ],
        ),
      ),
    );
    expect(find.textContaining('1 libre hoy'), findsOneWidget);
    expect(find.text('Sin cupo hoy'), findsOneWidget);
  });

  test('favoritos se marcan, se desmarcan y se recuerdan', () async {
    SharedPreferences.setMockInitialValues({});
    final p = Preferencias.instance;
    await p.cargar();
    await p.alternarFavorita('c1');
    expect(p.esFavorita('c1'), isTrue);
    await p.alternarFavorita('c1');
    expect(p.esFavorita('c1'), isFalse);
    expect(p.bienvenidaVista, isFalse);
    await p.marcarBienvenidaVista();
    expect(p.bienvenidaVista, isTrue);
  });
}
