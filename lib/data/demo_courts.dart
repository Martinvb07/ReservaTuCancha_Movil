import '../models/court.dart';

/// Datos de ejemplo para poder ver las pantallas antes de conectar el backend.
/// Cuando entre el cliente HTTP, esto se borra y las pantallas piden a
/// `/api/courts/featured` sin cambiar nada mas.
const demoCourts = <Court>[
  Court(
    id: '1',
    name: 'Cancha Sintética 1',
    sport: 'futbol',
    city: 'Villavicencio',
    department: 'Meta',
    pricePerHour: 80000,
    averageRating: 4.8,
    totalReviews: 34,
    photos: [
      'https://images.unsplash.com/photo-1529900748604-07564a03e7a6?w=1200&q=80',
    ],
    amenities: [
      'Parqueadero',
      'Luz nocturna',
      'Vestiarios',
      'Graderías',
      'Wi-Fi',
    ],
  ),
  Court(
    id: '2',
    name: 'Pádel Center Cancha A',
    sport: 'padel',
    city: 'Villavicencio',
    department: 'Meta',
    pricePerHour: 120000,
    averageRating: 4.9,
    totalReviews: 51,
    photos: [
      'https://images.unsplash.com/photo-1554068865-24cecd4e34b8?w=1200&q=80',
    ],
    amenities: ['Parqueadero', 'Cafetería', 'Duchas', 'Wi-Fi'],
  ),
  Court(
    id: '3',
    name: 'Arena Voley Playa',
    sport: 'voley_playa',
    city: 'Acacías',
    department: 'Meta',
    pricePerHour: 60000,
    averageRating: 4.6,
    totalReviews: 12,
    photos: [
      'https://images.unsplash.com/photo-1612872087720-bb876e2e67d1?w=1200&q=80',
    ],
    amenities: ['Luz nocturna', 'Graderías', 'Alquiler de equipos'],
  ),
  Court(
    id: '4',
    name: 'Cancha Sintética 2',
    sport: 'futbol',
    city: 'Villavicencio',
    department: 'Meta',
    pricePerHour: 95000,
    averageRating: 4.7,
    totalReviews: 28,
    photos: [
      'https://images.unsplash.com/photo-1459865264687-595d652de67e?w=1200&q=80',
    ],
    amenities: ['Parqueadero', 'Luz nocturna', 'Duchas'],
  ),
];
