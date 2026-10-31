import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/owner_api.dart';
import '../../api/rtc_api.dart';
import '../../models/booking.dart';
import '../../models/court.dart' show formatCop;
import '../../models/fechas.dart';
import '../../realtime/rtc_realtime.dart';
import '../../theme/palette.dart';
import '../../theme/shadows.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/dashboard/booking_detail_dialog.dart';
import '../../widgets/dashboard/bookings_calendar.dart';
import '../../widgets/motion/rtc_motion.dart';
import '../../widgets/rtc_toast.dart';

/// Port de `Frontend/src/app/dashboard/propetario/reservas/page.tsx`.
///
/// Dos vistas: calendario (la que abre por defecto) y lista paginada de a 10.
/// Los filtros de arriba valen para las dos.
class ReservasScreen extends StatefulWidget {
  const ReservasScreen({super.key});

  @override
  State<ReservasScreen> createState() => _ReservasScreenState();
}

/// `ITEMS_PER_PAGE`.
const _porPagina = 10;

/// Los cinco filtros de estado. OJO: la web arma la etiqueta con
/// `STATUS_LABELS[s]`, que no tiene 'cancelled', asi que esa pildora le sale
/// SIN TEXTO. Aca lleva "Cancelada", que es lo que evidentemente quiso decir.
const _filtrosEstado = <(String, String)>[
  ('all', 'Todas'),
  ('pending', 'Sin pagar'),
  ('confirmed', 'Confirmada'),
  ('cancelled', 'Cancelada'),
  ('completed', 'Completada'),
];

class _ReservasScreenState extends State<ReservasScreen> {
  final _buscador = TextEditingController();

  List<Booking> _reservas = const [];
  bool _cargando = true;
  String _busqueda = '';
  String _estado = 'all';
  int _pagina = 1;

  /// 'calendar' | 'list'. La web abre en calendario.
  String _vista = 'calendar';

  Booking? _detalle;

  @override
  void initState() {
    super.initState();
    _cargar();
    rtcReservasCambiaron.addListener(_alLlegarAviso);
  }

  @override
  void dispose() {
    rtcReservasCambiaron.removeListener(_alLlegarAviso);
    _buscador.dispose();
    super.dispose();
  }

  /// El `invalidateQueries(['owner-bookings'])` del socket, en silencio: una
  /// reserva nueva no debe tirar al usuario al principio de la lista.
  void _alLlegarAviso() => _cargar(silencioso: true);

  /// `silencioso`: al recargar DESPUES de una accion no se vuelve a poner el
  /// esqueleto. Ponerlo reemplaza toda la lista y el scroll salta al
  /// principio, asi que confirmar una reserva que estaba abajo te dejaba
  /// arriba del todo, como si la app te hubiera sacado de la pantalla.
  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _cargando = true);
    try {
      final reservas = await ownerApi.reservas();
      if (!mounted) return;
      setState(() {
        _reservas = reservas;
        _cargando = false;
      });
    } on RtcApiException catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      rtcToast(context, e.message, tipo: RtcToastTipo.error);
    }
  }

  Future<void> _cambiarEstado(String id, String estado) async {
    try {
      await ownerApi.cambiarEstado(id, estado);
      if (!mounted) return;
      rtcToast(context, 'Estado actualizado');
      setState(() => _detalle = null);
      await _cargar(silencioso: true);
    } on RtcApiException {
      if (!mounted) return;
      rtcToast(context, 'Error al cambiar el estado', tipo: RtcToastTipo.error);
    }
  }

  /// `filtered`: primero el estado, despues el texto contra nombre, email o
  /// codigo (sin el '#').
  List<Booking> get _filtradas {
    final q = _busqueda.toLowerCase();
    return _reservas.where((b) {
      if (_estado != 'all' && b.status != _estado) return false;
      if (q.isEmpty) return true;
      return b.guestName.toLowerCase().contains(q) ||
          b.guestEmail.toLowerCase().contains(q) ||
          b.bookingCode.toLowerCase().contains(q.replaceAll('#', ''));
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtradas = _filtradas;
    final paginas = (filtradas.length / _porPagina).ceil();
    final desde = (_pagina - 1) * _porPagina;
    final hasta = (desde + _porPagina).clamp(0, filtradas.length);
    final visibles = desde >= filtradas.length
        ? const <Booking>[]
        : filtradas.sublist(desde, hasta);

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _cargar,
          color: Green.c600,
          child: ListView(
            padding: const EdgeInsets.only(bottom: RtcSpace.s12),
            children: [
              _encabezado(),
              const SizedBox(height: RtcSpace.s4),
              _conmutador(),
              const SizedBox(height: RtcSpace.s6),
              _filtros(),
              const SizedBox(height: RtcSpace.s6),
              if (_cargando)
                _esqueletos()
              else if (_vista == 'calendar')
                BookingsCalendar(
                  bookings: filtradas,
                  onCambiarEstado: _cambiarEstado,
                )
              else ...[
                if (filtradas.isEmpty)
                  _vacio()
                else ...[
                  for (var i = 0; i < visibles.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: RtcSpace.s3),
                      child: RtcFadeUp(
                        delay: Duration(milliseconds: (i < 8 ? i : 8) * 45),
                        child: _tarjeta(visibles[i]),
                      ),
                    ),
                  if (filtradas.length > _porPagina)
                    _paginacion(filtradas.length, paginas, desde, hasta),
                ],
              ],
            ],
          ),
        ),
        if (_detalle != null)
          BookingDetailDialog(
            booking: _detalle!,
            onCambiarEstado: (estado) => _cambiarEstado(_detalle!.id, estado),
            onCerrar: () => setState(() => _detalle = null),
          ),
      ],
    );
  }

  Widget _encabezado() {
    final reagendadas = _reservas.where((b) => b.status == 'reagendada').length;
    final confirmadas = _reservas.where((b) => b.status == 'confirmed').length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Panel propietario',
          style: RtcType.sm.copyWith(
            color: Green.c700,
            fontWeight: RtcType.semibold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Reservas',
          style: RtcType.xl3.copyWith(
            letterSpacing: -0.4,
            fontWeight: FontWeight.w900,
            color: Gray.c900,
          ),
        ),
        const SizedBox(height: 4),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${_reservas.length} reservas · '),
              TextSpan(
                text: '$reagendadas reagendadas',
                style: RtcType.sm.copyWith(
                  color: const Color(0xFFCA8A04), // yellow-600
                  fontWeight: RtcType.semibold,
                ),
              ),
              const TextSpan(text: ' · '),
              TextSpan(
                text: '$confirmadas confirmadas',
                style: RtcType.sm.copyWith(
                  color: Green.c600,
                  fontWeight: RtcType.semibold,
                ),
              ),
            ],
          ),
          style: RtcType.sm.copyWith(color: Gray.c500),
        ),
      ],
    );
  }

  /// El conmutador Calendario / Lista: caja gris con la activa en blanco.
  Widget _conmutador() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Gray.c100,
          borderRadius: RtcRadius.brXl,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _opcionVista('calendar', 'Calendario', LucideIcons.layoutGrid),
            _opcionVista('list', 'Lista', LucideIcons.list),
          ],
        ),
      ),
    );
  }

  Widget _opcionVista(String id, String etiqueta, IconData icono) {
    final activa = _vista == id;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _vista = id),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: RtcSpace.s3,
          vertical: RtcSpace.s2,
        ),
        decoration: BoxDecoration(
          color: activa ? Colors.white : null,
          borderRadius: RtcRadius.brLg,
          boxShadow: activa ? RtcShadows.card : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 14, color: activa ? Gray.c900 : Gray.c500),
            const SizedBox(width: 6),
            Text(
              etiqueta,
              style: RtcType.xs.copyWith(
                fontWeight: RtcType.bold,
                color: activa ? Gray.c900 : Gray.c500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filtros() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _buscador,
          onChanged: (v) => setState(() {
            _busqueda = v;
            _pagina = 1;
          }),
          style: RtcType.sm.copyWith(color: Gray.c900),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Buscar por cliente, email o código (#XXXXXXXX)...',
            hintStyle: RtcType.xs.copyWith(color: Gray.c400),
            prefixIcon: const Icon(
              LucideIcons.search,
              size: 16,
              color: Gray.c400,
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 40),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: RtcSpace.s4,
              vertical: RtcSpace.s3,
            ),
            border: const OutlineInputBorder(
              borderRadius: RtcRadius.brXl,
              borderSide: BorderSide(color: Gray.c200),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: RtcRadius.brXl,
              borderSide: BorderSide(color: Gray.c200),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: RtcRadius.brXl,
              borderSide: BorderSide(color: Green.c400, width: 2),
            ),
          ),
        ),
        const SizedBox(height: RtcSpace.s3),
        // `flex gap-2 flex-wrap`
        Wrap(
          spacing: RtcSpace.s2,
          runSpacing: RtcSpace.s2,
          children: [
            for (final (valor, etiqueta) in _filtrosEstado)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() {
                  _estado = valor;
                  _pagina = 1;
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: RtcSpace.s3,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _estado == valor ? Gray.c900 : null,
                    borderRadius: RtcRadius.brFull,
                    border: Border.all(
                      color: _estado == valor ? Gray.c900 : Gray.c200,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    etiqueta,
                    style: RtcType.xs.copyWith(
                      fontWeight: RtcType.bold,
                      color: _estado == valor ? Colors.white : Gray.c500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _esqueletos() {
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: RtcSpace.s3),
            child: RtcSkeletonPulse(
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Gray.c100,
                  borderRadius: RtcRadius.brXxl,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _vacio() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 64), // py-16
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RtcRadius.brXxl,
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.calendarDays, size: 40, color: Gray.c300),
          const SizedBox(height: RtcSpace.s3),
          Text(
            'SIN RESERVAS',
            style: RtcType.xs.copyWith(
              fontWeight: FontWeight.w900,
              color: Gray.c400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _busqueda.isNotEmpty || _estado != 'all'
                ? 'Intenta con otros filtros'
                : 'Las reservas de tus canchas aparecerán aquí',
            textAlign: TextAlign.center,
            style: RtcType.xs.copyWith(color: Gray.c400),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(Booking b) {
    return Container(
      padding: const EdgeInsets.all(RtcSpace.s3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RtcRadius.brXxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // El bloque verde con el mes y el dia.
              Container(
                constraints: const BoxConstraints(minWidth: 44),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: RtcSpace.s2,
                ),
                decoration: BoxDecoration(
                  color: Green.c50,
                  borderRadius: RtcRadius.brXl,
                ),
                child: Column(
                  children: [
                    Text(
                      mesesCortos[b.date.month - 1].toUpperCase(),
                      style: RtcType.xs.copyWith(
                        fontSize: 9,
                        fontWeight: RtcType.bold,
                        color: Green.c600,
                      ),
                    ),
                    Text(
                      '${b.date.day}',
                      style: RtcType.lg.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Green.c700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: RtcSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                              fontWeight: FontWeight.w900,
                              color: Gray.c900,
                            ),
                          ),
                        PildoraEstado(estado: b.status),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _linea(
                      LucideIcons.clock,
                      '${hora12(b.startTime)} – ${hora12(b.endTime)}',
                    ),
                    _linea(LucideIcons.user, b.guestName),
                    _linea(LucideIcons.mail, b.guestEmail),
                  ],
                ),
              ),
              const SizedBox(width: RtcSpace.s2),
              _acciones(b),
            ],
          ),
          const SizedBox(height: 10),
          Container(height: 1, color: Gray.c50),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: b.bookingCode.isEmpty
                    ? const SizedBox()
                    : Text(
                        '#${b.bookingCode}',
                        style: RtcType.xs.copyWith(
                          fontWeight: RtcType.bold,
                          color: Gray.c400,
                        ),
                      ),
              ),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: '\$${formatCop(b.netoParaDueno)}'),
                    TextSpan(
                      text: ' COP',
                      style: RtcType.xs.copyWith(
                        fontSize: 10,
                        color: Gray.c400,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                style: RtcType.sm.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Green.c700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _linea(IconData icono, String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icono, size: 12, color: Gray.c500),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RtcType.xs.copyWith(color: Gray.c500),
            ),
          ),
        ],
      ),
    );
  }

  /// Una pendiente es un checkout en curso: la confirma ePayco al aprobar el
  /// pago y, si no se paga, se libera sola. El club no la toca.
  Widget _esperandoPago() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // amber-50
        borderRadius: RtcRadius.brFull,
        border: Border.all(color: const Color(0xFFFDE68A)), // amber-200
      ),
      child: Text(
        'Esperando pago',
        style: RtcType.xs.copyWith(
          fontSize: 10,
          fontWeight: RtcType.bold,
          color: const Color(0xFFD97706), // amber-600
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
      if (b.status == 'pending') _esperandoPago(),
      if (b.status == 'confirmed')
        _redondo(
          LucideIcons.trophy,
          const Color(0xFFBFDBFE), // blue-200
          const Color(0xFFEFF6FF), // blue-50
          const Color(0xFF3B82F6), // blue-500
          () => _cambiarEstado(b.id, 'completed'),
        ),
    ];

    // `flex items-center gap-1.5`: en fila, no apilados.
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

  /// La paginacion: "Mostrando X a Y de Z" y los numeros con sus puntos
  /// suspensivos cuando hay muchas paginas.
  Widget _paginacion(int total, int paginas, int desde, int hasta) {
    return Container(
      padding: const EdgeInsets.all(RtcSpace.s4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RtcRadius.brXxl,
      ),
      child: Column(
        children: [
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(text: 'Mostrando '),
                TextSpan(
                  text: '${desde + 1}',
                  style: const TextStyle(fontWeight: RtcType.bold),
                ),
                const TextSpan(text: ' a '),
                TextSpan(
                  text: '$hasta',
                  style: const TextStyle(fontWeight: RtcType.bold),
                ),
                const TextSpan(text: ' de '),
                TextSpan(
                  text: '$total',
                  style: const TextStyle(fontWeight: RtcType.bold),
                ),
                const TextSpan(text: ' reservas'),
              ],
            ),
            textAlign: TextAlign.center,
            style: RtcType.xs.copyWith(
              color: Gray.c600,
              fontWeight: RtcType.medium,
            ),
          ),
          const SizedBox(height: RtcSpace.s4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _flecha(LucideIcons.chevronLeft, _pagina > 1, () {
                setState(() => _pagina = _pagina - 1);
              }),
              const SizedBox(width: RtcSpace.s2),
              for (final p in _numeros(paginas)) ...[
                if (p == 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Text(
                      '...',
                      style: RtcType.sm.copyWith(color: Gray.c400),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _numero(p),
                  ),
              ],
              const SizedBox(width: RtcSpace.s2),
              _flecha(LucideIcons.chevronRight, _pagina < paginas, () {
                setState(() => _pagina = _pagina + 1);
              }),
            ],
          ),
        ],
      ),
    );
  }

  /// `isActive || isNear || isFirstOrLast`, con el 0 marcando los puntos
  /// suspensivos.
  List<int> _numeros(int paginas) {
    final out = <int>[];
    for (var p = 1; p <= paginas; p++) {
      final cerca = (p - _pagina).abs() <= 1;
      final extremo = p == 1 || p == paginas;
      if (cerca || extremo) {
        out.add(p);
      } else if (p == 2 || p == paginas - 1) {
        out.add(0);
      }
    }
    return out;
  }

  Widget _numero(int p) {
    final activa = p == _pagina;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _pagina = p),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: activa ? Green.c600 : null,
          borderRadius: RtcRadius.brLg,
          border: activa ? null : Border.all(color: Gray.c200),
        ),
        child: Text(
          '$p',
          style: RtcType.xs.copyWith(
            fontWeight: RtcType.bold,
            color: activa ? Colors.white : Gray.c700,
          ),
        ),
      ),
    );
  }

  Widget _flecha(IconData icono, bool activa, VoidCallback onTap) {
    return Opacity(
      opacity: activa ? 1 : 0.5,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: activa ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: RtcSpace.s3,
            vertical: RtcSpace.s2,
          ),
          decoration: BoxDecoration(
            borderRadius: RtcRadius.brLg,
            border: Border.all(color: Gray.c200),
          ),
          child: Icon(icono, size: 16, color: Gray.c700),
        ),
      ),
    );
  }
}
