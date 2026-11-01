import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../api/owner_api.dart';
import '../../api/rtc_api.dart';
import '../../models/booking.dart';
import '../../models/court.dart';
import '../../models/fechas.dart';
import '../../realtime/rtc_realtime.dart';
import '../../theme/motion.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/dashboard/cuenta_epayco.dart';
import '../../widgets/motion/rtc_motion.dart';
import '../../widgets/rtc_toast.dart';

/// Port de `Frontend/src/app/dashboard/propetario/pagos/page.tsx`.
///
/// Dos pestanas: historial de cobros con filtros y paginacion, y la cuenta de
/// ePayco del club. Los montos son lo que le llega al club, no lo que pago el
/// jugador: la tarifa de servicio y la comision nunca son plata suya.
class PagosScreen extends StatefulWidget {
  const PagosScreen({super.key});

  @override
  State<PagosScreen> createState() => _PagosScreenState();
}

/// `STATUS_PILL` / `STATUS_LABEL`.
const _estados = <String, ({Color fondo, Color texto, String etiqueta})>{
  'confirmed': (
    fondo: Color(0xFFDCFCE7),
    texto: Color(0xFF15803D),
    etiqueta: 'Confirmada',
  ),
  'pending': (
    fondo: Color(0xFFFEF9C3),
    texto: Color(0xFFA16207),
    etiqueta: 'Pendiente',
  ),
  'cancelled': (
    fondo: Color(0xFFFEE2E2),
    texto: Color(0xFFDC2626),
    etiqueta: 'Cancelada',
  ),
  'completed': (
    fondo: Color(0xFFDBEAFE),
    texto: Color(0xFF1D4ED8),
    etiqueta: 'Completada',
  ),
};

/// `METHOD_LABEL`.
const _metodos = <String, ({String etiqueta, Color texto, Color fondo})>{
  'epayco': (
    etiqueta: 'ePayco',
    texto: Color(0xFF2563EB),
    fondo: Color(0xFFEFF6FF),
  ),
  // Reservas de antes del cambio a ePayco.
  'wompi': (
    etiqueta: 'Wompi',
    texto: Color(0xFF2563EB),
    fondo: Color(0xFFEFF6FF),
  ),
  'efectivo': (
    etiqueta: 'Efectivo',
    texto: Color(0xFFD97706),
    fondo: Color(0xFFFFFBEB),
  ),
};

/// `PERIODS`.
const _periodos = [
  ('hoy', 'Hoy'),
  ('semana', 'Semana'),
  ('mes', 'Mes'),
  ('todo', 'Todo'),
];

/// `ITEMS_PER_PAGE`.
const _porPagina = 12;

/// `fmtBig`.
String _fmtBig(int n) {
  if (n >= 1000000) return '\$${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '\$${(n / 1000).round()}K';
  return '\$${formatCop(n)}';
}

/// `inPeriod`. La semana arranca el lunes (`weekStartsOn: 1`).
bool _enPeriodo(DateTime d, String periodo) {
  final hoy = ahoraEnBogota();
  switch (periodo) {
    case 'hoy':
      return d.year == hoy.year && d.month == hoy.month && d.day == hoy.day;
    case 'semana':
      final lunes = DateTime(
        hoy.year,
        hoy.month,
        hoy.day,
      ).subtract(Duration(days: hoy.weekday - 1));
      final domingo = lunes.add(const Duration(days: 7));
      return !d.isBefore(lunes) && d.isBefore(domingo);
    case 'mes':
      return d.year == hoy.year && d.month == hoy.month;
  }
  return true;
}

class _PagosScreenState extends State<PagosScreen> {
  String _tab = 'historial';
  String _periodo = 'todo';
  String _estado = 'all';
  String _busqueda = '';
  int _pagina = 1;

  List<Booking> _reservas = const [];
  ClubPerfil? _club;

  bool _cargandoReservas = true;
  bool _cargandoClub = true;
  bool _guardandoCuenta = false;

  final _buscador = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar();
    rtcReservasCambiaron.addListener(_recargarReservas);
  }

  @override
  void dispose() {
    rtcReservasCambiaron.removeListener(_recargarReservas);
    _buscador.dispose();
    super.dispose();
  }

  /// El `invalidateQueries(['owner-bookings'])` del socket: solo se vuelven a
  /// pedir las reservas, sin poner esqueletos ni mover el scroll.
  Future<void> _recargarReservas() async {
    try {
      final r = await ownerApi.reservas();
      if (!mounted) return;
      setState(() => _reservas = r);
    } on RtcApiException {
      // Se queda con lo que tenia; la proxima recarga lo corrige.
    }
  }

  Future<void> _cargar() async {
    setState(() {
      _cargandoReservas = true;
      _cargandoClub = true;
    });
    // Las dos queries de la web, en paralelo.
    final futuros = [
      ownerApi
          .reservas()
          .then((r) {
            if (!mounted) return;
            setState(() {
              _reservas = r;
              _cargandoReservas = false;
            });
          })
          .catchError((Object e) {
            if (!mounted) return;
            setState(() => _cargandoReservas = false);
            if (e is RtcApiException) {
              rtcToast(context, e.message, tipo: RtcToastTipo.error);
            }
          }),
      ownerApi.perfilClub().then((c) {
        if (!mounted) return;
        setState(() {
          _club = c;
          _cargandoClub = false;
        });
      }),
    ];
    await Future.wait(futuros);
  }

  // ── FILTRADO ─────────────────────────────────────────────────────────

  List<Booking> get _filtradas {
    final q = _busqueda.toLowerCase().replaceAll('#', '');
    final lista =
        _reservas
            .where((b) => _enPeriodo(b.date, _periodo))
            .where((b) => _estado == 'all' || b.status == _estado)
            .where(
              (b) =>
                  q.isEmpty ||
                  b.guestName.toLowerCase().contains(q) ||
                  b.guestEmail.toLowerCase().contains(q) ||
                  b.bookingCode.toLowerCase().contains(q),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    return lista;
  }

  bool _esConfirmada(Booking b) =>
      b.status == 'confirmed' || b.status == 'completed';

  void _reiniciarPagina() => _pagina = 1;

  // ── VISTA ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _cargar,
      color: Green.c600,
      child: ListView(
        padding: const EdgeInsets.only(bottom: RtcSpace.s12 + RtcSpace.s2),
        children: [
          _encabezado(),
          const SizedBox(height: RtcSpace.s5),
          _tabs(),
          const SizedBox(height: RtcSpace.s5),
          switch (_tab) {
            'cuenta' => _tabCuenta(),
            _ => _tabHistorial(),
          },
        ],
      ),
    );
  }

  /// El CSV de la web (`downloadCSV`), con las reservas filtradas que se ven
  /// en pantalla. En el telefono no se descarga: se comparte, y la persona
  /// elige si lo manda por WhatsApp, correo o lo guarda en Drive.
  Future<void> _exportar() async {
    final filas = _filtradas;
    if (filas.isEmpty) {
      rtcToast(context, 'No hay pagos para exportar', tipo: RtcToastTipo.error);
      return;
    }
    String celda(Object v) => '"${v.toString().replaceAll('"', '""')}"';
    final lineas = [
      [
        'Código',
        'Cliente',
        'Email',
        'Fecha',
        'Hora',
        'Estado',
        'Método',
        'Pagó el cliente COP',
        'Te llega COP',
      ].map(celda).join(','),
      for (final b in filas)
        [
          b.bookingCode,
          b.guestName,
          b.guestEmail,
          fechaIso(b.date),
          '${b.startTime} – ${b.endTime}',
          _estados[b.status]?.etiqueta ?? b.status,
          _metodos[b.paymentMethod]?.etiqueta ?? b.paymentMethod,
          b.totalPrice,
          b.netoParaDueno,
        ].map(celda).join(','),
    ];
    // Con BOM para que Excel abra bien las tildes.
    final bytes = utf8.encode('\uFEFF${lineas.join('\n')}');
    final nombre = 'pagos-${fechaIso(ahoraEnBogota())}.csv';
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'text/csv', name: nombre)],
        fileNameOverrides: [nombre],
        subject: 'Pagos ReservaTuCancha',
      ),
    );
  }

  Widget _encabezado() {
    // `flex-col sm:flex-row`: en movil el boton va debajo.
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
        Row(
          children: [
            Expanded(
              child: Text(
                'Pagos',
                style: RtcType.xl2.copyWith(
                  letterSpacing: -0.4,
                  fontWeight: FontWeight.w900,
                  color: Gray.c900,
                ),
              ),
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _exportar,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: RtcSpace.s4,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: RtcRadius.brFull,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.download,
                      size: 16,
                      color: Gray.c900,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Exportar',
                      style: RtcType.sm.copyWith(
                        fontWeight: RtcType.semibold,
                        color: Gray.c900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Historial de cobros y tu cuenta de ePayco',
          style: RtcType.sm.copyWith(color: Gray.c500),
        ),
      ],
    );
  }

  Widget _tabs() {
    return Wrap(
      spacing: RtcSpace.s2,
      runSpacing: RtcSpace.s2,
      children: [
        for (final (clave, etiqueta, icono) in const [
          ('historial', 'Historial de pagos', LucideIcons.chartColumn),
          ('cuenta', 'Cuenta de pagos', LucideIcons.landmark),
        ])
          _pastilla(
            etiqueta: etiqueta,
            icono: icono,
            activa: _tab == clave,
            grande: true,
            onTap: () => setState(() => _tab = clave),
          ),
      ],
    );
  }

  /// Las pastillas negras de los filtros y las pestanas.
  Widget _pastilla({
    required String etiqueta,
    required bool activa,
    required VoidCallback onTap,
    IconData? icono,
    bool grande = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: RtcDur.pick,
        curve: RtcCurves.smooth,
        padding: EdgeInsets.symmetric(
          horizontal: grande ? RtcSpace.s5 : RtcSpace.s3,
          vertical: grande ? 10 : 6,
        ),
        decoration: BoxDecoration(
          color: activa ? Gray.c900 : Colors.transparent,
          borderRadius: RtcRadius.brFull,
          border: Border.all(color: activa ? Gray.c900 : Gray.c200, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icono != null) ...[
              Icon(icono, size: 16, color: activa ? Colors.white : Gray.c500),
              const SizedBox(width: RtcSpace.s2),
            ],
            Text(
              etiqueta,
              style: (grande ? RtcType.sm : RtcType.xs).copyWith(
                fontWeight: RtcType.bold,
                color: activa ? Colors.white : Gray.c500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── TAB HISTORIAL ────────────────────────────────────────────────────

  Widget _tabHistorial() {
    final filtradas = _filtradas;
    final ingresos = filtradas
        .where(_esConfirmada)
        .fold<int>(0, (s, b) => s + b.netoParaDueno);
    final pendiente = filtradas
        .where((b) => b.status == 'pending')
        .fold<int>(0, (s, b) => s + b.netoParaDueno);
    final canceladas = filtradas.where((b) => b.status == 'cancelled').length;
    final confirmadas = filtradas.where(_esConfirmada).length;
    final pendientes = filtradas.where((b) => b.status == 'pending').length;

    final totalPaginas = (filtradas.length / _porPagina).ceil();
    final desde = (_pagina - 1) * _porPagina;
    final hasta = (desde + _porPagina).clamp(0, filtradas.length);
    final pagina = desde >= filtradas.length
        ? const <Booking>[]
        : filtradas.sublist(desde, hasta);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _filtroPeriodo(filtradas.length),
        const SizedBox(height: RtcSpace.s5),
        _kpis(
          ingresos: ingresos,
          pendiente: pendiente,
          total: filtradas.length,
          canceladas: canceladas,
          confirmadas: confirmadas,
          pendientes: pendientes,
        ),
        const SizedBox(height: RtcSpace.s5),
        _buscadorYEstados(),
        if (ingresos > 0) ...[
          const SizedBox(height: RtcSpace.s5),
          _resumenSaldo(ingresos, confirmadas),
        ],
        const SizedBox(height: RtcSpace.s5),
        _lista(pagina, filtradas.length),
        if (!_cargandoReservas && filtradas.length > _porPagina) ...[
          const SizedBox(height: RtcSpace.s5),
          _paginacion(desde, hasta, filtradas.length, totalPaginas),
        ],
      ],
    );
  }

  Widget _filtroPeriodo(int resultados) {
    return Container(
      padding: const EdgeInsets.all(RtcSpace.s4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RtcRadius.brXxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Padding(
                padding: EdgeInsets.only(right: RtcSpace.s2),
                child: Icon(
                  LucideIcons.slidersHorizontal,
                  size: 16,
                  color: Gray.c400,
                ),
              ),
              Expanded(
                child: Wrap(
                  spacing: RtcSpace.s2,
                  runSpacing: RtcSpace.s2,
                  children: [
                    for (final (clave, etiqueta) in _periodos)
                      _pastilla(
                        etiqueta: etiqueta,
                        activa: _periodo == clave,
                        onTap: () => setState(() {
                          _periodo = clave;
                          _reiniciarPagina();
                        }),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: RtcSpace.s3),
          Text(
            '$resultados resultado${resultados != 1 ? 's' : ''}',
            style: RtcType.xs.copyWith(
              fontWeight: RtcType.medium,
              color: Gray.c400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpis({
    required int ingresos,
    required int pendiente,
    required int total,
    required int canceladas,
    required int confirmadas,
    required int pendientes,
  }) {
    final tarjetas = <(String, String, String, IconData, Color, Color)>[
      (
        'Ingresos confirmados',
        _fmtBig(ingresos),
        '$confirmadas reserva${confirmadas != 1 ? 's' : ''}',
        LucideIcons.dollarSign,
        const Color(0xFF059669), // emerald-600
        const Color(0xFFECFDF5), // emerald-50
      ),
      (
        'Esperando pago',
        _fmtBig(pendiente),
        '$pendientes pendiente${pendientes != 1 ? 's' : ''}',
        LucideIcons.clock,
        const Color(0xFFD97706), // amber-600
        const Color(0xFFFFFBEB), // amber-50
      ),
      (
        'Total reservas',
        '$total',
        _periodo == 'todo'
            ? 'Historial completo'
            : 'En este ${_periodo == 'hoy' ? 'día' : _periodo}',
        LucideIcons.calendarDays,
        const Color(0xFF2563EB),
        const Color(0xFFEFF6FF),
      ),
      (
        'Canceladas',
        '$canceladas',
        '${confirmadas > 0 ? (canceladas / (total == 0 ? 1 : total) * 100).round() : 0}% del período',
        LucideIcons.circleX,
        Red.c500,
        Red.c50,
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: tarjetas.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: RtcSpace.s3,
        mainAxisSpacing: RtcSpace.s3,
        mainAxisExtent: 128,
      ),
      itemBuilder: (context, i) {
        final (etiqueta, valor, sub, icono, color, fondo) = tarjetas[i];
        return Container(
          padding: const EdgeInsets.all(RtcSpace.s4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: RtcRadius.brXxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      etiqueta,
                      style: RtcType.xs.copyWith(
                        fontSize: 12,
                        fontWeight: RtcType.semibold,
                        color: Gray.c500,
                      ),
                    ),
                  ),
                  const SizedBox(width: RtcSpace.s2),
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: fondo,
                      borderRadius: RtcRadius.brLg,
                    ),
                    child: Icon(icono, size: 16, color: color),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                _cargandoReservas ? '—' : valor,
                style: RtcType.xl2.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Gray.c900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RtcType.xs.copyWith(color: Gray.c400),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buscadorYEstados() {
    final borde = OutlineInputBorder(
      borderRadius: RtcRadius.brXl,
      borderSide: const BorderSide(color: Gray.c200),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _buscador,
          onChanged: (v) => setState(() {
            _busqueda = v;
            _reiniciarPagina();
          }),
          style: RtcType.sm.copyWith(color: Gray.c900),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Buscar por cliente, email o código (#XXXXXXXX)...',
            hintStyle: RtcType.xs.copyWith(color: Gray.c400),
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: RtcSpace.s3, right: RtcSpace.s2),
              child: Icon(LucideIcons.search, size: 16, color: Gray.c400),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 0),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: RtcSpace.s4,
              vertical: RtcSpace.s3,
            ),
            border: borde,
            enabledBorder: borde,
            focusedBorder: OutlineInputBorder(
              borderRadius: RtcRadius.brXl,
              borderSide: const BorderSide(color: Green.c400, width: 2),
            ),
          ),
        ),
        const SizedBox(height: RtcSpace.s3),
        Wrap(
          spacing: RtcSpace.s2,
          runSpacing: RtcSpace.s2,
          children: [
            for (final (clave, etiqueta) in const [
              ('all', 'Todos'),
              ('confirmed', 'Confirmadas'),
              ('pending', 'Pendientes'),
              ('completed', 'Completadas'),
              ('cancelled', 'Canceladas'),
            ])
              _pastilla(
                etiqueta: etiqueta,
                activa: _estado == clave,
                onTap: () => setState(() {
                  _estado = clave;
                  _reiniciarPagina();
                }),
              ),
          ],
        ),
      ],
    );
  }

  Widget _resumenSaldo(int ingresos, int confirmadas) {
    return Container(
      padding: const EdgeInsets.all(RtcSpace.s5),
      decoration: BoxDecoration(
        // `from-green-600 to-emerald-500`
        gradient: const LinearGradient(colors: [Green.c600, Color(0xFF10B981)]),
        borderRadius: RtcRadius.brXxl,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.20),
              borderRadius: RtcRadius.brXl,
            ),
            child: const Icon(
              LucideIcons.trendingUp,
              size: 20,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: RtcSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INGRESOS DEL PERÍODO',
                  style: RtcType.sm.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  '$confirmadas reservas confirmadas / completadas',
                  style: RtcType.xs.copyWith(
                    color: const Color(0xFFDCFCE7), // green-100
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: RtcSpace.s3),
          Text(
            _fmtBig(ingresos),
            style: RtcType.xl2.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _lista(List<Booking> pagina, int total) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RtcRadius.brXxl,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_cargandoReservas)
            for (var i = 0; i < 5; i++) _filaEsqueleto(i > 0)
          else if (total == 0)
            _sinResultados()
          else
            for (var i = 0; i < pagina.length; i++) _fila(pagina[i], i > 0),
        ],
      ),
    );
  }

  Widget _filaEsqueleto(bool conBorde) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: conBorde
            ? const Border(top: BorderSide(color: Gray.c50))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RtcSpace.s4,
          vertical: RtcSpace.s4,
        ),
        child: RtcSkeletonPulse(
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Gray.c100,
                  borderRadius: RtcRadius.brXl,
                ),
              ),
              const SizedBox(width: RtcSpace.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 12, color: Gray.c100),
                    const SizedBox(height: RtcSpace.s2),
                    FractionallySizedBox(
                      widthFactor: 0.6,
                      child: Container(height: 10, color: Gray.c100),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: RtcSpace.s4),
              Container(width: 80, height: 20, color: Gray.c100),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sinResultados() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 64), // py-16
      child: Column(
        children: [
          const Icon(LucideIcons.dollarSign, size: 40, color: Gray.c200),
          const SizedBox(height: RtcSpace.s3),
          Text(
            'SIN RESULTADOS',
            style: RtcType.sm.copyWith(
              fontWeight: FontWeight.w900,
              color: Gray.c400,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s6),
            child: Text(
              _busqueda.isNotEmpty || _estado != 'all'
                  ? 'Intenta con otros filtros'
                  : 'No hay pagos en este período',
              textAlign: TextAlign.center,
              style: RtcType.xs.copyWith(color: Gray.c400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fila(Booking b, bool conBorde) {
    final confirmada = _esConfirmada(b);
    final pendiente = b.status == 'pending';
    final metodo = _metodos[b.paymentMethod] ?? _metodos['epayco']!;
    final estado = _estados[b.status] ?? _estados['pending']!;

    return DecoratedBox(
      decoration: BoxDecoration(
        border: conBorde
            ? const Border(top: BorderSide(color: Gray.c50))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RtcSpace.s4,
          vertical: 14, // py-3.5
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: confirmada
                    ? const Color(0xFFDCFCE7) // green-100
                    : pendiente
                    ? const Color(0xFFFEF3C7) // amber-100
                    : Red.c100,
                borderRadius: RtcRadius.brXl,
              ),
              child: Icon(
                confirmada
                    ? LucideIcons.circleCheck
                    : pendiente
                    ? LucideIcons.clock
                    : LucideIcons.circleX,
                size: 16,
                color: confirmada
                    ? Green.c600
                    : pendiente
                    ? const Color(0xFFD97706)
                    : Red.c500,
              ),
            ),
            const SizedBox(width: RtcSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.guestName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RtcType.sm.copyWith(
                      fontWeight: RtcType.bold,
                      color: Gray.c900,
                    ),
                  ),
                  Text(
                    b.guestEmail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RtcType.xs.copyWith(fontSize: 11, color: Gray.c400),
                  ),
                  if (b.courtName.isNotEmpty)
                    Text(
                      b.courtName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RtcType.xs.copyWith(
                        fontSize: 10,
                        color: Gray.c300,
                      ),
                    ),
                  const SizedBox(height: 6),
                  // La grilla de escritorio (`sm:grid-cols-[...]`) no cabe en
                  // telefono: fecha, metodo y estado bajan debajo del cliente.
                  Text(
                    '${diaMesCorto(b.date)} ${b.date.year} · '
                    '${hora12(b.startTime)} – ${hora12(b.endTime)}',
                    style: RtcType.xs.copyWith(color: Gray.c400),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: RtcSpace.s2,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _insignia(
                        metodo.etiqueta,
                        metodo.fondo,
                        metodo.texto,
                        icono: b.paymentMethod == 'efectivo'
                            ? LucideIcons.banknote
                            : LucideIcons.creditCard,
                      ),
                      _insignia(estado.etiqueta, estado.fondo, estado.texto),
                      if (b.bookingCode.isNotEmpty)
                        Text(
                          '#${b.bookingCode}',
                          style: RtcType.xs.copyWith(
                            fontSize: 10,
                            color: Gray.c300,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: RtcSpace.s3),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${formatCop(b.netoParaDueno)}',
                  style: RtcType.sm.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Gray.c900,
                  ),
                ),
                Text(
                  'COP',
                  style: RtcType.xs.copyWith(fontSize: 10, color: Gray.c400),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _insignia(String texto, Color fondo, Color color, {IconData? icono}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: fondo, borderRadius: RtcRadius.brFull),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            texto,
            style: RtcType.xs.copyWith(
              fontSize: 10,
              fontWeight: RtcType.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paginacion(int desde, int hasta, int total, int totalPaginas) {
    // `page === 1 || page === totalPages || |page - currentPage| <= 1`, con
    // los puntos suspensivos en las posiciones 2 y totalPages-1.
    final botones = <Widget>[];
    for (var p = 1; p <= totalPaginas; p++) {
      final visible = p == 1 || p == totalPaginas || (p - _pagina).abs() <= 1;
      final puntos = !visible && (p == 2 || p == totalPaginas - 1);
      if (!visible && !puntos) continue;
      if (puntos) {
        botones.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('…', style: RtcType.sm.copyWith(color: Gray.c400)),
          ),
        );
        continue;
      }
      final actual = p == _pagina;
      botones.add(
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _pagina = p),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: actual ? Green.c600 : null,
              borderRadius: RtcRadius.brLg,
              border: actual ? null : Border.all(color: Gray.c200),
            ),
            child: Text(
              '$p',
              style: RtcType.xs.copyWith(
                fontWeight: RtcType.bold,
                color: actual ? Colors.white : Gray.c700,
              ),
            ),
          ),
        ),
      );
    }

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
                const TextSpan(text: '–'),
                TextSpan(
                  text: '$hasta',
                  style: const TextStyle(fontWeight: RtcType.bold),
                ),
                const TextSpan(text: ' de '),
                TextSpan(
                  text: '$total',
                  style: const TextStyle(fontWeight: RtcType.bold),
                ),
              ],
            ),
            style: RtcType.xs.copyWith(color: Gray.c500),
          ),
          const SizedBox(height: RtcSpace.s4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _flecha(
                LucideIcons.chevronLeft,
                _pagina > 1 ? () => setState(() => _pagina--) : null,
              ),
              const SizedBox(width: RtcSpace.s2),
              ...botones,
              const SizedBox(width: RtcSpace.s2),
              _flecha(
                LucideIcons.chevronRight,
                _pagina < totalPaginas ? () => setState(() => _pagina++) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _flecha(IconData icono, VoidCallback? onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        // `disabled:opacity-40`
        opacity: onTap == null ? 0.4 : 1,
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

  // ── TAB CUENTA ───────────────────────────────────────────────────────

  Widget _tabCuenta() {
    if (_cargandoClub) {
      return RtcSkeletonPulse(
        child: Container(
          height: 256, // h-64
          decoration: BoxDecoration(
            color: Gray.c100,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      );
    }

    final actual = _club?.epaycoReceptorId;
    return CuentaEpayco(
      // Al cambiar el id guardado, el formulario se rehace con el nuevo.
      key: ValueKey(actual ?? 'sin-cuenta'),
      actual: actual,
      guardando: _guardandoCuenta,
      onGuardar: _guardarCuenta,
    );
  }

  Future<void> _guardarCuenta(String receptorId) async {
    final id = _club?.id ?? '';
    if (id.isEmpty) {
      rtcToast(
        context,
        'ID del club no detectado. Desliza hacia abajo para recargar.',
        tipo: RtcToastTipo.error,
      );
      return;
    }
    setState(() => _guardandoCuenta = true);
    try {
      await ownerApi.guardarCuentaEpayco(id, receptorId);
      if (!mounted) return;
      rtcToast(context, 'Cuenta de ePayco conectada');
      final club = await ownerApi.perfilClub();
      if (!mounted) return;
      setState(() {
        _club = club;
        _guardandoCuenta = false;
      });
    } on RtcApiException catch (e) {
      if (!mounted) return;
      setState(() => _guardandoCuenta = false);
      rtcToast(context, e.message, tipo: RtcToastTipo.error);
    }
  }
}
