/// Lo que el jugador puede hacer con una reserva pagada desde el telefono:
/// mostrar el QR en la cancha, ponerla en su calendario y compartir la
/// cancha.
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/booking.dart';
import '../models/court.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';

/// Lo que va dentro del QR. El prefijo lo distingue de cualquier otro QR que
/// el dueño escanee por error; el escaner del panel lo lee con
/// [codigoDesdeQr].
String qrDeReserva(String codigo) => 'RTC:$codigo';

/// El codigo de reserva de un QR, o null si no es uno nuestro.
String? codigoDesdeQr(String? valor) {
  if (valor == null || !valor.startsWith('RTC:')) return null;
  final codigo = valor.substring(4).trim().toUpperCase();
  return codigo.isEmpty ? null : codigo;
}

/// La hoja con el QR grande, para mostrarlo en la recepcion de la cancha.
Future<void> mostrarQrReserva(BuildContext context, Booking b) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Gray.c200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: RtcSpace.s5),
            Text(
              'Muéstralo al llegar',
              style: RtcType.lg.copyWith(
                fontWeight: FontWeight.w700,
                color: Gray.c900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${b.courtName} · ${b.startTime} – ${b.endTime}',
              textAlign: TextAlign.center,
              style: RtcType.sm.copyWith(color: Gray.c500),
            ),
            const SizedBox(height: RtcSpace.s5),
            QrImageView(
              data: qrDeReserva(b.bookingCode),
              size: 220,
              padding: EdgeInsets.zero,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.circle,
                color: Gray.c900,
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.circle,
                color: Gray.c900,
              ),
              semanticsLabel: 'Código QR de la reserva ${b.bookingCode}',
            ),
            const SizedBox(height: RtcSpace.s4),
            Text(
              '#${b.bookingCode}',
              style: RtcType.base.copyWith(
                fontWeight: FontWeight.w800,
                color: Gray.c700,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Abre la reserva en Google Calendar, que funciona en Android, iOS y web
/// sin pedir permisos de calendario. La hora va en la zona de Colombia.
Future<void> agregarAlCalendario(Booking b) {
  String fecha(String hhmm) {
    final d = b.date;
    final hm = hhmm.replaceAll(':', '');
    return '${d.year}${d.month.toString().padLeft(2, '0')}'
        '${d.day.toString().padLeft(2, '0')}T${hm}00';
  }

  final uri = Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': 'Partido en ${b.courtName}',
    'dates': '${fecha(b.startTime)}/${fecha(b.endTime)}',
    'ctz': 'America/Bogota',
    'details':
        'Reserva #${b.bookingCode} hecha en ReservaTuCancha. '
        'Muestra el QR de la reserva al llegar.',
    if (b.city.isNotEmpty) 'location': b.city,
  });
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Comparte el enlace a la ficha de la cancha (WhatsApp, etc.).
Future<void> compartirCancha(Court c) {
  return SharePlus.instance.share(
    ShareParams(
      text:
          '¿Jugamos aquí? ${c.name} en ${c.city}: '
          'https://reservatucancha.site/canchas/${c.id}',
      subject: c.name,
    ),
  );
}

/// La fila de botones de una reserva pagada: QR y calendario.
class AccionesReserva extends StatelessWidget {
  const AccionesReserva({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Accion(
            icono: LucideIcons.qrCode,
            texto: 'Mostrar QR',
            oscuro: true,
            onTap: () => mostrarQrReserva(context, booking),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Accion(
            icono: LucideIcons.calendarPlus,
            texto: 'Al calendario',
            onTap: () => agregarAlCalendario(booking),
          ),
        ),
      ],
    );
  }
}

class _Accion extends StatelessWidget {
  const _Accion({
    required this.icono,
    required this.texto,
    required this.onTap,
    this.oscuro = false,
  });

  final IconData icono;
  final String texto;
  final VoidCallback onTap;
  final bool oscuro;

  @override
  Widget build(BuildContext context) {
    final color = oscuro ? Colors.white : Gray.c900;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: oscuro ? Gray.c900 : Fondo.app,
          borderRadius: RtcRadius.brFull,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              texto,
              style: RtcType.sm.copyWith(
                fontWeight: RtcType.semibold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
