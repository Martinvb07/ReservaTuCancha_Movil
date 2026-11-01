import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/bookings_api.dart';
import '../api/rtc_api.dart';
import '../app/routes.dart';
import '../models/booking.dart';
import '../models/court.dart' show formatCop;
import '../models/fechas.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/motion/rtc_motion.dart';
import '../widgets/acciones_reserva.dart';
import '../widgets/motion/rtc_pressable.dart';

/// Port de `Frontend/src/app/(public)/reservas/confirmacion/page.tsx`, con una
/// diferencia deliberada.
///
/// La web da el pago por bueno leyendo la URL: ePayco redirige ahi pase lo que
/// pase, asi que una tarjeta rechazada tambien ve "¡Todo listo!". La app
/// pregunta de verdad. La confirmacion de ePayco pone la reserva en
/// `confirmed` cuando aprueban y la BORRA cuando rechazan
/// (`epayco-confirmation.controller.ts`), asi que hay tres respuestas
/// posibles:
///
///   confirmed        -> pagado
///   404 / no existe  -> rechazado
///   sigue pending    -> el webhook todavia no llego, se vuelve a preguntar
class ConfirmacionScreen extends StatefulWidget {
  const ConfirmacionScreen({super.key, required this.bookingId});

  final String bookingId;

  @override
  State<ConfirmacionScreen> createState() => _ConfirmacionScreenState();
}

/// Cada cuanto se le pregunta al backend.
const _intervalo = Duration(seconds: 2);

/// Cuanto se insiste antes de decir "lo estamos verificando". La
/// confirmacion de ePayco suele llegar en segundos; si a los 30 no llego, no vale seguir
/// mirando una pantalla girando.
const _limite = Duration(seconds: 30);

enum _Estado { verificando, pagado, rechazado, demorado }

class _ConfirmacionScreenState extends State<ConfirmacionScreen>
    with WidgetsBindingObserver {
  _Estado _estado = _Estado.verificando;
  Booking? _booking;
  Timer? _timer;
  DateTime? _desde;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _arrancar();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver del navegador se consulta enseguida, sin esperar al proximo
    // tic: es el momento en el que casi siempre ya esta resuelto.
    if (state == AppLifecycleState.resumed && _estado == _Estado.verificando) {
      _consultar();
    }
  }

  void _arrancar() {
    _desde = DateTime.now();
    setState(() => _estado = _Estado.verificando);
    _timer?.cancel();
    _timer = Timer.periodic(_intervalo, (_) => _consultar());
    _consultar();
  }

  Future<void> _consultar() async {
    if (!mounted || _estado != _Estado.verificando) return;
    try {
      final booking = await bookingsApi.getById(widget.bookingId);
      if (!mounted) return;
      if (booking.status == 'confirmed') {
        _timer?.cancel();
        setState(() {
          _booking = booking;
          _estado = _Estado.pagado;
        });
        return;
      }
      // Sigue pendiente: el webhook no llego todavia.
      setState(() => _booking = booking);
      _vencido();
    } on RtcApiException catch (e) {
      if (!mounted) return;
      if (e.notFound) {
        _timer?.cancel();
        setState(() => _estado = _Estado.rechazado);
        return;
      }
      // Un fallo de red no significa nada sobre el pago: se sigue intentando
      // hasta que se acabe el tiempo.
      _vencido();
    }
  }

  void _vencido() {
    if (_desde == null) return;
    if (DateTime.now().difference(_desde!) < _limite) return;
    _timer?.cancel();
    setState(() => _estado = _Estado.demorado);
  }

  @override
  Widget build(BuildContext context) {
    // `min-h-screen bg-gray-900` con todo centrado.
    return ColoredBox(
      color: Gray.c900,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: RtcSpace.s4,
              vertical: RtcSpace.s12,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 384), // max-w-sm
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: switch (_estado) {
                  _Estado.verificando => _verificando(),
                  _Estado.pagado => _pagado(),
                  _Estado.rechazado => _rechazado(),
                  _Estado.demorado => _demorado(),
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── VERIFICANDO ──────────────────────────────────────────────────────
  List<Widget> _verificando() => [
    const SizedBox(
      width: 80,
      height: 80,
      child: CircularProgressIndicator(color: Lime.c400, strokeWidth: 3),
    ),
    const SizedBox(height: RtcSpace.s6),
    _titulillo('Confirmando tu pago', Lime.c400),
    const SizedBox(height: RtcSpace.s2),
    _titulo('UN MOMENTO'),
    const SizedBox(height: RtcSpace.s2),
    _bajada(
      'Estamos esperando la respuesta de ePayco. Si ya pagaste, no cierres '
      'la app: esto se resuelve solo en unos segundos.',
    ),
  ];

  // ── PAGADO ───────────────────────────────────────────────────────────
  List<Widget> _pagado() => [
    RtcCheckIn(child: _circulo(LucideIcons.circleCheck, Lime.c400)),
    const SizedBox(height: RtcSpace.s6),
    _titulillo('PAGO PROCESADO', Lime.c400),
    const SizedBox(height: RtcSpace.s2),
    _titulo('¡TODO LISTO!'),
    const SizedBox(height: RtcSpace.s2),
    _bajada(
      'Tu pago fue recibido. Te enviamos los detalles al correo con el link '
      'para cambiar de horario si lo necesitas.',
    ),
    if (_booking != null) ...[
      const SizedBox(height: RtcSpace.s6),
      _detalle(_booking!),
      const SizedBox(height: RtcSpace.s3),
      AccionesReserva(booking: _booking!),
    ],
    const SizedBox(height: RtcSpace.s6),
    _nota('Revisa tu bandeja de entrada (y carpeta de spam por si acaso).'),
    const SizedBox(height: RtcSpace.s6),
    _boton('Ver mis reservas', () => rtcNavigate('/mis-reservas')),
    const SizedBox(height: RtcSpace.s3),
    _botonSecundario('Volver al inicio', () => rtcNavigate('/')),
  ];

  // ── RECHAZADO ────────────────────────────────────────────────────────
  List<Widget> _rechazado() => [
    _circulo(LucideIcons.circleX, Red.c400),
    const SizedBox(height: RtcSpace.s6),
    _titulillo('PAGO NO APROBADO', Red.c400),
    const SizedBox(height: RtcSpace.s2),
    _titulo('NO SE PUDO COBRAR'),
    const SizedBox(height: RtcSpace.s2),
    _bajada(
      'El banco rechazó el pago, así que liberamos el horario para que otra '
      'persona pueda tomarlo. No se te cobró nada.',
    ),
    const SizedBox(height: RtcSpace.s6),
    _boton('Intentar de nuevo', () => rtcNavigate('/empresas')),
    const SizedBox(height: RtcSpace.s3),
    _botonSecundario('Volver al inicio', () => rtcNavigate('/')),
  ];

  // ── DEMORADO ─────────────────────────────────────────────────────────
  List<Widget> _demorado() => [
    _circulo(LucideIcons.clock, Amber.c400), // amber-400
    const SizedBox(height: RtcSpace.s6),
    _titulillo('VERIFICANDO', Amber.c400),
    const SizedBox(height: RtcSpace.s2),
    _titulo('ESTAMOS CONFIRMANDO'),
    const SizedBox(height: RtcSpace.s2),
    _bajada(
      'El pago está tardando más de lo normal en confirmarse. Si salió bien, '
      'te llega el correo con los detalles. También podés buscar tu reserva '
      'con tu email.',
    ),
    const SizedBox(height: RtcSpace.s6),
    _boton('Reintentar', _arrancar),
    const SizedBox(height: RtcSpace.s3),
    _botonSecundario('Buscar mi reserva', () => rtcNavigate('/mis-reservas')),
  ];

  // ── PIEZAS ───────────────────────────────────────────────────────────

  /// `w-20 h-20 rounded-full` con la sombra tenida del mismo color al 30%.
  Widget _circulo(IconData icon, Color color) => Container(
    width: 80,
    height: 80,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: color.withValues(alpha: 0.30),
          blurRadius: 25,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Icon(icon, size: 40, color: Gray.c900),
  );

  Widget _titulillo(String texto, Color color) => Text(
    texto.toUpperCase(),
    textAlign: TextAlign.center,
    style: RtcType.xs.copyWith(
      color: color,
      fontWeight: RtcType.semibold,
      letterSpacing: 1.6, // tracking-widest
    ),
  );

  Widget _titulo(String texto) => Text(
    texto,
    textAlign: TextAlign.center,
    style: RtcType.xl3.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w900,
    ),
  );

  Widget _bajada(String texto) => Text(
    texto,
    textAlign: TextAlign.center,
    style: RtcType.sm.copyWith(color: Gray.c500),
  );

  /// El recuadro con el codigo, que la web solo mostraba para efectivo. Aca
  /// sirve igual: es lo que hay que dar al llegar a la cancha.
  Widget _detalle(Booking b) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: RtcSpace.s6,
      vertical: RtcSpace.s5,
    ),
    decoration: BoxDecoration(
      color: Gray.c800,
      borderRadius: RtcRadius.brXxl,
      border: Border.all(color: Lime.c400.withValues(alpha: 0.30)),
    ),
    child: Column(
      children: [
        Text(
          'CÓDIGO DE RESERVA',
          style: RtcType.xs.copyWith(
            color: Gray.c500,
            fontWeight: RtcType.bold,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: RtcSpace.s3),
        Text(
          '#${b.bookingCode}',
          style: RtcType.xl3.copyWith(
            color: Lime.c400,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: RtcSpace.s3),
        Container(height: 1, color: Gray.c700),
        const SizedBox(height: RtcSpace.s3),
        Text(
          '${b.courtName} · ${fechaLargaCapitalizada(b.date)}',
          textAlign: TextAlign.center,
          style: RtcType.xs.copyWith(color: Gray.c500),
        ),
        Text(
          '${hora12(b.startTime)} – ${hora12(b.endTime)} · '
          '\$${formatCop(b.totalPrice)}',
          textAlign: TextAlign.center,
          style: RtcType.xs.copyWith(color: Gray.c500),
        ),
      ],
    ),
  );

  Widget _nota(String texto) => Container(
    padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s5, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: RtcRadius.brXxl,
      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
    ),
    child: Text(
      texto,
      textAlign: TextAlign.center,
      style: RtcType.xs.copyWith(color: Gray.c500),
    ),
  );

  Widget _boton(String label, VoidCallback onTap) => RtcPressable(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Lime.c400,
        borderRadius: RtcRadius.brXxl,
      ),
      child: Text(
        label,
        style: RtcType.base.copyWith(
          color: Gray.c900,
          fontWeight: FontWeight.w900,
        ),
      ),
    ),
  );

  Widget _botonSecundario(String label, VoidCallback onTap) => RtcPressable(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: RtcRadius.brXxl,
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        style: RtcType.base.copyWith(
          color: Colors.white,
          fontWeight: RtcType.semibold,
        ),
      ),
    ),
  );
}
