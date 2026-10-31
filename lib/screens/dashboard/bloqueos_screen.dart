import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/owner_api.dart';
import '../../api/rtc_api.dart';
import '../../models/court.dart';
import '../../models/fechas.dart';
import '../../theme/motion.dart';
import '../../theme/palette.dart';
import '../../theme/shadows.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/motion/rtc_motion.dart';
import '../../widgets/rtc_borde_punteado.dart';
import '../../widgets/rtc_select_field.dart';
import '../../widgets/rtc_toast.dart';

/// Port de `Frontend/src/app/dashboard/propetario/bloqueos/page.tsx`.
///
/// Un formulario plegable en naranja y la lista de bloqueos. Los pasados se
/// pintan al 60% y pierden el boton de borrar.
class BloqueosScreen extends StatefulWidget {
  const BloqueosScreen({super.key});

  @override
  State<BloqueosScreen> createState() => _BloqueosScreenState();
}

/// `EASE` de la pagina.
const _ease = RtcCurves.framerExpo;

class _BloqueosScreenState extends State<BloqueosScreen> {
  List<Court> _canchas = const [];
  List<BloqueoHorario> _bloqueos = const [];
  bool _cargando = true;

  bool _formAbierto = false;
  bool _bloqueando = false;
  String? _borrando;

  String? _canchaId;
  DateTime? _fecha;
  String? _horaInicio;
  String? _horaFin;
  final _motivo = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _cargando = true);
    try {
      final canchas = await ownerApi.misCanchas();
      final bloqueos = await ownerApi.bloqueos();
      if (!mounted) return;
      setState(() {
        _canchas = canchas;
        _bloqueos = bloqueos;
        _cargando = false;
      });
    } on RtcApiException catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      rtcToast(context, e.message, tipo: RtcToastTipo.error);
    }
  }

  /// Las 24 horas en punto.
  static final _horas = List.generate(
    24,
    (i) => '${i.toString().padLeft(2, '0')}:00',
  );

  List<(String, String)> get _opcionesCancha => [
    for (final c in _canchas) (c.id, c.name),
  ];

  List<(String, String)> get _opcionesInicio => [
    for (final h in _horas) (h, hora12(h)),
  ];

  /// `hours.filter(h => !startTime || h > startTime)`.
  List<(String, String)> get _opcionesFin => [
    for (final h in _horas)
      if (_horaInicio == null || h.compareTo(_horaInicio!) > 0) (h, hora12(h)),
  ];

  /// `pickStart`: al mover el inicio, el fin puede quedar invalido.
  void _elegirInicio(String v) => setState(() {
    _horaInicio = v;
    if (_horaFin != null && _horaFin!.compareTo(v) <= 0) _horaFin = null;
  });

  bool get _listo =>
      _canchaId != null &&
      _fecha != null &&
      _horaInicio != null &&
      _horaFin != null;

  int get _horasBloqueadas => _listo
      ? int.parse(_horaFin!.split(':')[0]) -
            int.parse(_horaInicio!.split(':')[0])
      : 0;

  void _limpiar() {
    _canchaId = null;
    _fecha = null;
    _horaInicio = null;
    _horaFin = null;
    _motivo.clear();
  }

  Future<void> _elegirFecha() async {
    final hoy = ahoraEnBogota();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha ?? hoy,
      // `min={format(new Date(), 'yyyy-MM-dd')}`: no se bloquea el pasado.
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: DateTime(hoy.year + 2),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(
            context,
          ).colorScheme.copyWith(primary: Orange.c500),
        ),
        child: child!,
      ),
    );
    if (elegida != null) setState(() => _fecha = elegida);
  }

  Future<void> _bloquear() async {
    if (!_listo || _bloqueando) return;
    FocusScope.of(context).unfocus();
    setState(() => _bloqueando = true);
    try {
      await ownerApi.crearBloqueo(
        courtId: _canchaId!,
        fecha: fechaIso(_fecha!),
        horaInicio: _horaInicio!,
        horaFin: _horaFin!,
        motivo: _motivo.text.trim(),
      );
      if (!mounted) return;
      rtcToast(context, 'Horario bloqueado exitosamente');
      setState(() {
        _bloqueando = false;
        _formAbierto = false;
        _limpiar();
      });
      await _cargar(silencioso: true);
    } on RtcApiException catch (e) {
      if (!mounted) return;
      setState(() => _bloqueando = false);
      rtcToast(context, e.message, tipo: RtcToastTipo.error);
    }
  }

  Future<void> _eliminar(String id) async {
    if (_borrando != null) return;
    setState(() => _borrando = id);
    try {
      await ownerApi.eliminarBloqueo(id);
      if (!mounted) return;
      rtcToast(context, 'Bloqueo eliminado');
      setState(() {
        _borrando = null;
        _bloqueos = _bloqueos.where((b) => b.id != id).toList();
      });
    } on RtcApiException {
      if (!mounted) return;
      setState(() => _borrando = null);
      rtcToast(context, 'Error al eliminar bloqueo', tipo: RtcToastTipo.error);
    }
  }

  // ── VISTA ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _cargar,
      color: Orange.c500,
      child: ListView(
        padding: const EdgeInsets.only(bottom: RtcSpace.s12),
        children: [
          _encabezado(),
          const SizedBox(height: RtcSpace.s6),
          // `AnimatePresence` con `height: 0 → auto` en 0.32s.
          AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: _ease,
            alignment: Alignment.topCenter,
            child: _formAbierto
                ? Padding(
                    padding: const EdgeInsets.only(bottom: RtcSpace.s6),
                    child: _formulario(),
                  )
                : const SizedBox(width: double.infinity),
          ),
          _lista(),
        ],
      ),
    );
  }

  Widget _encabezado() {
    // `flex-col sm:flex-row`: en movil el boton va debajo del titulo.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.ban, size: 24, color: Orange.c500),
            const SizedBox(width: RtcSpace.s2),
            Expanded(
              child: Text(
                'BLOQUEAR HORARIOS',
                style: RtcType.xl2.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Gray.c900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Bloquea horarios para mantenimiento, torneos privados o cualquier '
          'motivo.',
          style: RtcType.sm.copyWith(color: Gray.c500),
        ),
        const SizedBox(height: RtcSpace.s4),
        Align(
          alignment: Alignment.centerLeft,
          child: _Presionable(
            escala: 0.97,
            onTap: () => setState(() => _formAbierto = !_formAbierto),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: RtcSpace.s5,
                vertical: 10, // py-2.5
              ),
              decoration: BoxDecoration(
                color: Orange.c500,
                borderRadius: RtcRadius.brXl,
                boxShadow: [
                  cssShadow(
                    dy: 10,
                    blur: 15,
                    color: Orange.c500.withValues(alpha: 0.20),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // `animate={{ rotate: showForm ? 45 : 0 }}` con resorte
                  // 400/22: la cruz sale del mismo `+`.
                  _GiroResorte(
                    activo: _formAbierto,
                    child: const Icon(
                      LucideIcons.plus,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: RtcSpace.s2),
                  Text(
                    _formAbierto ? 'Cerrar' : 'Nuevo bloqueo',
                    style: RtcType.sm.copyWith(
                      fontWeight: RtcType.bold,
                      color: Colors.white,
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

  // ── FORMULARIO ───────────────────────────────────────────────────────

  Widget _formulario() {
    return Container(
      padding: const EdgeInsets.all(RtcSpace.s5),
      decoration: BoxDecoration(
        // `bg-orange-50/70` sobre el gris del panel.
        color: Color.alphaBlend(Orange.c50.withValues(alpha: 0.70), Slate.c50),
        borderRadius: RtcRadius.brXxl,
        border: Border.all(color: Orange.c200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Orange.c100,
                  borderRadius: RtcRadius.brXl,
                ),
                child: const Icon(
                  LucideIcons.triangleAlert,
                  size: 16,
                  color: Orange.c600,
                ),
              ),
              const SizedBox(width: 10), // gap-2.5
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bloquear horario',
                      style: RtcType.base.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Orange.c900,
                        height: 1.1, // leading-tight
                      ),
                    ),
                    Text(
                      'Ese rango dejará de aparecer como disponible',
                      style: RtcType.xs.copyWith(
                        color: Orange.c700.withValues(alpha: 0.70),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: RtcSpace.s3),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _formAbierto = false),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(LucideIcons.x, size: 16, color: Orange.c400),
                ),
              ),
            ],
          ),
          const SizedBox(height: RtcSpace.s5),

          // `grid-cols-1 sm:grid-cols-2`: en movil uno debajo del otro.
          _etiqueta('Cancha'),
          const SizedBox(height: RtcSpace.s2),
          RtcSelectField(
            value: _canchaId,
            opciones: _opcionesCancha,
            acento: RtcSelectAcento.naranja,
            titulo: 'Cancha',
            placeholder: _opcionesCancha.isEmpty
                ? 'No tienes canchas'
                : 'Seleccionar cancha',
            deshabilitado: _opcionesCancha.isEmpty,
            onChange: (v) => setState(() => _canchaId = v),
          ),
          const SizedBox(height: RtcSpace.s4),

          _etiqueta('Fecha'),
          const SizedBox(height: RtcSpace.s2),
          _campoFecha(),
          const SizedBox(height: RtcSpace.s4),

          _etiqueta('Hora inicio'),
          const SizedBox(height: RtcSpace.s2),
          RtcSelectField(
            value: _horaInicio,
            opciones: _opcionesInicio,
            acento: RtcSelectAcento.naranja,
            titulo: 'Hora de inicio',
            placeholder: 'Seleccionar',
            onChange: _elegirInicio,
          ),
          const SizedBox(height: RtcSpace.s4),

          _etiqueta('Hora fin'),
          const SizedBox(height: RtcSpace.s2),
          RtcSelectField(
            value: _horaFin,
            opciones: _opcionesFin,
            acento: RtcSelectAcento.naranja,
            titulo: 'Hora de fin',
            placeholder: _horaInicio == null
                ? 'Elige primero la hora de inicio'
                : 'Seleccionar',
            deshabilitado: _horaInicio == null,
            onChange: (v) => setState(() => _horaFin = v),
          ),
          const SizedBox(height: RtcSpace.s5),

          _etiqueta('Motivo', opcional: '(opcional)'),
          const SizedBox(height: RtcSpace.s2),
          TextField(
            controller: _motivo,
            style: RtcType.sm.copyWith(color: Gray.c900),
            decoration: _decoracion('Ej: Mantenimiento, Torneo privado...'),
          ),

          // El resumen en vivo, que entra desde -6px.
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: _ease,
            alignment: Alignment.topCenter,
            child: !_listo
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: RtcSpace.s5),
                    child: _resumen(),
                  ),
          ),
          const SizedBox(height: RtcSpace.s5),

          // `flex-col-reverse sm:flex-row`: en movil el principal va arriba.
          _botonBloquear(),
          const SizedBox(height: RtcSpace.s3),
          _Presionable(
            escala: 0.98,
            onTap: () => setState(() => _formAbierto = false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: RtcSpace.s3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Gray.c200),
                borderRadius: RtcRadius.brXl,
              ),
              child: Text(
                'Cancelar',
                style: RtcType.sm.copyWith(
                  fontWeight: RtcType.bold,
                  color: Gray.c600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campoFecha() {
    // `<input type="date">`: en telefono eso es el calendario del sistema.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _elegirFecha,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: RtcSpace.s4,
          vertical: RtcSpace.s3,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: RtcRadius.brXl,
          border: Border.all(color: Gray.c200),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _fecha == null ? 'Seleccionar fecha' : fechaIso(_fecha!),
                style: RtcType.sm.copyWith(
                  color: _fecha == null ? Gray.c400 : Gray.c900,
                ),
              ),
            ),
            const SizedBox(width: RtcSpace.s2),
            const Icon(LucideIcons.calendarDays, size: 16, color: Gray.c400),
          ],
        ),
      ),
    );
  }

  Widget _resumen() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s4,
        vertical: RtcSpace.s3,
      ),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          Orange.c100.withValues(alpha: 0.70),
          Orange.c50,
        ),
        borderRadius: RtcRadius.brXl,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.clock, size: 16, color: Orange.c800),
          ),
          const SizedBox(width: RtcSpace.s2),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Se bloquearán '),
                  TextSpan(
                    text:
                        '$_horasBloqueadas hora'
                        '${_horasBloqueadas == 1 ? '' : 's'}',
                    style: const TextStyle(fontWeight: RtcType.bold),
                  ),
                  const TextSpan(text: ' el '),
                  TextSpan(
                    text: fechaLarga(_fecha!),
                    style: const TextStyle(fontWeight: RtcType.bold),
                  ),
                ],
              ),
              style: RtcType.sm.copyWith(color: Orange.c800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonBloquear() {
    return _Presionable(
      escala: _listo ? 0.98 : 1,
      onTap: _listo ? _bloquear : null,
      child: Opacity(
        // `disabled:opacity-40`
        opacity: _listo && !_bloqueando ? 1 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: RtcSpace.s3),
          decoration: BoxDecoration(
            color: Orange.c500,
            borderRadius: RtcRadius.brXl,
            boxShadow: [
              cssShadow(
                dy: 10,
                blur: 15,
                color: Orange.c500.withValues(alpha: 0.20),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_bloqueando) ...[
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: RtcSpace.s2),
                Text(
                  'Bloqueando...',
                  style: RtcType.sm.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ] else ...[
                const Icon(LucideIcons.ban, size: 16, color: Colors.white),
                const SizedBox(width: RtcSpace.s2),
                Text(
                  'Confirmar bloqueo',
                  style: RtcType.sm.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── LISTA ────────────────────────────────────────────────────────────

  Widget _lista() {
    if (_cargando) {
      return Column(
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(height: RtcSpace.s3),
            RtcSkeletonPulse(
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: Gray.c100,
                  borderRadius: RtcRadius.brXl,
                ),
              ),
            ),
          ],
        ],
      );
    }

    if (_bloqueos.isEmpty) return _vacio();

    final hoy = ahoraEnBogota();
    final medianoche = DateTime(hoy.year, hoy.month, hoy.day);

    return Column(
      children: [
        for (var i = 0; i < _bloqueos.length; i++) ...[
          if (i > 0) const SizedBox(height: RtcSpace.s3),
          RtcItemIn(
            // `delay: Math.min(i * 0.04, 0.2)`
            delay: Duration(milliseconds: (i * 40).clamp(0, 200)),
            child: _tarjeta(
              _bloqueos[i],
              _bloqueos[i].fecha.isBefore(medianoche),
            ),
          ),
        ],
      ],
    );
  }

  Widget _vacio() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 64), // py-16
      decoration: ShapeDecoration(
        shape: RtcBordePunteado(color: Gray.c200, radio: RtcRadius.xxl),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.ban, size: 48, color: Gray.c300),
          const SizedBox(height: RtcSpace.s3),
          Text(
            'No tienes horarios bloqueados',
            style: RtcType.base.copyWith(
              fontWeight: RtcType.semibold,
              color: Gray.c500,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s6),
            child: Text(
              'Los horarios bloqueados no estarán disponibles para reservas',
              textAlign: TextAlign.center,
              style: RtcType.sm.copyWith(color: Gray.c400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(BloqueoHorario b, bool pasado) {
    return Opacity(
      opacity: pasado ? 0.6 : 1,
      child: Container(
        padding: const EdgeInsets.all(RtcSpace.s4),
        decoration: BoxDecoration(
          color: pasado ? Gray.c50 : Colors.white,
          borderRadius: RtcRadius.brXl,
          border: Border.all(color: pasado ? Gray.c100 : Orange.c100),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: pasado ? Gray.c200 : Orange.c100,
                borderRadius: RtcRadius.brXl,
              ),
              child: Icon(
                LucideIcons.ban,
                size: 20,
                color: pasado ? Gray.c400 : Orange.c500,
              ),
            ),
            const SizedBox(width: RtcSpace.s4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.nombreCancha,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RtcType.sm.copyWith(
                      fontWeight: RtcType.bold,
                      color: Gray.c900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: RtcSpace.s3,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _dato(LucideIcons.calendarDays, diaFechaCorta(b.fecha)),
                      _dato(
                        LucideIcons.clock,
                        '${hora12(b.horaInicio)} – ${hora12(b.horaFin)}',
                      ),
                      if (b.motivo.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: RtcSpace.s2,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Orange.c100,
                            borderRadius: RtcRadius.brFull,
                          ),
                          child: Text(
                            b.motivo,
                            style: RtcType.xs.copyWith(
                              fontWeight: RtcType.semibold,
                              color: Orange.c700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (!pasado) ...[
              const SizedBox(width: RtcSpace.s4),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _eliminar(b.id),
                child: Padding(
                  padding: const EdgeInsets.all(RtcSpace.s2),
                  child: _borrando == b.id
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Gray.c400,
                          ),
                        )
                      : const Icon(
                          LucideIcons.trash2,
                          size: 16,
                          color: Gray.c400,
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _dato(IconData icono, String texto) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 12, color: Gray.c500),
        const SizedBox(width: 4),
        Text(texto, style: RtcType.xs.copyWith(color: Gray.c500)),
      ],
    );
  }

  // ── PIEZAS ───────────────────────────────────────────────────────────

  Widget _etiqueta(String texto, {String? opcional}) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: texto.toUpperCase()),
          if (opcional != null)
            TextSpan(
              text: ' $opcional',
              style: RtcType.xs.copyWith(
                color: Gray.c400,
                fontWeight: RtcType.medium,
                letterSpacing: 0,
              ),
            ),
        ],
      ),
      style: RtcType.xs.copyWith(
        fontWeight: FontWeight.w900,
        color: Gray.c500,
        letterSpacing: 1.6,
      ),
    );
  }

  InputDecoration _decoracion(String hint) {
    final borde = OutlineInputBorder(
      borderRadius: RtcRadius.brXl,
      borderSide: const BorderSide(color: Gray.c200),
    );
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: RtcType.sm.copyWith(color: Gray.c400),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s4,
        vertical: RtcSpace.s3,
      ),
      border: borde,
      enabledBorder: borde,
      // `focus:ring-2 focus:ring-orange-400`
      focusedBorder: OutlineInputBorder(
        borderRadius: RtcRadius.brXl,
        borderSide: const BorderSide(color: Orange.c400, width: 2),
      ),
    );
  }
}

/// `whileTap={{ scale }}`.
class _Presionable extends StatefulWidget {
  const _Presionable({
    required this.child,
    required this.onTap,
    this.escala = 0.97,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double escala;

  @override
  State<_Presionable> createState() => _PresionableState();
}

class _PresionableState extends State<_Presionable> {
  bool _abajo = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _abajo = true),
      onTapUp: (_) => setState(() => _abajo = false),
      onTapCancel: () => setState(() => _abajo = false),
      child: AnimatedScale(
        scale: _abajo && widget.onTap != null ? widget.escala : 1,
        duration: RtcDur.pick,
        curve: RtcCurves.smooth,
        child: widget.child,
      ),
    );
  }
}

/// `animate={{ rotate: 45 }}` con `spring 400/22`.
class _GiroResorte extends StatefulWidget {
  const _GiroResorte({required this.activo, required this.child});

  final bool activo;
  final Widget child;

  @override
  State<_GiroResorte> createState() => _GiroResorteState();
}

class _GiroResorteState extends State<_GiroResorte>
    with SingleTickerProviderStateMixin {
  static const _resorte = SpringDescription(
    mass: 1,
    stiffness: 400,
    damping: 22,
  );

  late final AnimationController _c = AnimationController.unbounded(
    vsync: this,
    value: widget.activo ? 1 : 0,
  );

  @override
  void didUpdateWidget(_GiroResorte old) {
    super.didUpdateWidget(old);
    if (widget.activo != old.activo) {
      _c.animateWith(
        SpringSimulation(_resorte, _c.value, widget.activo ? 1 : 0, 0),
      );
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      // 45° = pi/4.
      builder: (context, child) =>
          Transform.rotate(angle: _c.value * (math.pi / 4), child: child),
      child: widget.child,
    );
  }
}
