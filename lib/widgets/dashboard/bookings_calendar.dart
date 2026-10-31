import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/booking.dart';
import '../../models/court.dart' show formatCop;
import '../../models/fechas.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import 'booking_detail_dialog.dart';

/// Port de `Frontend/src/components/dashboard/BookingsCalendar.tsx`.
///
/// Rejilla del mes con la semana empezando en lunes, puntos de color por
/// reserva (en movil la web muestra puntos, no las etiquetas: eso es `sm:`),
/// panel del dia elegido y el modal de detalle.
class BookingsCalendar extends StatefulWidget {
  const BookingsCalendar({
    super.key,
    required this.bookings,
    required this.onCambiarEstado,
  });

  final List<Booking> bookings;
  final void Function(String id, String estado) onCambiarEstado;

  @override
  State<BookingsCalendar> createState() => _BookingsCalendarState();
}

/// `WEEKDAYS`: la semana arranca en lunes (`weekStartsOn: 1`).
const _diasSemana = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

class _BookingsCalendarState extends State<BookingsCalendar> {
  DateTime _mes = DateTime.now();
  DateTime? _diaElegido;
  Booking? _detalle;

  /// `bookingsByDate`, con las de cada dia ordenadas por hora de inicio.
  Map<String, List<Booking>> get _porFecha {
    final mapa = <String, List<Booking>>{};
    for (final b in widget.bookings) {
      mapa.putIfAbsent(fechaIso(b.date), () => []).add(b);
    }
    for (final lista in mapa.values) {
      lista.sort((a, b) => a.startTime.compareTo(b.startTime));
    }
    return mapa;
  }

  /// `calendarDays`: de la primera casilla de la rejilla a la ultima.
  List<DateTime> get _dias {
    final inicioMes = DateTime(_mes.year, _mes.month, 1);
    final finMes = DateTime(_mes.year, _mes.month + 1, 0);
    // `startOfWeek(..., { weekStartsOn: 1 })`
    final desde = inicioMes.subtract(
      Duration(days: (inicioMes.weekday - DateTime.monday) % 7),
    );
    final hasta = finMes.add(
      Duration(days: (DateTime.sunday - finMes.weekday) % 7),
    );
    final out = <DateTime>[];
    for (var d = desde; !d.isAfter(hasta); d = d.add(const Duration(days: 1))) {
      out.add(d);
    }
    return out;
  }

  bool _mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final porFecha = _porFecha;
    final elegido = _diaElegido;
    final delDia = elegido == null
        ? const <Booking>[]
        : (porFecha[fechaIso(elegido)] ?? const <Booking>[]);

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _rejilla(porFecha),
            const SizedBox(height: RtcSpace.s4),
            _leyenda(),
            if (elegido != null) ...[
              const SizedBox(height: RtcSpace.s4),
              _panelDia(elegido, delDia),
            ],
          ],
        ),
        if (_detalle != null)
          BookingDetailDialog(
            booking: _detalle!,
            onCambiarEstado: (estado) {
              widget.onCambiarEstado(_detalle!.id, estado);
              setState(() => _detalle = null);
            },
            onCerrar: () => setState(() => _detalle = null),
          ),
      ],
    );
  }

  Widget _rejilla(Map<String, List<Booking>> porFecha) {
    final dias = _dias;
    final hoy = DateTime.now();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RtcRadius.brXxl,
        border: Border.all(color: Gray.c100),
      ),
      child: Column(
        children: [
          // Cabecera del mes
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: RtcSpace.s4,
              vertical: RtcSpace.s4,
            ),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Gray.c100)),
            ),
            child: Row(
              children: [
                _flechaMes(LucideIcons.chevronLeft, -1),
                Expanded(
                  child: Text(
                    '${mesesLargos[_mes.month - 1]} ${_mes.year}'.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: RtcType.base.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Gray.c900,
                    ),
                  ),
                ),
                _flechaMes(LucideIcons.chevronRight, 1),
              ],
            ),
          ),
          // Cabecera de dias
          Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Gray.c100)),
            ),
            child: Row(
              children: [
                for (final d in _diasSemana)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        d.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: RtcType.xs.copyWith(
                          fontSize: 10,
                          fontWeight: RtcType.bold,
                          color: Gray.c400,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Casillas
          for (var fila = 0; fila < dias.length / 7; fila++)
            // IntrinsicHeight le da alto acotado a la fila: sin el,
            // `stretch` dentro de un scroll vertical la colapsa a cero y el
            // calendario no se dibuja. Es lo que iguala el alto de las siete
            // casillas, como las celdas de una tabla.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var col = 0; col < 7; col++)
                    Expanded(
                      child: _casilla(dias[fila * 7 + col], porFecha, hoy),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _flechaMes(IconData icono, int delta) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () =>
          setState(() => _mes = DateTime(_mes.year, _mes.month + delta, 1)),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: RtcRadius.brXl,
          border: Border.all(color: Gray.c200),
        ),
        child: Icon(icono, size: 16, color: Gray.c500),
      ),
    );
  }

  Widget _casilla(
    DateTime dia,
    Map<String, List<Booking>> porFecha,
    DateTime hoy,
  ) {
    final delDia = porFecha[fechaIso(dia)] ?? const <Booking>[];
    final delMes = dia.month == _mes.month && dia.year == _mes.year;
    final esHoy = _mismoDia(dia, hoy);
    final elegido = _diaElegido != null && _mismoDia(dia, _diaElegido!);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _diaElegido = dia),
      child: Opacity(
        opacity: delMes ? 1 : 0.3,
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: elegido ? Green.c50 : null,
            border: Border(
              bottom: const BorderSide(color: Gray.c50),
              right: const BorderSide(color: Gray.c50),
              top: elegido
                  ? const BorderSide(color: Green.c400, width: 2)
                  : BorderSide.none,
              left: elegido
                  ? const BorderSide(color: Green.c400, width: 2)
                  : BorderSide.none,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: esHoy ? Green.c600 : null,
                  borderRadius: RtcRadius.brLg,
                ),
                child: Text(
                  '${dia.day}',
                  style: RtcType.xs.copyWith(
                    fontWeight: RtcType.bold,
                    color: esHoy ? Colors.white : Gray.c700,
                  ),
                ),
              ),
              if (delDia.isNotEmpty) ...[
                const SizedBox(height: 4),
                // En movil la web muestra puntos: las etiquetas son `sm:`.
                Wrap(
                  spacing: 2,
                  runSpacing: 2,
                  children: [
                    for (final b in delDia.take(5))
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: estiloReserva(b.status).$3,
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (delDia.length > 5)
                      Text(
                        '+${delDia.length - 5}',
                        style: RtcType.xs.copyWith(
                          fontSize: 8,
                          fontWeight: RtcType.bold,
                          color: Gray.c400,
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _leyenda() {
    return Wrap(
      spacing: RtcSpace.s3,
      runSpacing: 6,
      children: [
        for (final e in kEstadosReserva.entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: e.value.$3,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(e.value.$4, style: RtcType.xs.copyWith(color: Gray.c500)),
            ],
          ),
      ],
    );
  }

  Widget _panelDia(DateTime dia, List<Booking> delDia) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RtcRadius.brXxl,
        border: Border.all(color: Gray.c100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: RtcSpace.s4,
              vertical: RtcSpace.s3,
            ),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Gray.c100)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fechaLargaCapitalizada(dia).toUpperCase(),
                        style: RtcType.sm.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Gray.c900,
                        ),
                      ),
                      Text(
                        '${delDia.length} '
                        '${delDia.length == 1 ? 'reserva' : 'reservas'}',
                        style: RtcType.xs.copyWith(color: Gray.c400),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _diaElegido = null),
                  child: Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: RtcRadius.brLg,
                      border: Border.all(color: Gray.c200),
                    ),
                    child: const Icon(
                      LucideIcons.x,
                      size: 16,
                      color: Gray.c400,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (delDia.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: RtcSpace.s10),
              child: Column(
                children: [
                  const Icon(
                    LucideIcons.calendarDays,
                    size: 32,
                    color: Gray.c200,
                  ),
                  const SizedBox(height: RtcSpace.s2),
                  Text(
                    'Sin reservas este día',
                    style: RtcType.xs.copyWith(
                      fontWeight: RtcType.semibold,
                      color: Gray.c400,
                    ),
                  ),
                ],
              ),
            )
          else
            for (var i = 0; i < delDia.length; i++) ...[
              if (i > 0) Container(height: 1, color: Gray.c50),
              _filaDia(delDia[i]),
            ],
        ],
      ),
    );
  }

  Widget _filaDia(Booking b) {
    final (_, _, punto, _) = estiloReserva(b.status);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s4,
        vertical: RtcSpace.s3,
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Column(
                children: [
                  Text(
                    hora12(b.startTime),
                    style: RtcType.sm.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Gray.c900,
                    ),
                  ),
                  Text(
                    hora12(b.endTime),
                    style: RtcType.xs.copyWith(fontSize: 10, color: Gray.c400),
                  ),
                ],
              ),
            ),
            const SizedBox(width: RtcSpace.s3),
            // La linea vertical con el color del estado.
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: punto,
                borderRadius: RtcRadius.brFull,
              ),
            ),
            const SizedBox(width: RtcSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Wrap(
                    spacing: RtcSpace.s2,
                    runSpacing: 2,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (b.courtName.isNotEmpty)
                        Text(
                          b.courtName,
                          style: RtcType.sm.copyWith(
                            fontWeight: RtcType.bold,
                            color: Gray.c900,
                          ),
                        ),
                      PildoraEstado(estado: b.status),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(LucideIcons.user, size: 12, color: Gray.c500),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          b.guestName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RtcType.xs.copyWith(color: Gray.c500),
                        ),
                      ),
                      const SizedBox(width: RtcSpace.s3),
                      Text(
                        '\$${formatCop(b.totalPrice)}',
                        style: RtcType.xs.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Green.c700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: RtcSpace.s2),
            _acciones(b),
          ],
        ),
      ),
    );
  }

  Widget _acciones(Booking b) {
    final botones = <Widget>[
      _redondo(
        LucideIcons.eye,
        Gray.c200,
        Colors.white,
        Gray.c400,
        () => setState(() => _detalle = b),
      ),
      if (b.status == 'pending')
        _redondo(
          LucideIcons.circleCheck,
          const Color(0xFFFDE68A), // amber-200
          const Color(0xFFFFFBEB), // amber-50
          const Color(0xFFF59E0B), // amber-500
          () => widget.onCambiarEstado(b.id, 'confirmed'),
        ),
      if (b.status == 'pending' || b.status == 'confirmed')
        _redondo(
          LucideIcons.x,
          Red.c200,
          Red.c50,
          Red.c400,
          () => widget.onCambiarEstado(b.id, 'cancelled'),
        ),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < botones.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          botones[i],
        ],
      ],
    );
  }

  Widget _redondo(
    IconData icono,
    Color borde,
    Color fondo,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fondo,
          shape: BoxShape.circle,
          border: Border.all(color: borde),
        ),
        child: Icon(icono, size: 14, color: color),
      ),
    );
  }
}
