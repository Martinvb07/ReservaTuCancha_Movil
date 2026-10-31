import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/bookings_api.dart';
import '../api/rtc_api.dart';
import '../models/booking.dart';
import '../models/court.dart' show formatCop;
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../app/routes.dart';

/// Port de `Frontend/src/app/(public)/mis-reservas/page.tsx`.
///
/// Sin cuenta: se busca por email o por codigo de reserva. La pantalla tiene
/// cuatro estados y los cuatro estan portados — sin buscar, cargando, sin
/// resultados y con resultados.
class MisReservasScreen extends StatefulWidget {
  const MisReservasScreen({super.key});

  @override
  State<MisReservasScreen> createState() => _MisReservasScreenState();
}

class _MisReservasScreenState extends State<MisReservasScreen> {
  final _controller = TextEditingController();

  String _query = '';
  bool _searched = false;
  bool _loading = false;
  List<Booking> _bookings = const [];

  /// Mensaje del backend cuando la busqueda falla. La web se lo come en
  /// silencio y muestra "no encontramos": en el telefono, con la red que se
  /// cae, eso hace pensar que la reserva no existe.
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Con "@" busca por email; si no, por codigo de reserva.
  ///
  /// `GET /bookings/public` acepta `guestEmail` o `code` y se queda con el
  /// primero que venga (`bookings.controller.ts:18`). Es publico: no pide
  /// sesion, igual que en la web.
  Future<void> _search() async {
    final value = _controller.text.trim();
    if (value.isEmpty) return;

    setState(() {
      _query = value;
      _searched = true;
      _loading = true;
      _error = null;
    });

    final isEmail = value.contains('@');
    try {
      final found = await bookingsApi.search(
        guestEmail: isEmail ? value : null,
        code: isEmail ? null : value.replaceAll('#', ''),
      );
      if (!mounted) return;
      setState(() {
        _bookings = found;
        _loading = false;
      });
    } on RtcApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _bookings = const [];
        _error = e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(padding: EdgeInsets.zero, children: [_hero(), _results()]);
  }

  // ── HERO ─────────────────────────────────────────────────────────────
  Widget _hero() {
    return ClipRect(
      child: Container(
        color: Gray.c900,
        padding: const EdgeInsets.symmetric(
          horizontal: RtcSpace.s4,
          vertical: RtcSpace.s12 + RtcSpace.s4, // py-16
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // El circulo lima al 10%, corrido a la esquina inferior derecha.
            Positioned(
              right: -120,
              bottom: -160,
              child: Opacity(
                opacity: 0.10,
                child: Container(
                  width: 384, // w-96
                  height: 384,
                  decoration: const BoxDecoration(
                    color: Lime.c400,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            Column(
              children: [
                Text(
                  '✦ SIN NECESIDAD DE CUENTA',
                  textAlign: TextAlign.center,
                  style: RtcType.sm.copyWith(
                    color: Lime.c400,
                    fontWeight: RtcType.semibold,
                    letterSpacing: 1.4, // tracking-widest
                  ),
                ),
                const SizedBox(height: RtcSpace.s4),
                Text(
                  'MIS RESERVAS',
                  textAlign: TextAlign.center,
                  style: RtcType.xl4.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: RtcSpace.s4),
                Text(
                  'Ingresa tu email o el código de reserva para verla',
                  textAlign: TextAlign.center,
                  style: RtcType.sm.copyWith(color: Gray.c400),
                ),
                const SizedBox(height: RtcSpace.s6),
                _searchForm(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchForm() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            onSubmitted: (_) => _search(),
            style: RtcType.sm.copyWith(color: Colors.white),
            cursorColor: Lime.c400,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'tu@email.com o código #XXXXXXXX',
              hintStyle: RtcType.sm.copyWith(color: Gray.c500),
              prefixIcon: const Icon(
                LucideIcons.search,
                size: 16,
                color: Gray.c400,
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 44),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.10),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: RtcSpace.s4,
                vertical: RtcSpace.s3,
              ),
              border: OutlineInputBorder(
                borderRadius: RtcRadius.brXl,
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.20),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: RtcRadius.brXl,
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.20),
                ),
              ),
              // focus:ring-2 ring-lime-400
              focusedBorder: const OutlineInputBorder(
                borderRadius: RtcRadius.brXl,
                borderSide: BorderSide(color: Lime.c400, width: 2),
              ),
            ),
          ),
        ),
        const SizedBox(width: RtcSpace.s2),
        GestureDetector(
          onTap: _loading ? null : _search,
          child: Opacity(
            opacity: _loading ? 0.6 : 1,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: RtcSpace.s5,
                vertical: RtcSpace.s3 + 1,
              ),
              decoration: const BoxDecoration(
                color: Lime.c400,
                borderRadius: RtcRadius.brXl,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_loading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Gray.c900,
                      ),
                    )
                  else
                    const Icon(LucideIcons.search, size: 16, color: Gray.c900),
                  const SizedBox(width: RtcSpace.s2),
                  Text(
                    'Buscar',
                    style: RtcType.sm.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Gray.c900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── RESULTADOS ───────────────────────────────────────────────────────
  Widget _results() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s4,
        vertical: RtcSpace.s10,
      ),
      child: switch ((_searched, _loading, _bookings.isEmpty)) {
        (false, _, _) => _idleState(),
        (_, true, _) => _skeletons(),
        (true, false, true) => _emptyState(),
        _ => _list(),
      },
    );
  }

  /// Todavia no busco nada.
  Widget _idleState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RtcSpace.s12 + 16),
      child: Column(
        children: [
          const Icon(LucideIcons.calendarDays, size: 56, color: Gray.c200),
          const SizedBox(height: RtcSpace.s3),
          Text(
            'INGRESA TU EMAIL O CÓDIGO PARA VER TUS RESERVAS',
            textAlign: TextAlign.center,
            style: RtcType.sm.copyWith(
              fontWeight: FontWeight.w900,
              color: Gray.c300,
              letterSpacing: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _skeletons() {
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            height: 96,
            margin: const EdgeInsets.only(bottom: RtcSpace.s3),
            decoration: BoxDecoration(
              color: Gray.c100,
              borderRadius: RtcRadius.brXxl,
            ),
          ),
      ],
    );
  }

  Widget _emptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RtcSpace.s12 + 16),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Gray.c100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              _error == null ? LucideIcons.x : LucideIcons.wifiOff,
              size: 32,
              color: Gray.c300,
            ),
          ),
          const SizedBox(height: RtcSpace.s4),
          Text(
            _error == null ? 'NO ENCONTRAMOS RESERVAS' : 'NO PUDIMOS BUSCAR',
            style: RtcType.sm.copyWith(
              fontWeight: FontWeight.w900,
              color: Gray.c400,
            ),
          ),
          const SizedBox(height: RtcSpace.s4),
          if (_error != null)
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: RtcType.sm.copyWith(color: Gray.c400),
            )
          else
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'No hay reservas asociadas a '),
                  TextSpan(
                    text: _query,
                    style: const TextStyle(fontWeight: RtcType.bold),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              style: RtcType.sm.copyWith(color: Gray.c400),
            ),
          const SizedBox(height: RtcSpace.s4),
          GestureDetector(
            onTap: () => rtcNavigate('/empresas'),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: RtcSpace.s5,
                vertical: RtcSpace.s3,
              ),
              decoration: const BoxDecoration(
                color: Green.c600,
                borderRadius: RtcRadius.brXl,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Buscar canchas',
                    style: RtcType.sm.copyWith(
                      fontWeight: RtcType.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: RtcSpace.s2),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _list() {
    final n = _bookings.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text:
                    '$n reserva${n != 1 ? 's' : ''} '
                    'encontrada${n != 1 ? 's' : ''} para ',
              ),
              TextSpan(
                text: _query,
                style: const TextStyle(color: Gray.c900),
              ),
            ],
          ),
          style: RtcType.sm.copyWith(
            fontWeight: RtcType.semibold,
            color: Gray.c500,
          ),
        ),
        const SizedBox(height: RtcSpace.s4),
        for (final b in _bookings)
          Padding(
            padding: const EdgeInsets.only(bottom: RtcSpace.s4),
            child: _BookingCard(booking: b),
          ),
      ],
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({required this.booking});

  final Booking booking;

  static const _months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  /// `format(date, "dd 'de' MMM yyyy")`.
  String get _date =>
      '${booking.date.day.toString().padLeft(2, '0')} de '
      '${_months[booking.date.month - 1]} ${booking.date.year}';

  @override
  Widget build(BuildContext context) {
    final st = bookingStatusStyle(booking.status);

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
                    Wrap(
                      spacing: RtcSpace.s2,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          booking.courtName,
                          style: RtcType.sm.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Gray.c900,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: st.pillBackground,
                            borderRadius: RtcRadius.brFull,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: st.dot,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                st.label,
                                style: RtcType.xs.copyWith(
                                  fontSize: 10,
                                  fontWeight: RtcType.bold,
                                  color: st.pillForeground,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (booking.city.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            LucideIcons.mapPin,
                            size: 12,
                            color: Gray.c400,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            booking.city,
                            style: RtcType.xs.copyWith(color: Gray.c400),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: RtcSpace.s3),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'CÓDIGO',
                    style: RtcType.xs.copyWith(
                      fontSize: 10,
                      fontWeight: RtcType.bold,
                      color: Gray.c400,
                      letterSpacing: 1.4,
                    ),
                  ),
                  Text(
                    '#${booking.bookingCode}',
                    style: RtcType.sm.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Lime.c600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: RtcSpace.s4),

          Container(
            padding: const EdgeInsets.all(RtcSpace.s4),
            decoration: BoxDecoration(
              color: Gray.c50,
              borderRadius: RtcRadius.brXl,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _IconLine(icon: LucideIcons.calendarDays, text: _date),
                ),
                const SizedBox(width: RtcSpace.s3),
                Expanded(
                  child: _IconLine(
                    icon: LucideIcons.clock,
                    text: '${booking.startTime} – ${booking.endTime}',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: RtcSpace.s4),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '\$${formatCop(booking.totalPrice)} COP',
                style: RtcType.lg.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Green.c700,
                ),
              ),
              // Ya no se cancela: si el jugador no puede ir, mueve el horario.
              if (booking.status != 'completed' && booking.cancelToken != null)
                Text(
                  'Cambiar horario',
                  style: RtcType.xs.copyWith(
                    fontWeight: RtcType.semibold,
                    color: Green.c700,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Green.c600),
        const SizedBox(width: RtcSpace.s2),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: RtcType.sm.copyWith(color: Gray.c600),
          ),
        ),
      ],
    );
  }
}
