import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/bookings_api.dart' show Disponibilidad;
import '../app/routes.dart';
import '../data/mis_turnos.dart';
import '../models/booking.dart';
import '../models/court.dart';
import '../models/fechas.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'acciones_reserva.dart';
import 'icons/sport_icon.dart';
import 'motion/rtc_pressable.dart';
import 'remote_image.dart';

/// Lo que sale en el inicio al tocar el chip "Mi turno": el próximo turno con
/// su QR y las canchas donde ya jugó.
class MiTurnoSeccion extends StatelessWidget {
  const MiTurnoSeccion({
    super.key,
    required this.resumen,
    required this.canchas,
    required this.cupo,
  });

  final ResumenTurnos resumen;

  /// Las canchas cargadas en el inicio, para sacar la foto de las frecuentes.
  final Map<String, Court> canchas;
  final Map<String, Disponibilidad> cupo;

  @override
  Widget build(BuildContext context) {
    final proximo = resumen.proximo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (proximo != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s5),
            child: TarjetaProximoTurno(booking: proximo),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s5),
            child: Text(
              'No tienes turnos pendientes. Cuando reserves, aquí verás tu próximo partido con su QR.',
              style: RtcType.sm.copyWith(color: Gray.c500),
            ),
          ),
        if (resumen.frecuentes.isNotEmpty) ...[
          const SizedBox(height: RtcSpace.s6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s5),
            child: Text(
              'Volver a jugar',
              style: RtcType.lg.copyWith(
                fontWeight: FontWeight.w900,
                color: Gray.c900,
              ),
            ),
          ),
          const SizedBox(height: RtcSpace.s3),
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s5),
              itemCount: resumen.frecuentes.length,
              separatorBuilder: (_, _) => const SizedBox(width: RtcSpace.s3),
              itemBuilder: (_, i) {
                final f = resumen.frecuentes[i];
                return _TarjetaVolver(
                  frecuente: f,
                  cancha: canchas[f.courtId],
                  cupo: cupo[f.courtId],
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// La tarjeta oscura del próximo turno, con cuenta regresiva.
class TarjetaProximoTurno extends StatefulWidget {
  const TarjetaProximoTurno({super.key, required this.booking});

  final Booking booking;

  @override
  State<TarjetaProximoTurno> createState() => _TarjetaProximoTurnoState();
}

class _TarjetaProximoTurnoState extends State<TarjetaProximoTurno> {
  late final Timer _reloj;

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _reloj.cancel();
    super.dispose();
  }

  Booking get b => widget.booking;

  String get _cuando {
    final hoy = ahoraEnBogota();
    final dia = DateTime.utc(b.date.year, b.date.month, b.date.day);
    final hoyDia = DateTime.utc(hoy.year, hoy.month, hoy.day);
    final dias = dia.difference(hoyDia).inDays;
    final etiqueta = switch (dias) {
      0 => 'Hoy',
      1 => 'Mañana',
      _ =>
        '${diasLargos[b.date.weekday % 7][0].toUpperCase()}${diasLargos[b.date.weekday % 7].substring(1)} ${diaMesCorto(b.date)}',
    };
    return '$etiqueta, ${hora12(b.startTime)} – ${hora12(b.endTime)}';
  }

  /// "Empieza en 3 h 20 min", "Empieza en 12 min", "En juego hasta las 8:00 PM".
  String get _cuenta {
    final ahora = ahoraEnBogota();
    if (!ahora.isBefore(b.inicio)) {
      return 'En juego · hasta las ${hora12(b.endTime)}';
    }
    final falta = b.inicio.difference(ahora);
    if (falta.inDays >= 1) {
      final d = falta.inDays;
      return 'Faltan $d ${d == 1 ? 'día' : 'días'}';
    }
    final h = falta.inHours;
    final m = falta.inMinutes % 60;
    return h > 0
        ? 'Empieza en $h h $m min'
        : 'Empieza en ${falta.inMinutes} min';
  }

  Future<void> _comoLlegar() {
    final destino = b.lat != null && b.lng != null
        ? '${b.lat},${b.lng}'
        : [
            b.courtName,
            b.direccion,
            b.city,
          ].where((s) => s.isNotEmpty).join(', ');
    return launchUrl(
      Uri.https('www.google.com', '/maps/search/', {
        'api': '1',
        'query': destino,
      }),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final conQr = tieneCodigo(b);
    return Container(
      padding: const EdgeInsets.all(RtcSpace.s5),
      decoration: BoxDecoration(
        color: GrisFijo.c900,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TU PRÓXIMO TURNO',
                      style: RtcType.xs.copyWith(
                        color: Lime.c400,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      b.courtName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: RtcType.xl.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _cuando,
                      style: RtcType.sm.copyWith(color: GrisFijo.c300),
                    ),
                  ],
                ),
              ),
              if (conQr) ...[
                const SizedBox(width: RtcSpace.s3),
                RtcPressable(
                  onTap: () => mostrarQrReserva(context, b),
                  semanticLabel: 'Mostrar el QR de la reserva',
                  child: Container(
                    width: 64,
                    height: 64,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: QrImageView(
                      data: qrDeReserva(b.bookingCode),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: RtcSpace.s3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Lime.c400.withValues(alpha: 0.15),
              borderRadius: RtcRadius.brFull,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.timer, size: 14, color: Lime.c400),
                const SizedBox(width: 5),
                Text(
                  _cuenta,
                  style: RtcType.xs.copyWith(
                    color: Lime.c400,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: RtcSpace.s4),
          Row(
            children: [
              Expanded(
                child: _Boton(
                  texto: conQr ? 'Mostrar QR' : 'Ver mi reserva',
                  icono: conQr ? LucideIcons.qrCode : LucideIcons.ticket,
                  lima: true,
                  onTap: conQr
                      ? () => mostrarQrReserva(context, b)
                      : () => rtcNavigate('/mis-reservas'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Boton(
                  texto: 'Cómo llegar',
                  icono: LucideIcons.navigation,
                  onTap: _comoLlegar,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Boton extends StatelessWidget {
  const _Boton({
    required this.texto,
    required this.icono,
    required this.onTap,
    this.lima = false,
  });

  final String texto;
  final IconData icono;
  final VoidCallback onTap;
  final bool lima;

  @override
  Widget build(BuildContext context) {
    final color = lima ? GrisFijo.c900 : Colors.white;
    return RtcPressable(
      onTap: onTap,
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: lima ? Lime.c400 : Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 17, color: color),
            const SizedBox(width: 6),
            Text(
              texto,
              style: RtcType.sm.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Una cancha donde ya jugó, con el próximo horario libre de hoy.
class _TarjetaVolver extends StatelessWidget {
  const _TarjetaVolver({required this.frecuente, this.cancha, this.cupo});

  final CanchaFrecuente frecuente;
  final Court? cancha;
  final Disponibilidad? cupo;

  @override
  Widget build(BuildContext context) {
    final foto = cancha?.photos.isNotEmpty == true
        ? cancha!.photos.first
        : null;
    final proximo = cupo?.proximo;
    final deporte = cancha?.sport ?? frecuente.deporte;
    return RtcPressable(
      onTap: () => rtcOpenCourt(
        frecuente.courtId,
        date: proximo != null ? fechaIso(ahoraEnBogota()) : null,
        start: proximo,
        foto: foto,
      ),
      child: Container(
        width: 196,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Superficie.tarjeta,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 96,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  RemoteImage(url: foto ?? '', sport: deporte),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Lime.c400,
                        borderRadius: RtcRadius.brFull,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SportIcon(
                            sport: deporte,
                            size: 12,
                            color: GrisFijo.c900,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${frecuente.veces} ${frecuente.veces == 1 ? 'vez' : 'veces'}',
                            style: RtcType.xs.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: GrisFijo.c900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(RtcSpace.s3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    frecuente.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RtcType.sm.copyWith(
                      fontWeight: FontWeight.w800,
                      color: Gray.c900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Green.c100,
                            borderRadius: RtcRadius.brFull,
                          ),
                          child: Text(
                            proximo != null
                                ? 'Hoy ${hora12(proximo)}'
                                : 'Ver horarios',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RtcType.xs.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Green.c700,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Reservar',
                        style: RtcType.xs.copyWith(
                          fontWeight: FontWeight.w800,
                          color: Green.c600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
