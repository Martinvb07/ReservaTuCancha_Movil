/// Las rutas del panel del propietario. TODAS piden JWT: es la primera parte
/// de la app donde la sesion se usa de verdad.
library;

import '../models/booking.dart';
import '../models/court.dart';
import 'rtc_api.dart';

/// `GET /analytics/owner` — ver `analytics.service.ts:96`.
class OwnerStats {
  const OwnerStats({
    required this.totalBookings,
    required this.confirmedBookings,
    required this.pendingBookings,
    required this.cancelledBookings,
    required this.completedBookings,
    required this.totalRevenue,
    required this.confirmRate,
    required this.totalCourts,
    required this.avgRevenue,
  });

  final int totalBookings;
  final int confirmedBookings;
  final int pendingBookings;
  final int cancelledBookings;
  final int completedBookings;
  final int totalRevenue;

  /// Porcentaje de reservas que terminan confirmadas.
  final double confirmRate;

  final int totalCourts;
  final int avgRevenue;

  factory OwnerStats.fromJson(Map<String, dynamic> json) => OwnerStats(
    totalBookings: (json['totalBookings'] as num?)?.toInt() ?? 0,
    confirmedBookings: (json['confirmedBookings'] as num?)?.toInt() ?? 0,
    pendingBookings: (json['pendingBookings'] as num?)?.toInt() ?? 0,
    cancelledBookings: (json['cancelledBookings'] as num?)?.toInt() ?? 0,
    completedBookings: (json['completedBookings'] as num?)?.toInt() ?? 0,
    totalRevenue: (json['totalRevenue'] as num?)?.toInt() ?? 0,
    confirmRate: (json['confirmRate'] as num?)?.toDouble() ?? 0,
    totalCourts: (json['totalCourts'] as num?)?.toInt() ?? 0,
    avgRevenue: (json['avgRevenue'] as num?)?.toInt() ?? 0,
  );
}

class OwnerApi {
  const OwnerApi();

  Future<OwnerStats> stats() async {
    final data = await RtcApi.instance.get('/analytics/owner', auth: true);
    return OwnerStats.fromJson(data as Map<String, dynamic>);
  }

  /// Las dos peticiones de la pantalla de Analytics, en paralelo como el
  /// `Promise.all` de la web.
  Future<(OwnerAnalytics, List<MesAnalytics>)> analytics() async {
    final r = await Future.wait([
      RtcApi.instance.get('/analytics/owner', auth: true),
      RtcApi.instance.get('/analytics/owner/monthly', auth: true),
    ]);
    return (
      OwnerAnalytics.fromJson(r[0] as Map<String, dynamic>),
      (r[1] as List?)
              ?.whereType<Map<String, dynamic>>()
              .map(MesAnalytics.fromJson)
              .toList() ??
          const <MesAnalytics>[],
    );
  }

  /// `GET /courts/owner/my-courts`.
  Future<List<Court>> misCanchas() async {
    final data = await RtcApi.instance.get(
      '/courts/owner/my-courts',
      auth: true,
    );
    // El backend devuelve una lista pelada, pero la web contempla `data.data`
    // por si algun dia se pagina.
    final lista = data is Map<String, dynamic>
        ? data['data'] as List?
        : data as List?;
    return lista
            ?.whereType<Map<String, dynamic>>()
            .map(Court.fromJson)
            .toList() ??
        const [];
  }

  /// `PATCH /courts/:id` para prender o apagar una cancha.
  ///
  /// OJO: la web manda `{ isActive: undefined }`, que en JSON no viaja — o sea
  /// que su boton no cambia nada. Aca se manda el valor invertido, que es lo
  /// que el boton dice que hace.
  Future<void> activarCancha(String id, bool activa) => RtcApi.instance.patch(
    '/courts/$id',
    body: {'isActive': activa},
    auth: true,
  );

  /// `PATCH /courts/:id` con todo el formulario de edicion.
  Future<void> actualizarCancha(
    String id, {
    required String nombre,
    required String descripcion,
    required String direccion,
    required String ciudad,
    required String departamento,
    required int precioPorHora,
    required List<AvailabilitySlot> disponibilidad,
    required List<String> comodidades,
    List<double>? coordenadas,
  }) => RtcApi.instance.patch(
    '/courts/$id',
    body: {
      'name': nombre,
      'description': descripcion,
      'location': {
        'address': direccion,
        'city': ciudad,
        'department': departamento,
        // Mongo guarda GeoJSON: [lng, lat]
        'coordinates': ?coordenadas,
      },
      'pricePerHour': precioPorHora,
      'availability': [
        for (final s in disponibilidad)
          {
            'dayOfWeek': s.dayOfWeek,
            'openTime': s.openTime,
            'closeTime': s.closeTime,
            'slotDurationMinutes': s.slotDurationMinutes,
          },
      ],
      'amenities': comodidades,
    },
    auth: true,
  );

  /// `DELETE /courts/:id`.
  Future<void> eliminarCancha(String id) =>
      RtcApi.instance.delete('/courts/$id', auth: true);

  /// `POST /courts` — crear la cancha. Devuelve la creada con su id, que hace
  /// falta para subirle las fotos despues.
  Future<Court> crearCancha({
    required String nombre,
    required String descripcion,
    required String deporte,
    required String direccion,
    required String ciudad,
    required String departamento,
    required int precioPorHora,
    required String moneda,
    required List<AvailabilitySlot> disponibilidad,
    required List<String> comodidades,
    List<double>? coordenadas,
  }) async {
    final data = await RtcApi.instance.post(
      '/courts',
      body: {
        'name': nombre,
        'description': descripcion,
        'sport': deporte,
        'location': {
          'address': direccion,
          'city': ciudad,
          'department': departamento,
          'coordinates': ?coordenadas,
        },
        'pricePerHour': precioPorHora,
        'currency': moneda,
        'availability': [
          for (final s in disponibilidad)
            {
              'dayOfWeek': s.dayOfWeek,
              'openTime': s.openTime,
              'closeTime': s.closeTime,
              'slotDurationMinutes': s.slotDurationMinutes,
            },
        ],
        'amenities': comodidades,
      },
      auth: true,
    );
    return Court.fromJson(data as Map<String, dynamic>);
  }

  /// `POST /courts/:id/photos` — le suma una foto ya subida a Cloudinary.
  Future<void> agregarFoto(String courtId, String url) => RtcApi.instance.post(
    '/courts/$courtId/photos',
    body: {'url': url},
    auth: true,
  );

  /// `GET /liquidaciones/mias` — lo que la plataforma le gira al club cada
  /// lunes, ya con la comision descontada.
  Future<Liquidaciones?> liquidaciones() async {
    try {
      final data = await RtcApi.instance.get('/liquidaciones/mias', auth: true);
      return Liquidaciones.fromJson(
        (data as Map<String, dynamic>?) ?? const {},
      );
    } on RtcApiException {
      return null;
    }
  }

  /// `PATCH /clubs/:id/banco` — la cuenta donde el club recibe el giro.
  Future<void> guardarCuentaBanco(String clubId, Map<String, dynamic> datos) =>
      RtcApi.instance.patch('/clubs/$clubId/banco', body: datos, auth: true);

  /// `GET /clubs/my-club` completo, para la pantalla de Mi Club.
  Future<ClubPerfil?> perfilClub() async {
    try {
      final data = await RtcApi.instance.get('/clubs/my-club', auth: true);
      return ClubPerfil.fromJson((data as Map<String, dynamic>?) ?? const {});
    } on RtcApiException {
      return null;
    }
  }

  /// `PATCH /clubs/my-club/profile`.
  Future<void> guardarPerfilClub(Map<String, dynamic> cuerpo) =>
      RtcApi.instance.patch('/clubs/my-club/profile', body: cuerpo, auth: true);

  /// `POST /clubs/my-club/photos`.
  Future<void> agregarFotoClub(String url) => RtcApi.instance.post(
    '/clubs/my-club/photos',
    body: {'url': url},
    auth: true,
  );

  /// `DELETE /clubs/my-club/photos` — la URL va en el cuerpo.
  Future<void> eliminarFotoClub(String url) => RtcApi.instance.delete(
    '/clubs/my-club/photos',
    body: {'url': url},
    auth: true,
  );

  /// `DELETE /courts/:id/photos` — la URL va en el cuerpo, no en la ruta.
  Future<void> eliminarFoto(String courtId, String url) => RtcApi.instance
      .delete('/courts/$courtId/photos', body: {'url': url}, auth: true);

  /// La galeria no tiene endpoint para reordenar: la web borra TODAS las
  /// fotos y las vuelve a agregar con la elegida de primera. Se copia igual
  /// para no inventar una ruta que el backend no tiene.
  Future<void> ponerFotoPrincipal(
    String courtId,
    String url,
    List<String> fotos,
  ) async {
    final nuevoOrden = [url, ...fotos.where((f) => f != url)];
    for (final f in fotos) {
      await eliminarFoto(courtId, f);
    }
    for (final f in nuevoOrden) {
      await agregarFoto(courtId, f);
    }
  }

  /// `GET /courts/blocked-slots/my` — los bloqueos de todas sus canchas.
  Future<List<BloqueoHorario>> bloqueos() async {
    final data = await RtcApi.instance.get(
      '/courts/blocked-slots/my',
      auth: true,
    );
    return (data as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(BloqueoHorario.fromJson)
            .toList() ??
        const [];
  }

  /// `POST /courts/blocked-slots`.
  Future<void> crearBloqueo({
    required String courtId,
    required String fecha,
    required String horaInicio,
    required String horaFin,
    required String motivo,
  }) => RtcApi.instance.post(
    '/courts/blocked-slots',
    body: {
      'courtId': courtId,
      'date': fecha,
      'startTime': horaInicio,
      'endTime': horaFin,
      'reason': motivo,
    },
    auth: true,
  );

  /// `DELETE /courts/blocked-slots/:slotId`.
  Future<void> eliminarBloqueo(String id) =>
      RtcApi.instance.delete('/courts/blocked-slots/$id', auth: true);

  /// `GET /bookings/owner` — las reservas de todas las canchas del dueno.
  Future<List<Booking>> reservas() async {
    final data = await RtcApi.instance.get('/bookings/owner', auth: true);
    return (data as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(Booking.fromJson)
            .toList() ??
        const [];
  }

  /// `PATCH /bookings/:id/status`.
  Future<void> cambiarEstado(String id, String estado) => RtcApi.instance.patch(
    '/bookings/$id/status',
    body: {'status': estado},
    auth: true,
  );

  /// `GET /clubs/my-club`, con el `ensure-slug` que dispara la web cuando el
  /// club todavia no tiene uno.
  Future<ClubInfo?> club() async {
    try {
      final data = await RtcApi.instance.get('/clubs/my-club', auth: true);
      var info = ClubInfo.fromJson((data as Map<String, dynamic>?) ?? const {});
      final slug = info.slug;
      if (slug == null || slug.isEmpty) {
        try {
          final s = await RtcApi.instance.get(
            '/clubs/my-club/ensure-slug',
            auth: true,
          );
          info = info.conSlug((s as Map<String, dynamic>?)?['slug'] as String?);
        } on RtcApiException {
          // La web se lo come en silencio: sin slug no dibuja esa tarjeta.
        }
      }
      return info;
    } on RtcApiException {
      return null;
    }
  }
}

const ownerApi = OwnerApi();

/// `GET /liquidaciones/mias` — ver `liquidaciones.service.ts:227`.
class Liquidaciones {
  const Liquidaciones({
    required this.comisionPorcentaje,
    required this.semanas,
  });

  final int comisionPorcentaje;
  final List<SemanaLiquidacion> semanas;

  factory Liquidaciones.fromJson(Map<String, dynamic> json) => Liquidaciones(
    comisionPorcentaje: (json['comisionPorcentaje'] as num?)?.toInt() ?? 9,
    semanas:
        (json['semanas'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(SemanaLiquidacion.fromJson)
            .toList() ??
        const [],
  );
}

class SemanaLiquidacion {
  const SemanaLiquidacion({
    required this.etiqueta,
    required this.inicio,
    required this.giro,
    required this.enCurso,
    required this.reservas,
    required this.bruto,
    required this.comision,
    required this.neto,
    required this.estado,
    required this.giradaAt,
  });

  final String etiqueta;
  final String inicio;
  final DateTime? giro;
  final bool enCurso;
  final int reservas;
  final int bruto;
  final int comision;
  final int neto;

  /// `pendiente` | `girada`.
  final String estado;

  final DateTime? giradaAt;

  bool get girada => estado == 'girada';

  factory SemanaLiquidacion.fromJson(Map<String, dynamic> json) {
    int n(String k) => (json[k] as num?)?.toInt() ?? 0;
    DateTime? f(String k) =>
        DateTime.tryParse((json[k] as String?) ?? '')?.toLocal();
    return SemanaLiquidacion(
      etiqueta: (json['etiqueta'] as String?) ?? '',
      inicio: (json['inicio'] as String?) ?? '',
      giro: f('giro'),
      enCurso: (json['enCurso'] as bool?) ?? false,
      reservas: n('reservas'),
      bruto: n('bruto'),
      comision: n('comision'),
      neto: n('neto'),
      estado: (json['estado'] as String?) ?? 'pendiente',
      giradaAt: f('giradaAt'),
    );
  }
}

/// `GET /clubs/my-club` completo — lo que edita la pantalla de Mi Club.
class ClubPerfil {
  const ClubPerfil({
    required this.id,
    required this.banco,
    required this.slug,
    required this.nombre,
    required this.slogan,
    required this.descripcion,
    required this.direccion,
    required this.ciudad,
    required this.telefono,
    required this.email,
    required this.horario,
    required this.logo,
    required this.instagram,
    required this.facebook,
    required this.tiktok,
    required this.whatsapp,
    required this.fotos,
  });

  /// Hace falta para `PATCH /clubs/:id/banco`.
  final String id;

  /// La cuenta donde se recibe el giro semanal. `null` si no se configuro.
  final Map<String, dynamic>? banco;

  final String? slug;
  final String nombre;
  final String slogan;
  final String descripcion;
  final String direccion;
  final String ciudad;
  final String telefono;
  final String email;
  final String horario;
  final String logo;
  final String instagram;
  final String facebook;
  final String tiktok;
  final String whatsapp;
  final List<String> fotos;

  factory ClubPerfil.fromJson(Map<String, dynamic> json) {
    final redes = (json['socialLinks'] as Map<String, dynamic>?) ?? const {};
    String s(Map<String, dynamic> m, String k) => (m[k] as String?) ?? '';
    final banco = json['banco'] as Map<String, dynamic>?;
    return ClubPerfil(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      banco: (banco?['metodo'] as String?)?.isNotEmpty ?? false ? banco : null,
      slug: json['slug'] as String?,
      nombre: s(json, 'name'),
      slogan: s(json, 'slogan'),
      descripcion: s(json, 'description'),
      direccion: s(json, 'address'),
      ciudad: s(json, 'city'),
      telefono: s(json, 'contactPhone'),
      email: s(json, 'contactEmail'),
      horario: s(json, 'schedule'),
      logo: s(json, 'logo'),
      instagram: s(redes, 'instagram'),
      facebook: s(redes, 'facebook'),
      tiktok: s(redes, 'tiktok'),
      whatsapp: s(redes, 'whatsapp'),
      fotos:
          (json['photos'] as List?)?.whereType<String>().toList() ?? const [],
    );
  }
}

/// Una fila de `GET /courts/blocked-slots/my`. El backend le pega el
/// `courtName` a mano (`courts.service.ts:186`), no viene del documento.
class BloqueoHorario {
  const BloqueoHorario({
    required this.id,
    required this.nombreCancha,
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
    required this.motivo,
  });

  final String id;
  final String nombreCancha;
  final DateTime fecha;
  final String horaInicio;
  final String horaFin;
  final String motivo;

  factory BloqueoHorario.fromJson(Map<String, dynamic> json) => BloqueoHorario(
    id: (json['_id'] as String?) ?? '',
    nombreCancha: (json['courtName'] as String?) ?? '-',
    fecha:
        DateTime.tryParse((json['date'] as String?) ?? '')?.toLocal() ??
        DateTime.now(),
    horaInicio: (json['startTime'] as String?) ?? '',
    horaFin: (json['endTime'] as String?) ?? '',
    motivo: (json['reason'] as String?) ?? '',
  );
}

/// `GET /clubs/my-club`. Al panel solo le importan el slug (para la pagina
/// publica del club) y si Wompi quedo configurado.
class ClubInfo {
  const ClubInfo({required this.slug, required this.wompiConfigured});

  final String? slug;
  final bool wompiConfigured;

  factory ClubInfo.fromJson(Map<String, dynamic> json) => ClubInfo(
    slug: json['slug'] as String?,
    wompiConfigured: (json['wompiConfigured'] as bool?) ?? false,
  );

  ClubInfo conSlug(String? nuevo) =>
      ClubInfo(slug: nuevo, wompiConfigured: wompiConfigured);
}

/// `GET /analytics/owner` completo, con lo que solo usa la pantalla de
/// Analytics: los desgloses por cancha, por dia y por hora.
class OwnerAnalytics {
  const OwnerAnalytics({
    required this.stats,
    required this.porCancha,
    required this.porDia,
    required this.porHora,
  });

  final OwnerStats stats;

  /// (nombre, reservas, ingresos, confirmadas), ya ordenado por ingresos.
  final List<(String, int, int, int)> porCancha;

  /// (dia, cantidad) — los siete, arrancando en domingo.
  final List<(String, int)> porDia;

  /// (hora, cantidad).
  final List<(String, int)> porHora;

  factory OwnerAnalytics.fromJson(Map<String, dynamic> json) => OwnerAnalytics(
    stats: OwnerStats.fromJson(json),
    porCancha:
        (json['courtStats'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(
              (c) => (
                (c['name'] as String?) ?? 'Cancha',
                (c['bookings'] as num?)?.toInt() ?? 0,
                (c['revenue'] as num?)?.toInt() ?? 0,
                (c['confirmed'] as num?)?.toInt() ?? 0,
              ),
            )
            .toList() ??
        const [],
    porDia:
        (json['dayStats'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(
              (d) => (
                (d['day'] as String?) ?? '',
                (d['count'] as num?)?.toInt() ?? 0,
              ),
            )
            .toList() ??
        const [],
    porHora:
        (json['hourStats'] as List?)
            ?.whereType<Map<String, dynamic>>()
            .map(
              (h) => (
                (h['hour'] as String?) ?? '',
                (h['count'] as num?)?.toInt() ?? 0,
              ),
            )
            .toList() ??
        const [],
  );
}

/// Una fila de `GET /analytics/owner/monthly`.
class MesAnalytics {
  const MesAnalytics({
    required this.mesCorto,
    required this.ingresos,
    required this.reservas,
  });

  final String mesCorto;
  final int ingresos;
  final int reservas;

  factory MesAnalytics.fromJson(Map<String, dynamic> json) => MesAnalytics(
    mesCorto: (json['monthShort'] as String?) ?? '',
    ingresos: (json['revenue'] as num?)?.toInt() ?? 0,
    reservas: (json['bookings'] as num?)?.toInt() ?? 0,
  );
}
