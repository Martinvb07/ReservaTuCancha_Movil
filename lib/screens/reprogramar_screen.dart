import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/bookings_api.dart';
import '../api/courts_api.dart';
import '../api/rtc_api.dart';
import '../app/routes.dart';
import '../models/booking.dart';
import '../models/court.dart';
import '../models/fechas.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Port de `Frontend/src/app/(public)/reservas/reprogramar/page.tsx`.
///
/// Se entra con el `token` del correo de confirmacion. La reserva conserva
/// cancha y duracion: solo cambia cuando se juega. El backend vuelve a
/// validar todo (plazo de 24 horas, cruces), asi que aca solo se ayuda a
/// elegir un turno que tenga sentido.
class ReprogramarScreen extends StatefulWidget {
  const ReprogramarScreen({super.key, required this.token});

  final String token;

  @override
  State<ReprogramarScreen> createState() => _ReprogramarScreenState();
}

class _ReprogramarScreenState extends State<ReprogramarScreen> {
  Booking? _reserva;
  List<AvailabilitySlot> _horario = const [];
  String _courtId = '';
  bool _cargando = true;
  String? _error;

  DateTime? _dia;
  String? _hora;
  Set<String> _tomados = const {};
  bool _cargandoTurnos = false;
  bool _guardando = false;
  bool _listo = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      // Se lee crudo: la cancha llega con su horario de atencion, que el
      // modelo de reserva no guarda.
      final data =
          await RtcApi.instance.get(
                '/bookings/cancel-info',
                query: {'token': widget.token},
              )
              as Map<String, dynamic>;
      final cancha = data['courtId'] is Map<String, dynamic>
          ? data['courtId'] as Map<String, dynamic>
          : const <String, dynamic>{};
      if (!mounted) return;
      setState(() {
        _reserva = Booking.fromJson(data);
        _courtId = (cancha['_id'] ?? '').toString();
        _horario =
            (cancha['availability'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(AvailabilitySlot.fromJson)
                .toList() ??
            const [];
        _cargando = false;
      });
    } on RtcApiException {
      if (!mounted) return;
      setState(() {
        _error = 'El link expiró o la reserva ya no se puede cambiar.';
        _cargando = false;
      });
    }
  }

  int get _duracion {
    final r = _reserva!;
    return _min(r.endTime) - _min(r.startTime);
  }

  static int _min(String hhmm) {
    final p = hhmm.split(':').map(int.parse).toList();
    return p[0] * 60 + p[1];
  }

  static String _hhmm(int min) =>
      '${(min ~/ 60).toString().padLeft(2, '0')}:'
      '${(min % 60).toString().padLeft(2, '0')}';

  /// Los proximos 14 dias en que el club atiende.
  List<DateTime> get _dias {
    final abiertos = _horario.map((h) => h.dayOfWeek % 7).toSet();
    final hoy = ahoraEnBogota();
    final base = DateTime(hoy.year, hoy.month, hoy.day);
    final out = <DateTime>[];
    for (var i = 0; i < 45 && out.length < 14; i++) {
      final d = base.add(Duration(days: i));
      if (abiertos.contains(d.weekday % 7)) out.add(d);
    }
    return out;
  }

  List<String> get _turnos {
    final dia = _dia;
    if (dia == null) return const [];
    final regla = _horario
        .where((h) => h.dayOfWeek % 7 == dia.weekday % 7)
        .firstOrNull;
    if (regla == null) return const [];
    final paso = regla.slotDurationMinutes;
    final abre = _min(regla.openTime);
    final cierra = regla.closeTime == '00:00' ? 24 * 60 : _min(regla.closeTime);
    return [for (var t = abre; t + _duracion <= cierra; t += paso) _hhmm(t)];
  }

  Future<void> _elegirDia(DateTime d) async {
    setState(() {
      _dia = d;
      _hora = null;
      _cargandoTurnos = true;
    });
    final fecha = fechaIso(d);
    try {
      final r = await Future.wait([
        bookingsApi.takenSlots(_courtId, fecha),
        courtsApi.blockedSlots(_courtId, fecha),
      ]);
      if (!mounted) return;
      final tomados = <String>{};
      for (final rango in [...r[0], ...r[1]]) {
        for (final t in _turnos) {
          if (_min(t) < _min(rango.endTime) &&
              _min(t) + _duracion > _min(rango.startTime)) {
            tomados.add(t);
          }
        }
      }
      setState(() {
        _tomados = tomados;
        _cargandoTurnos = false;
      });
    } on RtcApiException {
      if (!mounted) return;
      setState(() => _cargandoTurnos = false);
    }
  }

  bool _noDisponible(String t) {
    final r = _reserva!;
    final dia = _dia!;
    // Su propio turno se puede volver a elegir: no choca consigo misma.
    final suyo = fechaIso(dia) == fechaIso(r.date) && t == r.startTime;
    if (suyo) return false;
    if (_tomados.contains(t)) return true;
    final ahora = ahoraEnBogota();
    if (fechaIso(dia) == fechaIso(ahora)) {
      return _min(t) <= ahora.hour * 60 + ahora.minute;
    }
    return false;
  }

  Future<void> _guardar() async {
    final hora = _hora;
    final dia = _dia;
    if (hora == null || dia == null || _guardando) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await bookingsApi.reprogramar(
        token: widget.token,
        date: fechaIso(dia),
        startTime: hora,
        endTime: _hhmm(_min(hora) + _duracion),
      );
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _listo = true;
      });
    } on RtcApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator(color: Green.c600));
    }
    final reserva = _reserva;
    if (reserva == null) {
      return _Mensaje(
        icono: LucideIcons.circleX,
        titulo: 'No se puede cambiar',
        texto: _error ?? 'El link no es válido.',
      );
    }
    if (_listo) {
      return _Mensaje(
        icono: LucideIcons.circleCheck,
        titulo: 'Horario cambiado',
        texto:
            'Tu reserva quedó para el ${fechaLargaCapitalizada(_dia!)} a las '
            '${hora12(_hora!)}. Te enviamos la confirmación al correo.',
        ok: true,
      );
    }

    final turnos = _turnos;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
      children: [
        Text(
          'Cambiar horario',
          style: RtcType.sm.copyWith(
            color: Green.c700,
            fontWeight: RtcType.semibold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          reserva.courtName,
          style: RtcType.xl2.copyWith(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: Gray.c900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Hoy: ${fechaLargaCapitalizada(reserva.date)}, '
          '${hora12(reserva.startTime)} – ${hora12(reserva.endTime)}',
          style: RtcType.sm.copyWith(color: Gray.c500),
        ),
        const SizedBox(height: RtcSpace.s6),
        _Tarjeta(
          titulo: 'Elige el nuevo día',
          child: SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _dias.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final d = _dias[i];
                final activo = _dia != null && fechaIso(_dia!) == fechaIso(d);
                return GestureDetector(
                  onTap: () => _elegirDia(d),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 62,
                    decoration: BoxDecoration(
                      color: activo ? Green.c600 : Fondo.app,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          diasCortos[d.weekday % 7],
                          style: RtcType.xs.copyWith(
                            color: activo ? Colors.white70 : Gray.c500,
                          ),
                        ),
                        Text(
                          '${d.day}',
                          style: RtcType.lg.copyWith(
                            fontWeight: FontWeight.w800,
                            color: activo ? Colors.white : Gray.c900,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        if (_dia != null) ...[
          const SizedBox(height: RtcSpace.s4),
          _Tarjeta(
            titulo: 'Elige la hora',
            child: _cargandoTurnos
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(
                      child: CircularProgressIndicator(color: Green.c600),
                    ),
                  )
                : turnos.isEmpty
                ? Text(
                    'Ese día no hay turnos.',
                    style: RtcType.sm.copyWith(color: Gray.c500),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final t in turnos)
                        _Turno(
                          texto: hora12(t),
                          activo: _hora == t,
                          deshabilitado: _noDisponible(t),
                          onTap: () => setState(() => _hora = t),
                        ),
                    ],
                  ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: RtcSpace.s3),
          Text(_error!, style: RtcType.sm.copyWith(color: Red.c500)),
        ],
        const SizedBox(height: RtcSpace.s5),
        Opacity(
          opacity: _hora == null ? 0.4 : 1,
          child: GestureDetector(
            onTap: _hora == null ? null : _guardar,
            child: Container(
              height: 54,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Green.c600,
                borderRadius: RtcRadius.brFull,
              ),
              child: _guardando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      'Mover mi reserva',
                      style: RtcType.base.copyWith(
                        fontWeight: RtcType.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: RtcSpace.s3),
        Text(
          'Se puede cambiar hasta 24 horas antes del turno. El valor pagado se '
          'conserva completo.',
          textAlign: TextAlign.center,
          style: RtcType.xs.copyWith(color: Gray.c500),
        ),
      ],
    );
  }
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.titulo, required this.child});

  final String titulo;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            style: RtcType.base.copyWith(
              fontWeight: FontWeight.w700,
              color: Gray.c900,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Turno extends StatelessWidget {
  const _Turno({
    required this.texto,
    required this.activo,
    required this.deshabilitado,
    required this.onTap,
  });

  final String texto;
  final bool activo;
  final bool deshabilitado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: deshabilitado ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: activo
              ? Green.c600
              : deshabilitado
              ? Fondo.app
              : Colors.white,
          borderRadius: RtcRadius.brFull,
          border: Border.all(color: activo ? Green.c600 : Gray.c200),
        ),
        child: Text(
          texto,
          style: RtcType.sm.copyWith(
            fontWeight: RtcType.semibold,
            color: activo
                ? Colors.white
                : deshabilitado
                ? Gray.c300
                : Gray.c800,
            decoration: deshabilitado ? TextDecoration.lineThrough : null,
          ),
        ),
      ),
    );
  }
}

/// Estado final o de error, centrado, con el boton para volver.
class _Mensaje extends StatelessWidget {
  const _Mensaje({
    required this.icono,
    required this.titulo,
    required this.texto,
    this.ok = false,
  });

  final IconData icono;
  final String titulo;
  final String texto;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: ok ? Green.c50 : const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, size: 34, color: ok ? Green.c600 : Red.c500),
            ),
            const SizedBox(height: 16),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: RtcType.xl.copyWith(
                fontWeight: FontWeight.w800,
                color: Gray.c900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              texto,
              textAlign: TextAlign.center,
              style: RtcType.sm.copyWith(color: Gray.c500),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => rtcNavigate('/mis-reservas'),
              child: Text(
                'Ver mis reservas',
                style: RtcType.sm.copyWith(
                  fontWeight: RtcType.bold,
                  color: Green.c700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
