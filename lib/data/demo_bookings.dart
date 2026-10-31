import '../models/booking.dart';

/// Reservas de ejemplo para poder recorrer los cuatro estados de la pantalla
/// (sin buscar, cargando, sin resultados, con resultados) antes de conectar
/// `/bookings/public`.
final demoBookings = <Booking>[
  Booking(
    id: 'b1',
    bookingCode: 'A7F3K2M9',
    courtName: 'Cancha Sintética 1',
    city: 'Villavicencio',
    date: DateTime.now().add(const Duration(days: 3)),
    startTime: '19:00',
    endTime: '20:00',
    totalPrice: 80000,
    status: 'confirmed',
    guestEmail: 'martindavidvb@gmail.com',
    cancelToken: 'tok-1',
  ),
  Booking(
    id: 'b2',
    bookingCode: 'Q4X8N1P6',
    courtName: 'Pádel Center Cancha A',
    city: 'Villavicencio',
    date: DateTime.now().add(const Duration(days: 8)),
    startTime: '17:00',
    endTime: '18:00',
    totalPrice: 120000,
    status: 'pending',
    guestEmail: 'martindavidvb@gmail.com',
    cancelToken: 'tok-2',
  ),
  Booking(
    id: 'b3',
    bookingCode: 'Z2C5V7B3',
    courtName: 'Arena Voley Playa',
    city: 'Acacías',
    date: DateTime.now().subtract(const Duration(days: 12)),
    startTime: '10:00',
    endTime: '11:00',
    totalPrice: 60000,
    status: 'completed',
    guestEmail: 'martindavidvb@gmail.com',
  ),
];
