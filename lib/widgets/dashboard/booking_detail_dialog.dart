import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/booking.dart';
import '../../models/court.dart' show formatCop;
import '../../models/fechas.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../motion/rtc_motion.dart';

/// `STATUS_STYLES` + `STATUS_LABELS` del panel de reservas.
///
/// OJO: la web no define 'cancelled' en ninguno de los dos mapas, asi que una
/// reserva cancelada cae al estilo de 'pending'. Se replica el fallback, pero
/// la pildora del filtro si lleva su texto: sin el sale un boton vacio.
const kEstadosReserva = <String, (Color, Color, Color, String)>{
  // fondo de la pildora, texto de la pildora, punto, etiqueta
  'confirmed': (Color(0xFFDCFCE7), Green.c700, Color(0xFF22C55E), 'Confirmada'),
  'reagendada': (
    Color(0xFFFEF3C7),
    Color(0xFFB45309),
    Color(0xFFFBBF24),
    'Reagendada',
  ),
  'completed': (
    Color(0xFFDBEAFE),
    Color(0xFF1D4ED8),
    Color(0xFF60A5FA),
    'Completada',
  ),
  'pending': (Gray.c100, Gray.c500, Gray.c400, 'Sin pagar'),
};

(Color, Color, Color, String) estiloReserva(String estado) =>
    kEstadosReserva[estado] ?? kEstadosReserva['pending']!;

/// La pildora de estado, igual en la lista, el calendario y el detalle.
class PildoraEstado extends StatelessWidget {
  const PildoraEstado({super.key, required this.estado, this.grande = false});

  final String estado;
  final bool grande;

  @override
  Widget build(BuildContext context) {
    final (fondo, texto, punto, etiqueta) = estiloReserva(estado);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: grande ? RtcSpace.s3 : RtcSpace.s2,
        vertical: grande ? 6 : 2,
      ),
      decoration: BoxDecoration(color: fondo, borderRadius: RtcRadius.brFull),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: punto, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            etiqueta,
            style: RtcType.xs.copyWith(
              fontSize: grande ? 12 : 10,
              fontWeight: RtcType.bold,
              color: texto,
            ),
          ),
        ],
      ),
    );
  }
}

/// Port del `<Dialog>` de detalle de reserva, que las dos vistas comparten.
class BookingDetailDialog extends StatelessWidget {
  const BookingDetailDialog({
    super.key,
    required this.booking,
    required this.onCambiarEstado,
    required this.onCerrar,
  });

  final Booking booking;
  final void Function(String estado) onCambiarEstado;
  final VoidCallback onCerrar;

  @override
  Widget build(BuildContext context) {
    // El club solo da por jugado un turno pagado. Confirmar le toca a ePayco
    // y el estado "cancelada" ya no existe: lo que no se paga se borra solo.
    final puedeAccionar = booking.status == 'confirmed';
    final esperandoPago = booking.status == 'pending';

    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: onCerrar,
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.80)),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(RtcSpace.s4),
              child: RtcSheetUp(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(RtcSpace.s6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: RtcRadius.brXxl,
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'DETALLE DE RESERVA',
                            style: RtcType.lg.copyWith(
                              fontWeight: FontWeight.w900,
                              color: Gray.c900,
                            ),
                          ),
                          const SizedBox(height: RtcSpace.s4),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: PildoraEstado(
                              estado: booking.status,
                              grande: true,
                            ),
                          ),
                          const SizedBox(height: RtcSpace.s4),
                          _datos(),
                          if (booking.bookingCode.isNotEmpty) ...[
                            const SizedBox(height: RtcSpace.s4),
                            _fila(
                              'Código',
                              '#${booking.bookingCode}',
                              fondo: Gray.c100,
                              colorValor: Gray.c700,
                              espaciado: 3,
                            ),
                          ],
                          const SizedBox(height: RtcSpace.s4),
                          _fila(
                            'Te llega',
                            '\$${formatCop(booking.netoParaDueno)} COP',
                            fondo: Green.c50,
                            colorValor: Green.c700,
                            grande: true,
                          ),
                          if (puedeAccionar) ...[
                            const SizedBox(height: RtcSpace.s4),
                            _acciones(),
                          ],
                          if (esperandoPago) ...[
                            const SizedBox(height: RtcSpace.s4),
                            _avisoEsperandoPago(),
                          ],
                          const SizedBox(height: RtcSpace.s4),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: onCerrar,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: RtcRadius.brXl,
                                border: Border.all(color: Gray.c200),
                              ),
                              child: Text(
                                'Cerrar',
                                style: RtcType.sm.copyWith(
                                  fontWeight: RtcType.semibold,
                                  color: Gray.c600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _datos() {
    return Container(
      padding: const EdgeInsets.all(RtcSpace.s4),
      decoration: BoxDecoration(color: Gray.c50, borderRadius: RtcRadius.brXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _dato(LucideIcons.calendarDays, fechaLargaCapitalizada(booking.date)),
          _dato(
            LucideIcons.clock,
            '${hora12(booking.startTime)} – ${hora12(booking.endTime)}',
          ),
          _dato(LucideIcons.user, booking.guestName),
          _dato(LucideIcons.mail, booking.guestEmail),
          _dato(LucideIcons.phone, booking.guestPhone),
          if (booking.notes != null) ...[
            const SizedBox(height: RtcSpace.s2),
            Container(height: 1, color: Gray.c100),
            const SizedBox(height: RtcSpace.s2),
            Text(
              '📝 ${booking.notes}',
              style: RtcType.sm.copyWith(color: Gray.c500),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dato(IconData icono, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: RtcSpace.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icono, size: 16, color: Green.c600),
          ),
          const SizedBox(width: RtcSpace.s2),
          Expanded(
            child: Text(texto, style: RtcType.sm.copyWith(color: Gray.c600)),
          ),
        ],
      ),
    );
  }

  Widget _fila(
    String etiqueta,
    String valor, {
    required Color fondo,
    required Color colorValor,
    bool grande = false,
    double espaciado = 0,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s4,
        vertical: RtcSpace.s3,
      ),
      decoration: BoxDecoration(color: fondo, borderRadius: RtcRadius.brXl),
      child: Row(
        children: [
          Expanded(
            child: Text(
              etiqueta,
              style: RtcType.sm.copyWith(
                color: fondo == Gray.c100 ? Gray.c500 : Gray.c600,
                fontWeight: RtcType.semibold,
              ),
            ),
          ),
          Text(
            valor,
            style: (grande ? RtcType.lg : RtcType.base).copyWith(
              fontWeight: FontWeight.w900,
              color: colorValor,
              letterSpacing: espaciado,
            ),
          ),
        ],
      ),
    );
  }

  Widget _acciones() {
    return _boton(
      LucideIcons.trophy,
      'Completar',
      fondo: const Color(0xFF2563EB), // blue-600
      color: Colors.white,
      onTap: () => onCambiarEstado('completed'),
    );
  }

  Widget _avisoEsperandoPago() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s4,
        vertical: RtcSpace.s3,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // amber-50
        borderRadius: RtcRadius.brXl,
      ),
      child: Text(
        'Esperando el pago. Se confirma sola cuando ePayco lo apruebe; si no '
        'se paga, el horario se libera.',
        style: RtcType.xs.copyWith(
          color: const Color(0xFFB45309), // amber-700
          height: 1.35,
        ),
      ),
    );
  }

  Widget _boton(
    IconData icono,
    String etiqueta, {
    required Color? fondo,
    required Color color,
    Color? borde,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10), // py-2.5
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fondo,
          borderRadius: RtcRadius.brXl,
          border: borde == null ? null : Border.all(color: borde, width: 2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 16, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                etiqueta,
                maxLines: 1,
                style: RtcType.sm.copyWith(
                  fontWeight: RtcType.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
