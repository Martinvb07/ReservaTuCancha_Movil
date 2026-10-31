import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/owner_api.dart';
import '../../api/rtc_api.dart';
import '../../models/fechas.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/dashboard/graficas.dart';
import '../../widgets/motion/rtc_motion.dart';
import '../../widgets/rtc_toast.dart';

/// Port de `Frontend/src/app/dashboard/propetario/analytics/page.tsx`.
///
/// Ocho KPI y cinco graficas. En movil todo va en una columna: las grillas de
/// la web son `lg:grid-cols-2`, salvo la de los KPI que es `grid-cols-2`.
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

/// `STATUS_COLORS`.
const _coloresEstado = [
  Color(0xFF16A34A),
  Color(0xFFF59E0B),
  Color(0xFFEF4444),
  Color(0xFF3B82F6),
];
const _colorBarra = Color(0xFF16A34A);
const _colorLinea = Color(0xFF10B981);
const _colorHora = Color(0xFF6366F1);
const _colorDia = Color(0xFFF59E0B);

/// `fmt`.
String _fmt(int n) {
  if (n >= 1000000) return '\$${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '\$${(n / 1000).round()}K';
  return '\$$n';
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  OwnerAnalytics? _datos;
  List<MesAnalytics> _meses = const [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final (datos, meses) = await ownerApi.analytics();
      if (!mounted) return;
      setState(() {
        _datos = datos;
        _meses = meses;
        _cargando = false;
      });
    } on RtcApiException catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      rtcToast(context, e.message, tipo: RtcToastTipo.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _datos;
    final s = d?.stats;

    return RefreshIndicator(
      onRefresh: _cargar,
      color: Green.c600,
      child: ListView(
        padding: const EdgeInsets.only(bottom: RtcSpace.s12 + RtcSpace.s2),
        children: [
          _encabezado(),
          const SizedBox(height: RtcSpace.s5),
          _kpis(s),
          const SizedBox(height: RtcSpace.s5),
          _reservasPorMes(),
          const SizedBox(height: RtcSpace.s4),
          _ingresos(),
          const SizedBox(height: RtcSpace.s4),
          _estados(s),
          const SizedBox(height: RtcSpace.s4),
          _diasPopulares(d),
          const SizedBox(height: RtcSpace.s4),
          _horasPopulares(d),
          if (_cargando || (d?.porCancha.isNotEmpty ?? false)) ...[
            const SizedBox(height: RtcSpace.s4),
            _ranking(d),
          ],
        ],
      ),
    );
  }

  Widget _encabezado() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('✦', style: RtcType.xs.copyWith(color: Lime.c600)),
            const SizedBox(width: RtcSpace.s2),
            Text(
              'PANEL PROPIETARIO',
              style: RtcType.xs.copyWith(
                color: Lime.c600,
                fontWeight: RtcType.semibold,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'ANALYTICS',
          style: RtcType.xl2.copyWith(
            fontWeight: FontWeight.w900,
            color: Gray.c900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Rendimiento e ingresos de tus canchas',
          style: RtcType.sm.copyWith(color: Gray.c500),
        ),
      ],
    );
  }

  // ── KPIs ─────────────────────────────────────────────────────────────
  Widget _kpis(OwnerStats? s) {
    final kpis = <(String, String, IconData, Color, Color, String?)>[
      (
        'Reservas totales',
        '${s?.totalBookings ?? 0}',
        LucideIcons.calendarDays,
        const Color(0xFF2563EB),
        const Color(0xFFEFF6FF),
        null,
      ),
      (
        'Confirmadas',
        '${s?.confirmedBookings ?? 0}',
        LucideIcons.circleCheck,
        Green.c600,
        Green.c50,
        null,
      ),
      (
        'Ingresos totales',
        _fmt(s?.totalRevenue ?? 0),
        LucideIcons.dollarSign,
        const Color(0xFF059669),
        const Color(0xFFECFDF5),
        null,
      ),
      (
        'Canchas activas',
        '${s?.totalCourts ?? 0}',
        LucideIcons.building2,
        const Color(0xFF9333EA),
        const Color(0xFFFAF5FF),
        null,
      ),
      (
        'Pendientes',
        '${s?.pendingBookings ?? 0}',
        LucideIcons.clock,
        const Color(0xFFD97706),
        const Color(0xFFFFFBEB),
        null,
      ),
      (
        'Canceladas',
        '${s?.cancelledBookings ?? 0}',
        LucideIcons.circleX,
        Red.c500,
        Red.c50,
        null,
      ),
      (
        'Tasa confirmación',
        '${(s?.confirmRate ?? 0).round()}%',
        LucideIcons.trendingUp,
        const Color(0xFF4F46E5),
        const Color(0xFFEEF2FF),
        s == null
            ? null
            : '${s.confirmedBookings + s.completedBookings} de ${s.totalBookings}',
      ),
      (
        'Ingreso por reserva',
        _fmt(s?.avgRevenue ?? 0),
        LucideIcons.award,
        const Color(0xFFDB2777), // pink-600
        const Color(0xFFFDF2F8), // pink-50
        'promedio confirmadas',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: kpis.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: RtcSpace.s3,
        mainAxisSpacing: RtcSpace.s3,
        // 120 y no 112: la tarjeta con subtitulo y etiqueta de dos lineas
        // (INGRESO POR RESERVA) se pasaba por 2px.
        mainAxisExtent: 120,
      ),
      itemBuilder: (context, i) {
        if (_cargando) {
          return RtcSkeletonPulse(
            child: Container(
              decoration: BoxDecoration(
                color: Gray.c100,
                borderRadius: RtcRadius.brXl,
              ),
            ),
          );
        }
        final (etiqueta, valor, icono, color, fondo, sub) = kpis[i];
        return Container(
          padding: const EdgeInsets.all(RtcSpace.s4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: RtcRadius.brXxl,
            border: Border.all(color: Gray.c100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      etiqueta.toUpperCase(),
                      style: RtcType.xs.copyWith(
                        fontSize: 10,
                        color: Gray.c400,
                        fontWeight: RtcType.bold,
                        letterSpacing: 1.2,
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
                valor,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RtcType.xl2.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Gray.c900,
                ),
              ),
              if (sub != null)
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

  // ── GRAFICAS ─────────────────────────────────────────────────────────

  Widget _reservasPorMes() {
    return _tarjeta(
      titulo: 'Reservas por mes',
      subtitulo: 'Últimos 12 meses',
      icono: LucideIcons.chartColumn,
      color: const Color(0xFF2563EB),
      fondo: const Color(0xFFEFF6FF),
      alto: 220,
      hijo: _meses.isEmpty
          ? const GraficaVacia(alto: 220)
          : GraficaBarras(
              datos: [for (final m in _meses) (m.mesCorto, m.reservas)],
              color: _colorBarra,
              alto: 220,
            ),
    );
  }

  Widget _ingresos() {
    return _tarjeta(
      titulo: 'Ingresos (COP)',
      subtitulo: 'Últimos 12 meses',
      icono: LucideIcons.trendingUp,
      color: const Color(0xFF059669),
      fondo: const Color(0xFFECFDF5),
      alto: 190,
      hijo: _meses.isEmpty
          ? const GraficaVacia(alto: 190)
          : GraficaLinea(
              datos: [for (final m in _meses) (m.mesCorto, m.ingresos)],
              color: _colorLinea,
              formatoY: (v) => _fmt(v.round()),
            ),
    );
  }

  Widget _estados(OwnerStats? s) {
    final datos = <(String, num)>[
      ('Confirmadas', s?.confirmedBookings ?? 0),
      ('Pendientes', s?.pendingBookings ?? 0),
      ('Canceladas', s?.cancelledBookings ?? 0),
      ('Completadas', s?.completedBookings ?? 0),
    ].where((d) => d.$2 > 0).toList();

    return _tarjeta(
      titulo: 'Estado de reservas',
      subtitulo: 'Distribución total',
      icono: LucideIcons.users,
      color: const Color(0xFF9333EA),
      fondo: const Color(0xFFFAF5FF),
      alto: 190,
      hijo: datos.isEmpty
          ? const GraficaVacia(alto: 190)
          : GraficaDona(datos: datos, colores: _coloresEstado),
    );
  }

  Widget _diasPopulares(OwnerAnalytics? d) {
    final datos = d?.porDia ?? const <(String, int)>[];
    final hay = datos.any((x) => x.$2 > 0);
    return _tarjeta(
      titulo: 'Días más populares',
      subtitulo: 'Reservas activas por día de semana',
      icono: LucideIcons.calendarDays,
      color: const Color(0xFFD97706),
      fondo: const Color(0xFFFFFBEB),
      alto: 190,
      hijo: hay
          ? GraficaBarras(
              datos: [for (final x in datos) (x.$1, x.$2)],
              color: _colorDia,
            )
          : const GraficaVacia(alto: 190),
    );
  }

  Widget _horasPopulares(OwnerAnalytics? d) {
    final datos = d?.porHora ?? const <(String, int)>[];
    return _tarjeta(
      titulo: 'Horas más reservadas',
      subtitulo: 'Franja horaria de inicio',
      icono: LucideIcons.clock,
      color: const Color(0xFF4F46E5),
      fondo: const Color(0xFFEEF2FF),
      alto: 190,
      hijo: datos.isEmpty
          ? const GraficaVacia(alto: 190)
          : GraficaBarras(
              datos: [for (final x in datos) (horaCorta12(x.$1), x.$2)],
              color: _colorHora,
              // `interval={1}`: una etiqueta de cada dos.
              saltarEtiquetas: 2,
            ),
    );
  }

  Widget _ranking(OwnerAnalytics? d) {
    final canchas = d?.porCancha ?? const <(String, int, int, int)>[];
    final tope = canchas.isEmpty ? 0 : canchas.first.$3;

    return _tarjeta(
      titulo: 'Rendimiento por cancha',
      subtitulo: 'Ordenado por ingresos',
      icono: LucideIcons.award,
      color: const Color(0xFFDB2777),
      fondo: const Color(0xFFFDF2F8),
      alto: 0,
      hijo: _cargando
          ? Column(
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: RtcSpace.s3),
                    child: RtcSkeletonPulse(
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: Gray.c100,
                          borderRadius: RtcRadius.brXl,
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : Column(
              children: [
                for (var i = 0; i < canchas.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: RtcSpace.s3),
                    child: _filaRanking(canchas[i], i, tope),
                  ),
              ],
            ),
    );
  }

  Widget _filaRanking((String, int, int, int) c, int i, int tope) {
    final (nombre, reservas, ingresos, confirmadas) = c;
    final pct = tope > 0 ? (ingresos / tope) : 0.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 20,
          child: Text(
            '#${i + 1}',
            textAlign: TextAlign.right,
            style: RtcType.xs.copyWith(
              fontWeight: FontWeight.w900,
              color: Gray.c300,
            ),
          ),
        ),
        const SizedBox(width: RtcSpace.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RtcType.sm.copyWith(
                        fontWeight: RtcType.bold,
                        color: Gray.c800,
                      ),
                    ),
                  ),
                  const SizedBox(width: RtcSpace.s2),
                  Text(
                    _fmt(ingresos),
                    style: RtcType.xs.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              // La barra con el degradado emerald → lime.
              ClipRRect(
                borderRadius: RtcRadius.brFull,
                child: Container(
                  height: 6,
                  color: Gray.c100,
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: pct.clamp(0.0, 1.0),
                    child: const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF34D399), Lime.c400],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    '$reservas reservas',
                    style: RtcType.xs.copyWith(fontSize: 10, color: Gray.c400),
                  ),
                  const SizedBox(width: RtcSpace.s3),
                  Text(
                    '$confirmadas confirmadas',
                    style: RtcType.xs.copyWith(
                      fontSize: 10,
                      color: const Color(0xFF22C55E),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// `ChartCard`.
  Widget _tarjeta({
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required Color color,
    required Color fondo,
    required double alto,
    required Widget hijo,
  }) {
    return Container(
      padding: const EdgeInsets.all(RtcSpace.s5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RtcRadius.brXxl,
        border: Border.all(color: Gray.c100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo.toUpperCase(),
                      style: RtcType.xs.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Gray.c900,
                        letterSpacing: 1.6,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitulo,
                      style: RtcType.xs.copyWith(color: Gray.c400),
                    ),
                  ],
                ),
              ),
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
          const SizedBox(height: RtcSpace.s5),
          if (_cargando && alto > 0)
            RtcSkeletonPulse(
              child: Container(
                height: alto,
                decoration: BoxDecoration(
                  color: Gray.c100,
                  borderRadius: RtcRadius.brXl,
                ),
              ),
            )
          else
            hijo,
        ],
      ),
    );
  }
}
