import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../api/owner_api.dart';
import '../../auth/session.dart';
import '../../api/rtc_api.dart';
import '../../app/routes.dart';
import '../../models/booking.dart';
import '../../models/court.dart' show formatCop;
import '../../models/fechas.dart';
import '../../realtime/rtc_realtime.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../motion/rtc_motion.dart';
import '../rtc_toast.dart';

/// Port de `Frontend/src/components/dashboard/OwnerHomeWidgets.tsx`.
///
/// Es la mitad de abajo del Inicio del panel: el aviso de ePayco, la tarjeta de
/// la pagina publica del club, la grafica de los ultimos 7 dias, las reservas
/// por confirmar y las de hoy.
///
/// La grafica de la web es `recharts`; aca se dibuja con un CustomPainter para
/// no sumar una dependencia por siete barras.
class OwnerHomeWidgets extends StatefulWidget {
  const OwnerHomeWidgets({super.key});

  @override
  State<OwnerHomeWidgets> createState() => OwnerHomeWidgetsState();
}

/// `fmtCOP`.
String _fmtCop(int n) {
  if (n >= 1000000) return '\$${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '\$${(n / 1000).round()}K';
  return '\$$n';
}

/// `STATUS_BORDER`, `STATUS_TIME` y `STATUS_LABEL` juntos.
const _estados = <String, (Color, Color, Color, String)>{
  // borde, fondo, color de la hora, etiqueta
  'confirmed': (Color(0xFFBBF7D0), Green.c50, Green.c700, 'Confirmada'),
  'pending': (
    Color(0xFFFDE68A),
    Color(0xFFFFFBEB),
    Color(0xFFB45309),
    'Pendiente',
  ),
  'cancelled': (Red.c100, Red.c50, Red.c500, 'Cancelada'),
  'completed': (
    Color(0xFFBFDBFE),
    Color(0xFFEFF6FF),
    Color(0xFF1D4ED8),
    'Completada',
  ),
};

(Color, Color, Color, String) _estilo(String estado) =>
    _estados[estado] ?? _estados['pending']!;

class OwnerHomeWidgetsState extends State<OwnerHomeWidgets> {
  List<Booking> _reservas = const [];
  ClubInfo? _club;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    cargar();
    rtcReservasCambiaron.addListener(_alLlegarAviso);
  }

  @override
  void dispose() {
    rtcReservasCambiaron.removeListener(_alLlegarAviso);
    super.dispose();
  }

  /// El `invalidateQueries(['owner-bookings'])` del socket, en silencio.
  void _alLlegarAviso() => cargar(silencioso: true);

  /// Igual que en Reservas: tras confirmar no se vuelve a poner el esqueleto,
  /// que reemplaza todo y manda el scroll al principio.
  Future<void> cargar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _cargando = true);
    try {
      final reservas = await ownerApi.reservas();
      if (!mounted) return;
      setState(() {
        _reservas = reservas;
        _cargando = false;
      });
    } on RtcApiException {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
    final club = await ownerApi.club();
    if (!mounted) return;
    setState(() => _club = club);
  }

  // ── DATOS DERIVADOS ──────────────────────────────────────────────────

  List<Booking> get _pendientes =>
      _reservas.where((b) => b.status == 'pending').toList();

  bool _esHoy(DateTime d) {
    final hoy = DateTime.now();
    return d.year == hoy.year && d.month == hoy.month && d.day == hoy.day;
  }

  List<Booking> get _deHoy {
    final lista = _reservas.where((b) => _esHoy(b.date)).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    return lista;
  }

  /// `weekData`: los ultimos 7 dias, de hace 6 hasta hoy.
  List<({String dia, int reservas, int ingresos, bool hoy})> get _semana {
    final hoy = DateTime.now();
    return List.generate(7, (i) {
      final d = DateTime(
        hoy.year,
        hoy.month,
        hoy.day,
      ).subtract(Duration(days: 6 - i));
      final delDia = _reservas
          .where(
            (b) =>
                b.date.year == d.year &&
                b.date.month == d.month &&
                b.date.day == d.day,
          )
          .toList();
      final ingresos = delDia
          .where((b) => b.status == 'confirmed' || b.status == 'completed')
          .fold<int>(0, (s, b) => s + b.netoParaDueno);
      return (
        // `format(day, 'EEE', { locale: es })`
        dia: diasCortos[d.weekday % 7].toLowerCase(),
        reservas: delDia.length,
        ingresos: ingresos,
        hoy: _esHoy(d),
      );
    });
  }

  // ── PINTADO ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final club = _club;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // La cuenta de pagos la conecta el dueño, no sus empleados.
        if (club != null && !club.epaycoConectado && RtcSession.instance.user?.esStaff != true) ...[
          _avisoEpayco(),
          const SizedBox(height: RtcSpace.s5),
        ],
        if (club?.slug != null && club!.slug!.isNotEmpty) ...[
          _paginaPublica(club.slug!),
          const SizedBox(height: RtcSpace.s5),
        ],
        _grafica(),
        const SizedBox(height: RtcSpace.s5),
        _porConfirmar(),
        const SizedBox(height: RtcSpace.s5),
        _reservasDeHoy(),
      ],
    );
  }

  Widget _avisoEpayco() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => rtcIrAlPanel('/dashboard/propetario/pagos'),
      child: Container(
        padding: const EdgeInsets.all(RtcSpace.s4),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB), // amber-50
          borderRadius: RtcRadius.brXxl,
          border: Border.all(color: const Color(0xFFFDE68A)), // amber-200
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B), // amber-500
                borderRadius: RtcRadius.brXl,
              ),
              child: const Icon(
                LucideIcons.circleAlert,
                size: 20,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: RtcSpace.s4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Conecta tu cuenta de ePayco',
                    style: RtcType.sm.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF78350F), // amber-900
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sin ella tus canchas no pueden recibir reservas pagadas '
                    'en línea: no hay a dónde consignarte.',
                    style: RtcType.xs.copyWith(
                      color: const Color(0xFFB45309), // amber-700
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _paginaPublica(String slug) {
    final url = 'https://reservatucancha.site/club/$slug';
    return Container(
      padding: const EdgeInsets.all(RtcSpace.s4),
      decoration: BoxDecoration(
        // bg-gradient-to-r from-gray-900 to-gray-800
        gradient: const LinearGradient(colors: [Gray.c900, Gray.c800]),
        borderRadius: RtcRadius.brXxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Lime.c400,
                  borderRadius: RtcRadius.brXl,
                ),
                child: const Text('🔗', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: RtcSpace.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tu página pública',
                      style: RtcType.sm.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'reservatucancha.site/club/$slug',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RtcType.xs.copyWith(color: Gray.c400),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: RtcSpace.s3),
          Row(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  if (!mounted) return;
                  rtcToast(context, 'Link copiado');
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: RtcSpace.s3,
                    vertical: 6,
                  ),
                  decoration: const BoxDecoration(
                    color: Lime.c400,
                    borderRadius: RtcRadius.brFull,
                  ),
                  child: Text(
                    'Copiar link',
                    style: RtcType.xs.copyWith(
                      color: Gray.c900,
                      fontWeight: RtcType.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: RtcSpace.s2),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.externalApplication,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: RtcSpace.s3,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: RtcRadius.brFull,
                    border: Border.all(color: Gray.c600),
                  ),
                  child: Text(
                    'Ver página',
                    style: RtcType.xs.copyWith(
                      color: Gray.c300,
                      fontWeight: RtcType.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── GRAFICA ──────────────────────────────────────────────────────────
  Widget _grafica() {
    final semana = _semana;
    final totalReservas = semana.fold<int>(0, (s, d) => s + d.reservas);
    final totalIngresos = semana.fold<int>(0, (s, d) => s + d.ingresos);

    return _tarjeta(
      titulo: 'Últimos 7 días',
      subtitulo: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$totalReservas reserva${totalReservas != 1 ? 's' : ''} · ',
            ),
            TextSpan(
              text: '${_fmtCop(totalIngresos)} COP',
              style: RtcType.xs.copyWith(
                color: Green.c600,
                fontWeight: RtcType.semibold,
              ),
            ),
          ],
        ),
        style: RtcType.xs.copyWith(color: Gray.c400),
      ),
      icono: LucideIcons.trendingUp,
      iconoColor: const Color(0xFF4F46E5), // indigo-600
      iconoFondo: const Color(0xFFEEF2FF), // indigo-50
      hijo: Column(
        children: [
          if (_cargando)
            RtcSkeletonPulse(
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Gray.c50,
                  borderRadius: RtcRadius.brXl,
                ),
              ),
            )
          else
            SizedBox(
              height: 160,
              child: CustomPaint(
                size: Size.infinite,
                painter: _BarrasPainter(semana),
              ),
            ),
          const SizedBox(height: RtcSpace.s3),
          Container(height: 1, color: Gray.c50),
          const SizedBox(height: RtcSpace.s3),
          Row(
            children: [
              _leyenda(Green.c600, 'Hoy'),
              const SizedBox(width: RtcSpace.s4),
              _leyenda(const Color(0xFFBBF7D0), 'Otros días'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _leyenda(Color color, String texto) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, borderRadius: RtcRadius.brSm),
        ),
        const SizedBox(width: 6),
        Text(texto, style: RtcType.xs.copyWith(fontSize: 11, color: Gray.c400)),
      ],
    );
  }

  // ── POR CONFIRMAR ────────────────────────────────────────────────────
  Widget _porConfirmar() {
    final pendientes = _pendientes;
    return _tarjeta(
      titulo: 'Por confirmar',
      subtitulo: Text(
        _cargando
            ? '—'
            : '${pendientes.length} pendiente${pendientes.length != 1 ? 's' : ''}',
        style: RtcType.xs.copyWith(color: Gray.c400),
      ),
      icono: pendientes.isEmpty ? LucideIcons.circleCheck : LucideIcons.clock,
      iconoColor: pendientes.isEmpty ? Gray.c400 : const Color(0xFFD97706),
      iconoFondo: pendientes.isEmpty ? Gray.c100 : const Color(0xFFFEF3C7),
      hijo: _cargando
          ? Column(
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: RtcSpace.s2),
                    child: RtcSkeletonPulse(
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: Gray.c50,
                          borderRadius: RtcRadius.brXl,
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : pendientes.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: RtcSpace.s6),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Green.c50,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.circleCheck,
                      size: 24,
                      color: Color(0xFF22C55E),
                    ),
                  ),
                  const SizedBox(height: RtcSpace.s3),
                  Text(
                    'Todo al día',
                    style: RtcType.sm.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Gray.c400,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sin reservas pendientes',
                    style: RtcType.xs.copyWith(color: Gray.c300),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                for (final b in pendientes.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: RtcSpace.s2),
                    child: _filaPendiente(b),
                  ),
                if (pendientes.length > 5)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => rtcIrAlPanel('/dashboard/propetario/reservas'),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Ver ${pendientes.length - 5} más',
                            style: RtcType.xs.copyWith(
                              color: Green.c600,
                              fontWeight: RtcType.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            LucideIcons.arrowRight,
                            size: 14,
                            color: Green.c600,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _filaPendiente(Booking b) {
    final efectivo = b.paymentMethod == 'efectivo';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s3,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // amber-50
        borderRadius: RtcRadius.brXl,
        border: Border.all(color: const Color(0xFFFEF3C7)), // amber-100
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.guestName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RtcType.xs.copyWith(
                    fontWeight: RtcType.bold,
                    color: Gray.c800,
                  ),
                ),
                Text(
                  '${diaMesCorto(b.date)} · ${hora12(b.startTime)}'
                  '${b.courtName.isEmpty ? '' : ' · ${b.courtName}'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RtcType.xs.copyWith(fontSize: 10, color: Gray.c400),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: efectivo
                        ? const Color(0xFFFDE68A) // amber-200
                        : const Color(0xFFDBEAFE), // blue-100
                    borderRadius: RtcRadius.brFull,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        efectivo
                            ? LucideIcons.banknote
                            : LucideIcons.creditCard,
                        size: 10,
                        color: efectivo
                            ? const Color(0xFF92400E) // amber-800
                            : const Color(0xFF1D4ED8), // blue-700
                      ),
                      const SizedBox(width: 3),
                      Text(
                        efectivo ? 'Efectivo' : 'ePayco',
                        style: RtcType.xs.copyWith(
                          fontSize: 9,
                          fontWeight: RtcType.bold,
                          color: efectivo
                              ? const Color(0xFF92400E)
                              : const Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: RtcSpace.s3),
          // La confirma ePayco al aprobar el pago, no el club: si el club
          // pudiera, una reserva sin pagar le llegaria al jugador confirmada.
          Text(
            'Esperando pago',
            style: RtcType.xs.copyWith(
              fontSize: 10,
              fontWeight: RtcType.bold,
              color: const Color(0xFFB45309), // amber-700
            ),
          ),
        ],
      ),
    );
  }

  // ── RESERVAS DE HOY ──────────────────────────────────────────────────
  Widget _reservasDeHoy() {
    final hoy = _deHoy;
    final confirmados = hoy
        .where((b) => b.status == 'confirmed' || b.status == 'completed')
        .fold<int>(0, (s, b) => s + b.netoParaDueno);

    return _tarjeta(
      titulo: 'Reservas de hoy',
      subtitulo: Text(
        fechaLargaCapitalizada(DateTime.now()),
        style: RtcType.xs.copyWith(color: Gray.c400),
      ),
      icono: LucideIcons.calendar,
      iconoColor: hoy.isEmpty ? Gray.c400 : const Color(0xFF2563EB),
      iconoFondo: hoy.isEmpty ? Gray.c100 : const Color(0xFFEFF6FF),
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_cargando)
            for (var i = 0; i < 2; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: RtcSpace.s3),
                child: RtcSkeletonPulse(
                  child: Container(
                    height: 96,
                    decoration: BoxDecoration(
                      color: Gray.c50,
                      borderRadius: RtcRadius.brXl,
                    ),
                  ),
                ),
              )
          else if (hoy.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: RtcSpace.s10),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Gray.c50,
                      borderRadius: RtcRadius.brXxl,
                    ),
                    child: const Icon(
                      LucideIcons.calendar,
                      size: 28,
                      color: Gray.c300,
                    ),
                  ),
                  const SizedBox(height: RtcSpace.s3),
                  Text(
                    'Sin reservas para hoy',
                    style: RtcType.sm.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Gray.c400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Las reservas del día aparecerán aquí',
                    style: RtcType.xs.copyWith(color: Gray.c300),
                  ),
                ],
              ),
            )
          else ...[
            for (final b in hoy)
              Padding(
                padding: const EdgeInsets.only(bottom: RtcSpace.s3),
                child: _tarjetaDeHoy(b),
              ),
            const SizedBox(height: 4),
            Container(height: 1, color: Gray.c50),
            const SizedBox(height: RtcSpace.s4),
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${hoy.length}',
                          style: RtcType.xs.copyWith(
                            fontWeight: RtcType.bold,
                            color: Gray.c700,
                          ),
                        ),
                        TextSpan(
                          text: ' reserva${hoy.length != 1 ? 's' : ''} hoy · ',
                        ),
                        TextSpan(
                          text: '${_fmtCop(confirmados)} confirmados',
                          style: RtcType.xs.copyWith(
                            color: Green.c600,
                            fontWeight: RtcType.semibold,
                          ),
                        ),
                      ],
                    ),
                    style: RtcType.xs.copyWith(color: Gray.c400),
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => rtcIrAlPanel('/dashboard/propetario/reservas'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ver todas',
                        style: RtcType.xs.copyWith(
                          color: Green.c600,
                          fontWeight: RtcType.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        LucideIcons.arrowRight,
                        size: 14,
                        color: Green.c600,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _tarjetaDeHoy(Booking b) {
    final (borde, fondo, colorHora, etiqueta) = _estilo(b.status);
    return Container(
      padding: const EdgeInsets.all(14), // p-3.5
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: RtcRadius.brXl,
        border: Border.all(color: borde, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${hora12(b.startTime)} – ${hora12(b.endTime)}',
                  style: RtcType.sm.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colorHora,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: RtcSpace.s2,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.70),
                  borderRadius: RtcRadius.brFull,
                ),
                child: Text(
                  '\$${formatCop(b.netoParaDueno)}',
                  style: RtcType.xs.copyWith(
                    fontWeight: RtcType.bold,
                    color: Gray.c500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(LucideIcons.user, size: 12, color: Gray.c400),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  b.guestName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RtcType.xs.copyWith(
                    fontWeight: RtcType.semibold,
                    color: Gray.c800,
                  ),
                ),
              ),
            ],
          ),
          if (b.courtName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              b.courtName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RtcType.xs.copyWith(fontSize: 11, color: Gray.c400),
            ),
          ],
          const SizedBox(height: RtcSpace.s2),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.60)),
          const SizedBox(height: RtcSpace.s2),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: RtcSpace.s2,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.70),
                  borderRadius: RtcRadius.brFull,
                ),
                child: Text(
                  etiqueta,
                  style: RtcType.xs.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Gray.c700,
                  ),
                ),
              ),
              const Spacer(),
              if (b.bookingCode.isNotEmpty)
                Text(
                  '#${b.bookingCode}',
                  style: RtcType.xs.copyWith(fontSize: 10, color: Gray.c300),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// El contenedor que repiten los tres bloques: titulo en versalitas,
  /// bajada gris y el cuadradito con el icono a la derecha.
  Widget _tarjeta({
    required String titulo,
    required Widget subtitulo,
    required IconData icono,
    required Color iconoColor,
    required Color iconoFondo,
    required Widget hijo,
  }) {
    return Container(
      padding: const EdgeInsets.all(RtcSpace.s5),
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
                    subtitulo,
                  ],
                ),
              ),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: iconoFondo,
                  borderRadius: RtcRadius.brLg,
                ),
                child: Icon(icono, size: 16, color: iconoColor),
              ),
            ],
          ),
          const SizedBox(height: RtcSpace.s5),
          hijo,
        ],
      ),
    );
  }
}

/// La grafica de barras de recharts: rejilla punteada horizontal, ejes sin
/// linea, barras con las esquinas de arriba redondeadas (`radius=[6,6,0,0]`) y
/// `maxBarSize=40`. La de hoy va en green-600 y el resto en green-200.
class _BarrasPainter extends CustomPainter {
  _BarrasPainter(this.datos);

  final List<({String dia, int reservas, int ingresos, bool hoy})> datos;

  @override
  void paint(Canvas canvas, Size size) {
    const margenIzq = 24.0; // el eje Y
    const margenAbajo = 20.0; // las etiquetas de dia
    final alto = size.height - margenAbajo;
    final ancho = size.width - margenIzq;

    final maximo = datos.fold<int>(
      0,
      (m, d) => d.reservas > m ? d.reservas : m,
    );
    // `allowDecimals={false}`: la escala sube de a enteros.
    final tope = maximo == 0 ? 1 : maximo;

    // CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0", solo horizontal.
    final rejilla = Paint()
      ..color = const Color(0xFFF0F0F0)
      ..strokeWidth = 1;
    for (var i = 0; i <= tope; i++) {
      final y = alto - (alto * i / tope);
      for (var x = margenIzq; x < size.width; x += 6) {
        canvas.drawLine(Offset(x, y), Offset(x + 3, y), rejilla);
      }
      _texto(canvas, '$i', Offset(0, y - 6), 10, const Color(0xFF9CA3AF));
    }

    final paso = ancho / datos.length;
    final anchoBarra = (paso * 0.6).clamp(0.0, 40.0); // maxBarSize
    for (var i = 0; i < datos.length; i++) {
      final d = datos[i];
      final centro = margenIzq + paso * i + paso / 2;
      final altura = alto * (d.reservas / tope);
      if (altura > 0) {
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTWH(
            centro - anchoBarra / 2,
            alto - altura,
            anchoBarra,
            altura,
          ),
          topLeft: const Radius.circular(6),
          topRight: const Radius.circular(6),
        );
        canvas.drawRRect(
          rect,
          Paint()..color = d.hoy ? Green.c600 : const Color(0xFFBBF7D0),
        );
      }
      _texto(
        canvas,
        d.dia,
        Offset(centro, alto + 4),
        11,
        const Color(0xFF9CA3AF),
        centrado: true,
      );
    }
  }

  void _texto(
    Canvas canvas,
    String texto,
    Offset donde,
    double tamano,
    Color color, {
    bool centrado = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: texto,
        style: TextStyle(
          fontSize: tamano,
          color: color,
          fontFamily: RtcType.fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      centrado ? Offset(donde.dx - tp.width / 2, donde.dy) : donde,
    );
  }

  @override
  bool shouldRepaint(_BarrasPainter old) => old.datos != datos;
}
