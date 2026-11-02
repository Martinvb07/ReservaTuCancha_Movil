import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/bookings_api.dart';
import '../api/courts_api.dart';
import '../api/rtc_api.dart';
import '../app/routes.dart';
import '../booking/pago.dart';
import '../models/court.dart';
import '../models/fechas.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'medios_pago.dart';
import 'motion/rtc_motion.dart';
import '../data/preferencias.dart';
import '../data/push.dart';
import 'rtc_toast.dart';
import 'motion/rtc_pressable.dart';

/// Port de `Frontend/src/components/bookings/BookingForm.tsx`.
///
/// Dos pasos: elegir cuando y luego los datos + pago. Toda la aritmetica de
/// franjas esta copiada del original, no reinventada: los cortes de
/// `generateTimeSlots`, el limite de 14 fechas, la seleccion contigua y el
/// calculo del total.
/// Lo que la barra fija de la ficha necesita saber del formulario: en qué
/// paso va, si ya hay horario elegido y cuánto suma, para mostrar el botón de
/// la acción que toca ("Reservar", "Continuar" o "Pagar") y ejecutarla.
class BookingFormController extends ChangeNotifier {
  String _paso = 'when';
  bool _listo = false;
  bool _procesando = false;
  int _total = 0;

  /// 'when' (elegir día y hora) o 'checkout' (datos y pago).
  String get paso => _paso;

  /// Ya hay día y horario elegidos.
  bool get listo => _listo;
  bool get procesando => _procesando;
  int get total => _total;

  VoidCallback? _continuar;
  Future<bool> Function()? _pagar;

  /// Pasa al paso de datos y pago.
  void continuar() => _continuar?.call();

  /// Valida y abre el pago. false si faltan datos (el formulario los marca).
  Future<bool> pagar() async => await _pagar?.call() ?? false;

  void _actualizar({
    required String paso,
    required bool listo,
    required bool procesando,
    required int total,
  }) {
    if (paso == _paso &&
        listo == _listo &&
        procesando == _procesando &&
        total == _total) {
      return;
    }
    _paso = paso;
    _listo = listo;
    _procesando = procesando;
    _total = total;
    notifyListeners();
  }
}

class BookingForm extends StatefulWidget {
  const BookingForm({
    this.controller,
    super.key,
    required this.courtId,
    required this.courtName,
    required this.pricePerHour,
    required this.availability,
    this.initialDate,
    this.initialStart,
  });

  final String courtId;
  final String courtName;
  final int pricePerHour;
  final List<AvailabilitySlot> availability;

  /// Preseleccion desde el buscador (`yyyy-MM-dd` y `HH:mm`).
  final String? initialDate;
  final String? initialStart;

  /// Para la barra fija de la ficha (ver [BookingFormController]).
  final BookingFormController? controller;

  @override
  State<BookingForm> createState() => _BookingFormState();
}

/// `PER_PAGE`.
const _perPage = 8;

class _BookingFormState extends State<BookingForm> {
  // Salen llenos con lo de la ultima reserva hecha desde este telefono.
  final _nombre = TextEditingController(
    text: Preferencias.instance.jugador.nombre,
  );
  final _email = TextEditingController(
    text: Preferencias.instance.jugador.email,
  );
  final _telefono = TextEditingController(
    text: Preferencias.instance.jugador.telefono,
  );
  final _notas = TextEditingController();

  /// 'when' | 'checkout'.
  String _step = 'when';

  DateTime? _selectedDate;
  List<String> _selectedSlots = const [];
  int _dateOffset = 0;
  bool _processing = false;

  PagosConfig? _pagos;
  List<BlockedSlot> _booked = const [];
  List<BlockedSlot> _blocked = const [];

  /// Para descartar respuestas de una fecha que ya no es la elegida.
  int _slotsRequest = 0;

  final _errores = <String, String>{};
  String? _errorGeneral;

  bool _aplicadaFecha = false;
  bool _aplicadaHora = false;

  @override
  void initState() {
    super.initState();
    // La barra fija de la ficha ejecuta las mismas acciones que los botones.
    widget.controller
      ?.._continuar = () {
        if (_selectedDate != null && _selectedSlots.isNotEmpty) {
          setState(() => _step = 'checkout');
        }
      }
      .._pagar = _confirmarYPagar;
    _cargarPagos();
    _aplicarPreseleccion();
  }

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _telefono.dispose();
    _notas.dispose();
    super.dispose();
  }

  Future<void> _cargarPagos() async {
    try {
      final config = await courtsApi.pagosConfig(widget.courtId);
      if (!mounted) return;
      setState(() => _pagos = config);
    } on RtcApiException {
      // La web deja la config en undefined y muestra el metodo igual: solo
      // esconde el pago cuando el backend dice explicitamente que no.
    }
  }

  // ── FECHAS Y FRANJAS ─────────────────────────────────────────────────

  /// `getAvailableDates`: mira 30 dias hacia adelante y corta en 14.
  List<DateTime> get _availableDates {
    final dias = widget.availability.map((s) => s.dayOfWeek).toSet();
    final hoy = DateTime.now();
    final base = DateTime(hoy.year, hoy.month, hoy.day);
    final out = <DateTime>[];
    for (var i = 0; i < 30; i++) {
      // `addHours(today, i * 24)`, no addDays.
      final d = base.add(Duration(hours: i * 24));
      if (dias.contains(d.weekday % 7)) out.add(d);
      if (out.length >= 14) break;
    }
    return out;
  }

  AvailabilitySlot? get _slotDelDia {
    final d = _selectedDate;
    if (d == null) return null;
    for (final s in widget.availability) {
      if (s.dayOfWeek == d.weekday % 7) return s;
    }
    return null;
  }

  /// `generateTimeSlots(openTime, closeTime, slotMinutes)`.
  List<String> get _timeSlots {
    final slot = _slotDelDia;
    if (slot == null) return const [];

    final open = slot.openTime.split(':').map(int.parse).toList();
    // "00:00" de cierre significa medianoche del dia siguiente, no las 0:00
    // de hoy: si no, la cancha que cierra a las 12 no mostraria ninguna hora.
    final cierra = slot.closeTime == '00:00'
        ? 24 * 60
        : slot.closeTime.split(':').map(int.parse).reduce((h, m) => h * 60 + m);

    final out = <String>[];
    var actual = open[0] * 60 + open[1];
    while (actual + slot.slotDurationMinutes <= cierra) {
      out.add(
        '${(actual ~/ 60).toString().padLeft(2, '0')}:'
        '${(actual % 60).toString().padLeft(2, '0')}',
      );
      actual += slot.slotDurationMinutes;
    }
    return out;
  }

  int get _slotDuration => _slotDelDia?.slotDurationMinutes ?? 60;

  String get _endTime => _selectedSlots.isEmpty
      ? ''
      : sumarMinutos(
          _selectedSlots.first,
          _slotDuration * _selectedSlots.length,
        );

  /// `Math.round(pricePerHour * slotDurationH * (selectedSlots.length || 1))`.
  int get _precioCancha {
    final horas = _slotDuration / 60;
    final n = _selectedSlots.isEmpty ? 1 : _selectedSlots.length;
    return (widget.pricePerHour * horas * n).round();
  }

  int get _tarifaServicio =>
      _pagos?.tarifaServicio ?? PagosConfig.tarifaPorDefecto;

  /// Lo que se ve antes de pagar. El backend arma el cobro real con el precio
  /// de la cancha: lo que se manda en `totalPrice` no decide nada.
  int get _totalFecha => _precioCancha + _tarifaServicio;

  int get _totalPrice => _totalFecha;

  /// `expandUnavailable`: una franja ocupada tapa todas las horas que abarca.
  Set<String> _expandir(List<BlockedSlot> slots) {
    final out = <String>{};
    for (final s in slots) {
      for (final t in _timeSlots) {
        if (t.compareTo(s.startTime) >= 0 && t.compareTo(s.endTime) < 0) {
          out.add(t);
        }
      }
    }
    return out;
  }

  bool _esPasada(String slot) {
    final ahora = ahoraEnBogota();
    final hoyStr = fechaIso(ahora);
    final elegida = _selectedDate == null ? '' : fechaIso(_selectedDate!);
    if (elegida.isNotEmpty && elegida.compareTo(hoyStr) < 0) return true;
    if (elegida != hoyStr) return false;
    final parts = slot.split(':').map(int.parse).toList();
    return parts[0] * 60 + parts[1] <= ahora.hour * 60 + ahora.minute;
  }

  bool _noDisponible(String slot) =>
      _expandir(_booked).contains(slot) ||
      _expandir(_blocked).contains(slot) ||
      _esPasada(slot);

  /// Reservada por otro (no bloqueada ni pasada): se puede pedir aviso.
  bool _admiteEspera(String slot) =>
      _expandir(_booked).contains(slot) &&
      !_expandir(_blocked).contains(slot) &&
      !_esPasada(slot);

  /// Lista de espera: avisar por correo (y push) si el turno se libera.
  Future<void> _pedirAviso(String slot) async {
    HapticFeedback.selectionClick();
    final email = TextEditingController(text: _email.text.trim());
    final fin = sumarMinutos(slot, _slotDuration);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      // Las pantallas están pintadas en claro; sin esto, con el teléfono en
      // modo oscuro la hoja salía oscura y el texto gris oscuro no se leía.
      backgroundColor: Superficie.tarjeta,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          RtcSpace.s6,
          0,
          RtcSpace.s6,
          MediaQuery.of(ctx).viewInsets.bottom + RtcSpace.s6,
        ),
        child: _AvisoTurno(
          titulo: 'Avísame si se libera el de las ${hora12(slot)}',
          email: email,
          onEnviar: () async {
            final correo = email.text.trim();
            if (!RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$').hasMatch(correo)) {
              rtcToast(
                ctx,
                'Escribe un correo válido',
                tipo: RtcToastTipo.error,
              );
              return;
            }
            try {
              await bookingsApi.listaEspera(
                courtId: widget.courtId,
                date: fechaIso(_selectedDate!),
                startTime: slot,
                endTime: fin,
                email: correo,
                nombre: _nombre.text,
                pushToken: await PushNotificaciones.instance.pedirPermiso(),
              );
              if (ctx.mounted) Navigator.of(ctx).pop(true);
            } on RtcApiException catch (e) {
              if (ctx.mounted) {
                rtcToast(ctx, e.message, tipo: RtcToastTipo.error);
              }
            }
          },
        ),
      ),
    );
    email.dispose();
    if (ok == true && mounted) {
      rtcToast(context, 'Listo: te avisamos si ese turno se libera');
    }
  }

  Future<void> _cargarFranjas() async {
    final date = _selectedDate;
    if (date == null) return;
    final token = ++_slotsRequest;
    final iso = fechaIso(date);
    try {
      final results = await Future.wait([
        bookingsApi.takenSlots(widget.courtId, iso),
        courtsApi.blockedSlots(widget.courtId, iso),
      ]);
      if (!mounted || token != _slotsRequest) return;
      setState(() {
        _booked = results[0];
        _blocked = results[1];
        // Si por carrera quedo elegida una franja que ya no esta libre, se
        // suelta — el mismo useEffect de la web.
        _selectedSlots = _selectedSlots
            .where((s) => !_noDisponible(s))
            .toList();
      });
      _aplicarHoraInicial();
    } on RtcApiException {
      if (!mounted || token != _slotsRequest) return;
      // Sin la lista de ocupados es preferible no dejar reservar a ciegas.
      setState(() => _errorGeneral = 'No pudimos cargar los horarios ocupados');
    }
  }

  void _aplicarPreseleccion() {
    if (_aplicadaFecha) return;
    _aplicadaFecha = true;
    final inicial = widget.initialDate;
    if (inicial == null) return;

    final fechas = _availableDates;
    final idx = fechas.indexWhere((d) => fechaIso(d) == inicial);
    if (idx < 0) return;
    _selectedDate = fechas[idx];
    _dateOffset = (idx ~/ _perPage) * _perPage;
    _cargarFranjas();
  }

  void _aplicarHoraInicial() {
    if (_aplicadaHora) return;
    final inicial = widget.initialStart;
    if (inicial == null || _selectedDate == null || _timeSlots.isEmpty) return;
    _aplicadaHora = true;
    if (_timeSlots.contains(inicial) && !_noDisponible(inicial)) {
      setState(() => _selectedSlots = [inicial]);
    }
  }

  /// `toggleSlot`: tocar una elegida recorta hasta antes de ella; la siguiente
  /// extiende; cualquier otra empieza de cero.
  void _toggleSlot(String slot) {
    if (_noDisponible(slot)) return;
    setState(() {
      if (_selectedSlots.contains(slot)) {
        _selectedSlots = _selectedSlots.sublist(
          0,
          _selectedSlots.indexOf(slot),
        );
        return;
      }
      if (_selectedSlots.isEmpty) {
        _selectedSlots = [slot];
        return;
      }
      final idx = _timeSlots.indexOf(slot);
      final ultimo = _timeSlots.indexOf(_selectedSlots.last);
      _selectedSlots = idx == ultimo + 1 ? [..._selectedSlots, slot] : [slot];
    });
  }

  void _elegirFecha(DateTime d) {
    setState(() {
      _selectedDate = d;
      _selectedSlots = const [];
      _booked = const [];
      _blocked = const [];
      _errorGeneral = null;
    });
    _cargarFranjas();
  }

  // ── ENVIO ────────────────────────────────────────────────────────────

  /// El esquema de zod del formulario.
  bool _validar() {
    final errores = <String, String>{};
    if (_nombre.text.trim().length < 2) {
      errores['guestName'] = 'Nombre muy corto';
    }
    if (!RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$').hasMatch(_email.text.trim())) {
      errores['guestEmail'] = 'Email inválido';
    }
    if (_telefono.text.trim().length < 7) {
      errores['guestPhone'] = 'Teléfono inválido';
    }
    setState(() {
      _errores
        ..clear()
        ..addAll(errores);
    });
    return errores.isEmpty;
  }

  Future<bool> _confirmarYPagar() async {
    if (_processing) return true;
    if (!_validar()) return false;
    HapticFeedback.mediumImpact();
    setState(() {
      _processing = true;
      _errorGeneral = null;
    });

    try {
      final booking = await bookingsApi.create(
        courtId: widget.courtId,
        guestName: _nombre.text.trim(),
        guestEmail: _email.text.trim(),
        guestPhone: _telefono.text.trim(),
        date: fechaIso(_selectedDate!),
        startTime: _selectedSlots.first,
        endTime: _endTime,
        totalPrice: _totalPrice,
        notes: _notas.text,
        // Para avisar en este teléfono la confirmación y el recordatorio.
        pushToken: await PushNotificaciones.instance.pedirPermiso(),
      );

      final checkout = await bookingsApi.initPayment(
        booking.id,
        redirectUrlDePago(booking.id),
      );

      if (!mounted) return true;
      // La pantalla de confirmacion se abre ANTES que el navegador: cuando la
      // persona vuelve, la app ya estuvo consultando si el pago entro.
      // Para la proxima: el formulario ya sale lleno y Mis reservas las
      // muestra sin buscar.
      Preferencias.instance.guardarJugador(
        DatosJugador(
          nombre: _nombre.text.trim(),
          email: _email.text.trim(),
          telefono: _telefono.text.trim(),
        ),
      );
      rtcAbrirConfirmacion(booking.id);
      await abrirCheckout(checkout);
    } on RtcApiException catch (e) {
      if (!mounted) return true;
      setState(() {
        _errorGeneral = e.message;
        _processing = false;
      });
    }
    return true;
  }

  // ── PINTADO ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // La barra de la ficha se entera después del cuadro, no durante.
    final c = widget.controller;
    if (c != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        c._actualizar(
          paso: _step,
          listo: _selectedDate != null && _selectedSlots.isNotEmpty,
          procesando: _processing,
          total: _totalPrice,
        );
      });
    }
    // Va sobre el fondo gris de la ficha: la tarjeta blanca se separa sola,
    // sin borde ni sombra.
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Superficie.tarjeta,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _encabezado(),
          Padding(
            padding: const EdgeInsets.all(RtcSpace.s6),
            child: _step == 'when' ? _pasoCuando() : _pasoCheckout(),
          ),
        ],
      ),
    );
  }

  /// Precio por hora a la izquierda y "Paso N de 2" a la derecha.
  Widget _encabezado() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s6,
        vertical: RtcSpace.s5,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Gray.c100)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '\$${formatCop(widget.pricePerHour)}',
            style: RtcType.xl2.copyWith(
              fontWeight: RtcType.bold,
              color: Gray.c900,
            ),
          ),
          Text(' COP / hora', style: RtcType.sm.copyWith(color: Gray.c500)),
          const Spacer(),
          Text(
            _step == 'when' ? 'Paso 1 de 2' : 'Paso 2 de 2',
            style: RtcType.xs.copyWith(
              color: Gray.c500,
              fontWeight: RtcType.medium,
            ),
          ),
        ],
      ),
    );
  }

  // ── PASO 1 ───────────────────────────────────────────────────────────
  Widget _pasoCuando() {
    final listo = _selectedDate != null && _selectedSlots.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _etiqueta(LucideIcons.calendarDays, 'Elige un día'),
        const SizedBox(height: 6),
        if (widget.availability.isEmpty) _sinDias() else _selectorFechas(),
        if (_selectedDate != null) ...[
          const SizedBox(height: RtcSpace.s5),
          _etiqueta(
            LucideIcons.clock,
            'Horarios',
            extra: '($_slotDuration min)',
          ),
          const SizedBox(height: 6),
          _grillaHorarios(),
        ],
        if (listo) ...[const SizedBox(height: RtcSpace.s5), _resumenVivo()],
        if (_errorGeneral != null) ...[
          const SizedBox(height: RtcSpace.s3),
          Text(_errorGeneral!, style: RtcType.xs.copyWith(color: Red.c500)),
        ],
        const SizedBox(height: RtcSpace.s5),
        _botonPrincipal(
          label: 'Continuar',
          icon: LucideIcons.chevronRight,
          enabled: listo,
          // `.rtc-ready`: el boton "respira" cuando ya se puede continuar.
          pulsing: listo,
          onTap: () => setState(() => _step = 'checkout'),
        ),
        const SizedBox(height: RtcSpace.s3),
        Text(
          'Sin registro · Puedes cambiar de horario hasta 24h antes',
          textAlign: TextAlign.center,
          style: RtcType.xs.copyWith(color: Gray.c500),
        ),
      ],
    );
  }

  Widget _sinDias() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: RtcSpace.s6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: RtcRadius.brXxl,
        border: Border.all(color: Gray.c200, width: 2),
      ),
      child: Text(
        'Esta cancha no tiene días configurados aún',
        style: RtcType.sm.copyWith(color: Gray.c500),
      ),
    );
  }

  Widget _selectorFechas() {
    final fechas = _availableDates;
    final visibles = fechas.skip(_dateOffset).take(_perPage).toList();
    final hoy = fechaIso(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _flecha(
              LucideIcons.chevronLeft,
              _dateOffset > 0,
              () => setState(
                () => _dateOffset = (_dateOffset - _perPage).clamp(0, 999),
              ),
            ),
            Expanded(
              child: Text(
                visibles.isEmpty
                    ? ''
                    : '${diaMesCorto(visibles.first)} – '
                          '${diaMesCorto(visibles.last)}',
                textAlign: TextAlign.center,
                style: RtcType.xs.copyWith(
                  color: Gray.c500,
                  fontWeight: RtcType.medium,
                ),
              ),
            ),
            _flecha(
              LucideIcons.chevronRight,
              _dateOffset + _perPage < fechas.length,
              () => setState(() => _dateOffset += _perPage),
            ),
          ],
        ),
        const SizedBox(height: RtcSpace.s2),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: visibles.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 6, // gap-1.5
            mainAxisSpacing: 6,
            // Las celdas llevan dia, numero, mes y a veces "Hoy".
            mainAxisExtent: 84,
          ),
          itemBuilder: (context, i) {
            final d = visibles[i];
            final elegida =
                _selectedDate != null &&
                fechaIso(d) == fechaIso(_selectedDate!);
            return RtcPressable(
              behavior: HitTestBehavior.opaque,
              onTap: () => _elegirFecha(d),
              child: RtcPick(
                trigger: elegida,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: elegida ? Green.c50 : null,
                    borderRadius: RtcRadius.brXl,
                    border: Border.all(color: elegida ? Green.c600 : Gray.c200),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        diasCortos[d.weekday % 7].toUpperCase(),
                        style: RtcType.xs.copyWith(
                          fontSize: 11,
                          color: Gray.c500,
                        ),
                      ),
                      Text(
                        '${d.day}',
                        style: RtcType.base.copyWith(
                          fontWeight: RtcType.bold,
                          color: elegida ? Green.c700 : Gray.c900,
                        ),
                      ),
                      Text(
                        mesesCortos[d.month - 1],
                        style: RtcType.xs.copyWith(
                          fontSize: 11,
                          color: Gray.c500,
                        ),
                      ),
                      if (fechaIso(d) == hoy)
                        Text(
                          'Hoy',
                          style: RtcType.xs.copyWith(
                            fontSize: 11,
                            color: Green.c600,
                            fontWeight: RtcType.semibold,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _flecha(IconData icon, bool enabled, VoidCallback onTap) {
    return Opacity(
      opacity: enabled ? 1 : 0.3,
      child: RtcPressable(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Gray.c200),
          ),
          child: Icon(icon, size: 14, color: Gray.c700),
        ),
      ),
    );
  }

  Widget _grillaHorarios() {
    final slots = _timeSlots;
    if (slots.isEmpty) {
      return RtcSkeletonPulse(
        child: Container(
          height: 96,
          decoration: BoxDecoration(
            color: Gray.c100,
            borderRadius: RtcRadius.brXl,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: slots.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: RtcSpace.s2,
            mainAxisSpacing: RtcSpace.s2,
            mainAxisExtent: 40,
          ),
          itemBuilder: (context, i) {
            final slot = slots[i];
            final elegida = _selectedSlots.contains(slot);
            final ocupada = _noDisponible(slot);
            final esperable = _admiteEspera(slot);
            return RtcPressable(
              behavior: HitTestBehavior.opaque,
              onTap: esperable
                  ? () => _pedirAviso(slot)
                  : ocupada
                  ? null
                  : () => _toggleSlot(slot),
              child: RtcPick(
                trigger: elegida,
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: elegida
                        ? Green.c600
                        : ocupada
                        ? Gray.c50
                        : null,
                    borderRadius: RtcRadius.brXl,
                    border: Border.all(
                      color: elegida
                          ? Green.c600
                          : ocupada
                          ? Gray.c100
                          : Gray.c200,
                    ),
                  ),
                  child: Text(
                    hora12(slot),
                    style: RtcType.xs.copyWith(
                      fontWeight: RtcType.semibold,
                      color: elegida
                          ? Colors.white
                          : ocupada
                          ? Gray.c300
                          : Gray.c700,
                      decoration: ocupada ? TextDecoration.lineThrough : null,
                      decorationColor: Gray.c300,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10), // mt-2.5
        Row(
          children: [
            _leyenda(Green.c600, Green.c600, 'Elegido'),
            const SizedBox(width: RtcSpace.s4),
            _leyenda(null, Gray.c200, 'Libre'),
            const SizedBox(width: RtcSpace.s4),
            _leyenda(Gray.c100, Gray.c100, 'Ocupado'),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Toca varias horas seguidas para reservar más tiempo. ¿Está ocupado '
          'el que quieres? Tócalo y te avisamos si se libera.',
          style: RtcType.xs.copyWith(fontSize: 11, color: Gray.c500),
        ),
      ],
    );
  }

  Widget _leyenda(Color? fill, Color border, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: RtcRadius.brSm,
            border: Border.all(color: border),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: RtcType.xs.copyWith(fontSize: 11, color: Gray.c500)),
      ],
    );
  }

  Widget _resumenVivo() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s4,
        vertical: RtcSpace.s3,
      ),
      decoration: BoxDecoration(
        color: Green.c50,
        borderRadius: RtcRadius.brXxl,
        border: Border.all(color: Green.c200), // green-200
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fechaLargaCapitalizada(_selectedDate!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RtcType.sm.copyWith(
                    fontWeight: RtcType.semibold,
                    color: Green.c900,
                  ),
                ),
                Text(
                  '${hora12(_selectedSlots.first)} – ${hora12(_endTime)} · '
                  '${_slotDuration * _selectedSlots.length} min',
                  style: RtcType.xs.copyWith(color: Green.c700),
                ),
              ],
            ),
          ),
          Text(
            '\$${formatCop(_totalPrice)}',
            style: RtcType.sm.copyWith(
              fontWeight: RtcType.bold,
              color: Green.c800,
            ),
          ),
        ],
      ),
    );
  }

  // ── PASO 2 ───────────────────────────────────────────────────────────
  Widget _pasoCheckout() {
    final sinPago = _pagos != null && !_pagos!.configured;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RtcPressable(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _step = 'when'),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.arrowLeft, size: 16, color: Gray.c500),
              const SizedBox(width: 6),
              Text(
                'Volver',
                style: RtcType.sm.copyWith(
                  fontWeight: RtcType.medium,
                  color: Gray.c500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: RtcSpace.s5),
        _resumenEditable(),
        const SizedBox(height: RtcSpace.s5),
        _campo(
          icon: LucideIcons.user,
          label: 'Nombre completo',
          hint: 'Juan Pérez',
          controller: _nombre,
          error: _errores['guestName'],
        ),
        const SizedBox(height: RtcSpace.s3),
        _campo(
          icon: LucideIcons.mail,
          label: 'Email',
          hint: 'juan@email.com',
          controller: _email,
          error: _errores['guestEmail'],
          keyboard: TextInputType.emailAddress,
        ),
        const SizedBox(height: RtcSpace.s3),
        _campo(
          icon: LucideIcons.phone,
          label: 'Teléfono / WhatsApp',
          hint: '+57 300 123 4567',
          controller: _telefono,
          error: _errores['guestPhone'],
          keyboard: TextInputType.phone,
        ),
        const SizedBox(height: RtcSpace.s3),
        _campo(
          label: 'Notas',
          opcional: true,
          hint: 'Ej: venimos 5 personas…',
          controller: _notas,
          lineas: 2,
        ),
        const SizedBox(height: RtcSpace.s5),
        _etiqueta(LucideIcons.lock, 'Método de pago'),
        const SizedBox(height: 10),
        if (sinPago) _pagoNoDisponible() else _metodoEpayco(),
        const SizedBox(height: RtcSpace.s5),
        // El desglose va completo a proposito: la tarifa de servicio se ve
        // antes de pagar, no como una sorpresa en ePayco.
        _lineaDesglose(
          'Cancha · ${_slotDuration * _selectedSlots.length} min',
          _precioCancha,
        ),
        const SizedBox(height: 6),
        _lineaDesglose('Tarifa de servicio', _tarifaServicio),
        const SizedBox(height: RtcSpace.s2),
        Divider(height: 1, color: Gray.c100),
        const SizedBox(height: RtcSpace.s2),
        Row(
          children: [
            Text('Total', style: RtcType.sm.copyWith(color: Gray.c500)),
            const Spacer(),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '\$${formatCop(_totalPrice)}'),
                  TextSpan(
                    text: ' COP',
                    style: RtcType.sm.copyWith(color: Gray.c500),
                  ),
                ],
              ),
              style: RtcType.xl2.copyWith(
                fontWeight: RtcType.bold,
                color: Gray.c900,
              ),
            ),
          ],
        ),
        if (_errorGeneral != null) ...[
          const SizedBox(height: RtcSpace.s3),
          Text(_errorGeneral!, style: RtcType.xs.copyWith(color: Red.c500)),
        ],
        const SizedBox(height: RtcSpace.s5),
        _botonPrincipal(
          label: _processing ? 'Procesando…' : 'Confirmar y pagar',
          icon: LucideIcons.creditCard,
          iconLeading: true,
          enabled: !_processing && !sinPago,
          onTap: _confirmarYPagar,
        ),
        const SizedBox(height: RtcSpace.s3),
        Text(
          'Recibirás la confirmación por email, con el link para cambiar tu '
          'horario si lo necesitas.',
          textAlign: TextAlign.center,
          style: RtcType.xs.copyWith(color: Gray.c500),
        ),
      ],
    );
  }

  Widget _resumenEditable() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s4,
        vertical: RtcSpace.s3,
      ),
      decoration: BoxDecoration(
        color: Gray.c50,
        borderRadius: RtcRadius.brXxl,
        border: Border.all(color: Gray.c100),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fechaLargaCapitalizada(_selectedDate!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RtcType.sm.copyWith(
                    fontWeight: RtcType.semibold,
                    color: Gray.c900,
                  ),
                ),
                Text(
                  '${hora12(_selectedSlots.first)} – ${hora12(_endTime)} · '
                  '${widget.courtName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RtcType.xs.copyWith(color: Gray.c500),
                ),
              ],
            ),
          ),
          RtcPressable(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _step = 'when'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.pencil, size: 12, color: Green.c700),
                const SizedBox(width: 4),
                Text(
                  'Editar',
                  style: RtcType.xs.copyWith(
                    fontWeight: RtcType.medium,
                    color: Green.c700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _lineaDesglose(String label, int valor) {
    return Row(
      children: [
        Text(label, style: RtcType.sm.copyWith(color: Gray.c500)),
        const Spacer(),
        Text(
          '\$${formatCop(valor)}',
          style: RtcType.sm.copyWith(
            fontWeight: RtcType.medium,
            color: Gray.c900,
          ),
        ),
      ],
    );
  }

  /// Una sola tarjeta: no hay nada que elegir (todo se paga en ePayco), así
  /// que va sin radio y con los medios como logos chicos en una fila.
  Widget _metodoEpayco() {
    return Container(
      padding: const EdgeInsets.all(RtcSpace.s4),
      decoration: BoxDecoration(
        color: Superficie.tarjeta,
        borderRadius: RtcRadius.brXxl,
        border: Border.all(color: Gray.c200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Green.c50,
                  borderRadius: RtcRadius.brXl,
                ),
                child: const Icon(
                  LucideIcons.shieldCheck,
                  size: 18,
                  color: Green.c600,
                ),
              ),
              const SizedBox(width: RtcSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pago seguro con ePayco',
                      style: RtcType.sm.copyWith(
                        fontWeight: RtcType.semibold,
                        color: Gray.c900,
                      ),
                    ),
                    Text(
                      'Eliges el medio al pagar',
                      style: RtcType.xs.copyWith(color: Gray.c500),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: RtcSpace.s3),
          const MediosPago(),
        ],
      ),
    );
  }

  Widget _pagoNoDisponible() {
    return Container(
      padding: const EdgeInsets.all(RtcSpace.s3),
      decoration: BoxDecoration(
        color: Amber.c50,
        borderRadius: RtcRadius.brXl,
        border: Border.all(color: Amber.c200), // amber-200
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.circleAlert, size: 16, color: Amber.c600),
          ),
          const SizedBox(width: RtcSpace.s2),
          Expanded(
            child: Text(
              'El pago en línea no está disponible en este momento. Intenta '
              'de nuevo en unos minutos.',
              style: RtcType.xs.copyWith(color: Amber.c800),
            ),
          ),
        ],
      ),
    );
  }

  // ── PIEZAS SUELTAS ───────────────────────────────────────────────────

  /// El `lbl` del formulario: icono chico + texto en gris.
  Widget _etiqueta(IconData? icon, String label, {String? extra}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: Gray.c500),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: RtcType.xs.copyWith(
            fontWeight: RtcType.semibold,
            color: Gray.c500,
          ),
        ),
        if (extra != null) ...[
          const SizedBox(width: 4),
          Text(extra, style: RtcType.xs.copyWith(color: Gray.c500)),
        ],
      ],
    );
  }

  Widget _campo({
    IconData? icon,
    required String label,
    required String hint,
    required TextEditingController controller,
    String? error,
    bool opcional = false,
    int lineas = 1,
    TextInputType? keyboard,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: Gray.c500),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: RtcType.xs.copyWith(
                fontWeight: RtcType.semibold,
                color: Gray.c500,
              ),
            ),
            if (opcional) ...[
              const SizedBox(width: 4),
              Text('(opcional)', style: RtcType.xs.copyWith(color: Gray.c500)),
            ],
          ],
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboard,
          maxLines: lineas,
          enabled: !_processing,
          style: RtcType.sm.copyWith(color: Gray.c900),
          onChanged: (_) {
            if (error != null) setState(() => _errores.clear());
          },
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: RtcType.sm.copyWith(color: Gray.c500),
            filled: true,
            fillColor: Superficie.tarjeta,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: RtcSpace.s4,
              vertical: RtcSpace.s3,
            ),
            border: OutlineInputBorder(
              borderRadius: RtcRadius.brXl,
              borderSide: BorderSide(color: Gray.c200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: RtcRadius.brXl,
              borderSide: BorderSide(color: Gray.c200),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: RtcRadius.brXl,
              borderSide: BorderSide(color: Gray.c200),
            ),
            // focus:ring-2 ring-green-500/40
            focusedBorder: OutlineInputBorder(
              borderRadius: RtcRadius.brXl,
              borderSide: BorderSide(
                color: Green.c500.withValues(alpha: 0.40),
                width: 2,
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(error, style: RtcType.xs.copyWith(color: Red.c500)),
          ),
      ],
    );
  }

  Widget _botonPrincipal({
    required String label,
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
    bool iconLeading = false,
    bool pulsing = false,
  }) {
    final boton = Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14), // py-3.5
        decoration: const BoxDecoration(
          color: Green.c600,
          borderRadius: RtcRadius.brXxl,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconLeading) ...[
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(width: RtcSpace.s2),
            ],
            Text(
              label,
              style: RtcType.base.copyWith(
                color: Colors.white,
                fontWeight: RtcType.semibold,
              ),
            ),
            if (!iconLeading) ...[
              const SizedBox(width: RtcSpace.s2),
              Icon(icon, size: 20, color: Colors.white),
            ],
          ],
        ),
      ),
    );

    return RtcPressable(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      // `.rtc-ready` se aplica SOLO cuando ya se puede continuar. Envolver
      // siempre no sirve: RtcReadyPulse deja el resplandor de reposo aunque
      // este inactivo, y el boton deshabilitado quedaria brillando.
      child: pulsing
          ? RtcReadyPulse(
              active: true,
              borderRadius: RtcRadius.brXxl,
              child: boton,
            )
          : boton,
    );
  }
}

/// Hoja de "avísame si se libera": un correo y un botón.
class _AvisoTurno extends StatefulWidget {
  const _AvisoTurno({
    required this.titulo,
    required this.email,
    required this.onEnviar,
  });

  final String titulo;
  final TextEditingController email;
  final Future<void> Function() onEnviar;

  @override
  State<_AvisoTurno> createState() => _AvisoTurnoState();
}

class _AvisoTurnoState extends State<_AvisoTurno> {
  bool _enviando = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.bellRing, size: 18, color: Orange.c600),
            const SizedBox(width: RtcSpace.s2),
            Expanded(
              child: Text(
                widget.titulo,
                style: RtcType.base.copyWith(
                  fontWeight: RtcType.bold,
                  color: Gray.c900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: RtcSpace.s2),
        Text(
          'Si el pago de quien lo tiene no pasa o mueve su reserva, te '
          'escribimos. El primero que lo pague se lo queda.',
          style: RtcType.sm.copyWith(color: Gray.c500),
        ),
        const SizedBox(height: RtcSpace.s4),
        TextField(
          controller: widget.email,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: InputDecoration(
            hintText: 'tu@correo.com',
            border: OutlineInputBorder(borderRadius: RtcRadius.brXl),
          ),
        ),
        const SizedBox(height: RtcSpace.s4),
        FilledButton(
          style: FilledButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: GrisFijo.c900,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: RtcRadius.brXl),
          ),
          onPressed: _enviando
              ? null
              : () async {
                  setState(() => _enviando = true);
                  await widget.onEnviar();
                  if (mounted) setState(() => _enviando = false);
                },
          child: Text(_enviando ? 'Enviando…' : 'Avisarme'),
        ),
      ],
    );
  }
}
