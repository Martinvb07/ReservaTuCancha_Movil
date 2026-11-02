import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/cloudinary.dart';
import '../../api/owner_api.dart';
import '../../api/rtc_api.dart';
import '../../app/routes.dart';
import '../../models/constantes.dart';
import '../../models/court.dart';
import '../../theme/motion.dart';
import '../../theme/palette.dart';
import '../../theme/shadows.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/dashboard/availability_editor.dart';
import '../../widgets/dashboard/location_picker.dart';
import '../../widgets/icons/sport_icon.dart';
import '../../widgets/rtc_borde_punteado.dart';
import '../../widgets/rtc_select_field.dart';
import '../../widgets/rtc_toast.dart';
import '../../widgets/step_wizard.dart';
import '../../widgets/motion/rtc_pressable.dart';

/// Port de `Frontend/src/app/dashboard/propetario/canchas/nueva/page.tsx`.
///
/// Seis pasos: deporte, datos + ubicacion, precio + disponibilidad, fotos,
/// comodidades y el resumen final. Las fotos se eligen aca pero se suben
/// DESPUES de crear la cancha, porque necesitan su id.
class NuevaCanchaScreen extends StatefulWidget {
  const NuevaCanchaScreen({super.key});

  @override
  State<NuevaCanchaScreen> createState() => _NuevaCanchaScreenState();
}

/// `SPORTS`.
const _deportes = <({String valor, String etiqueta, String desc})>[
  (valor: 'futbol', etiqueta: 'Fútbol', desc: 'Fútbol 5, 7 u 11'),
  (valor: 'padel', etiqueta: 'Pádel', desc: 'Techada o abierta'),
  (valor: 'voley_playa', etiqueta: 'Voley Playa', desc: 'Arena profesional'),
];

/// `FUTBOL_MODALIDADES`. El `valor` se guarda como amenidad, asi que la
/// etiqueta tiene que salir de el ("futbol_5" → "Fútbol 5").
const _modalidades =
    <({String valor, String etiqueta, String jugadores, String desc})>[
      (
        valor: 'futbol_5',
        etiqueta: 'Fútbol 5',
        jugadores: '10 jug.',
        desc: 'Cancha pequeña',
      ),
      (
        valor: 'futbol_7',
        etiqueta: 'Fútbol 7',
        jugadores: '14 jug.',
        desc: 'Cancha mediana',
      ),
      (
        valor: 'futbol_11',
        etiqueta: 'Fútbol 11',
        jugadores: '22 jug.',
        desc: 'Cancha reglamentaria',
      ),
    ];

/// `CURRENCIES`.
const _monedas = [('COP', 'COP'), ('USD', 'USD')];

/// `STEPS`: titulo, pista y que campos valida cada paso.
const _pasos = <({String titulo, String pista, List<String> campos})>[
  (
    titulo: 'Deporte',
    pista: 'Qué se juega en la cancha',
    campos: ['sport', 'futbolModalidad'],
  ),
  (
    titulo: 'Datos',
    pista: 'Nombre y dónde queda',
    campos: ['name', 'address', 'city', 'department'],
  ),
  (
    titulo: 'Precio',
    pista: 'Tarifa y horarios de atención',
    campos: ['pricePerHour'],
  ),
  (titulo: 'Fotos', pista: 'Lo primero que ve el jugador', campos: []),
  (titulo: 'Comodidades', pista: 'Qué ofrece tu cancha', campos: []),
  (titulo: 'Publicar', pista: 'Revisión final', campos: []),
];

final _ultimo = _pasos.length - 1;

/// Maximo del dropzone: `imgs.slice(0, 10 - prev.length)`.
const _maxFotos = 10;

class _NuevaCanchaScreenState extends State<NuevaCanchaScreen> {
  final _nombre = TextEditingController();
  final _descripcion = TextEditingController();
  final _direccion = TextEditingController();
  final _ciudad = TextEditingController();
  final _departamento = TextEditingController();
  final _precio = TextEditingController();

  int _paso = 0;

  /// 1 = avanzando, -1 = retrocediendo.
  int _dir = 1;

  String? _deporte;
  String? _modalidad;
  String _moneda = 'COP';

  /// Fotos elegidas. Todavia no existe la cancha, asi que se guardan sin subir.
  final _fotos = <XFile>[];

  /// Punto exacto en el mapa. Opcional: sin el la cancha se ubica por ciudad.
  LatLng? _pin;

  List<AvailabilitySlot> _disponibilidad = const [
    AvailabilitySlot(
      dayOfWeek: 1,
      openTime: '07:00',
      closeTime: '22:00',
      slotDurationMinutes: 60,
    ),
    AvailabilitySlot(
      dayOfWeek: 2,
      openTime: '07:00',
      closeTime: '22:00',
      slotDurationMinutes: 60,
    ),
    AvailabilitySlot(
      dayOfWeek: 3,
      openTime: '07:00',
      closeTime: '22:00',
      slotDurationMinutes: 60,
    ),
    AvailabilitySlot(
      dayOfWeek: 4,
      openTime: '07:00',
      closeTime: '22:00',
      slotDurationMinutes: 60,
    ),
    AvailabilitySlot(
      dayOfWeek: 5,
      openTime: '07:00',
      closeTime: '22:00',
      slotDurationMinutes: 60,
    ),
  ];

  List<String> _comodidades = const [];

  final _errores = <String, String>{};
  bool _publicando = false;

  /// `uploadStatus`: "Subiendo foto 2 de 5...".
  String? _estadoSubida;

  @override
  void dispose() {
    for (final c in [
      _nombre,
      _descripcion,
      _direccion,
      _ciudad,
      _departamento,
      _precio,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── VALIDACION ───────────────────────────────────────────────────────
  // El `schema` de zod, campo por campo. Solo se valida lo del paso actual,
  // igual que `trigger(STEPS[step].fields)`.

  String? _error(String campo) {
    switch (campo) {
      case 'name':
        return _nombre.text.trim().length < 3 ? 'Mínimo 3 caracteres' : null;
      case 'address':
        return _direccion.text.trim().length < 5
            ? 'Ingresa la dirección'
            : null;
      case 'city':
        return _ciudad.text.trim().length < 2 ? 'Ingresa la ciudad' : null;
      case 'department':
        return _departamento.text.trim().length < 2
            ? 'Ingresa el departamento'
            : null;
      case 'pricePerHour':
        final v = int.tryParse(_precio.text.trim());
        return (v == null || v < 1000) ? 'Precio mínimo \$1.000 COP' : null;
      case 'sport':
        return _deporte == null ? 'Selecciona un deporte' : null;
      case 'futbolModalidad':
        return _deporte == 'futbol' && _modalidad == null
            ? 'Selecciona la modalidad'
            : null;
    }
    return null;
  }

  bool _validar(List<String> campos) {
    var ok = true;
    for (final c in campos) {
      final e = _error(c);
      if (e == null) {
        _errores.remove(c);
      } else {
        _errores[c] = e;
        ok = false;
      }
    }
    setState(() {});
    return ok;
  }

  void _irA(int destino) {
    setState(() {
      _dir = destino > _paso ? 1 : -1;
      _paso = destino;
    });
  }

  /// `next()`.
  void _siguiente() {
    FocusScope.of(context).unfocus();
    if (!_validar(_pasos[_paso].campos)) return;
    // La disponibilidad no vive en el schema: se valida a mano.
    if (_paso == 2 && _disponibilidad.isEmpty) {
      rtcToast(
        context,
        'Selecciona al menos un día de atención.',
        tipo: RtcToastTipo.error,
      );
      return;
    }
    _irA(_paso + 1 > _ultimo ? _ultimo : _paso + 1);
  }

  /// `onInvalid`: salta al primer paso con errores.
  void _revisarTodo() {
    final malos = <String>[];
    for (final p in _pasos) {
      for (final c in p.campos) {
        if (_error(c) != null) malos.add(c);
      }
    }
    if (malos.isEmpty) return;
    _errores
      ..clear()
      ..addEntries(malos.map((c) => MapEntry(c, _error(c)!)));
    final paso = _pasos.indexWhere((p) => p.campos.any(malos.contains));
    if (paso >= 0) {
      _irA(paso);
      rtcToast(
        context,
        'Revisa los campos marcados en rojo.',
        tipo: RtcToastTipo.error,
      );
    }
  }

  // ── FOTOS ────────────────────────────────────────────────────────────

  Future<void> _elegirFotos() async {
    if (_fotos.length >= _maxFotos) return;
    // La web usa `<input type="file" accept="image/*" multiple>`: en movil eso
    // es el selector de la galeria con seleccion multiple.
    final elegidas = await ImagePicker().pickMultiImage();
    if (elegidas.isEmpty || !mounted) return;
    setState(() {
      _fotos.addAll(elegidas.take(_maxFotos - _fotos.length));
    });
  }

  void _quitarFoto(int i) => setState(() => _fotos.removeAt(i));

  // ── PUBLICAR ─────────────────────────────────────────────────────────

  Future<void> _publicar() async {
    FocusScope.of(context).unfocus();
    final campos = [for (final p in _pasos) ...p.campos];
    if (!_validar(campos)) {
      _revisarTodo();
      return;
    }

    setState(() => _publicando = true);
    try {
      final cancha = await ownerApi.crearCancha(
        nombre: _nombre.text.trim(),
        descripcion: _descripcion.text.trim(),
        deporte: _deporte!,
        // "futbol_5" → "Fútbol 5", la misma amenidad que crea la web.
        comodidades: _modalidad == null
            ? _comodidades
            : [
                _modalidad!
                    .replaceFirst('_', ' ')
                    .replaceFirst('futbol', 'Fútbol'),
                ..._comodidades,
              ],
        direccion: _direccion.text.trim(),
        ciudad: _ciudad.text.trim(),
        departamento: _departamento.text.trim(),
        // Mongo guarda GeoJSON: [lng, lat]
        coordenadas: _pin == null ? null : [_pin!.longitude, _pin!.latitude],
        precioPorHora: int.parse(_precio.text.trim()),
        moneda: _moneda,
        disponibilidad: _disponibilidad,
      );

      // Las fotos necesitan el id de la cancha, asi que van despues de crearla.
      // Si alguna falla no se pierde la cancha: se avisa y se sigue.
      if (_fotos.isNotEmpty) {
        var fallidas = 0;
        for (var i = 0; i < _fotos.length; i++) {
          if (!mounted) return;
          setState(
            () => _estadoSubida = 'Subiendo foto ${i + 1} de ${_fotos.length}…',
          );
          try {
            final bytes = await _fotos[i].readAsBytes();
            final url = await subirACloudinary(bytes, _fotos[i].name);
            await ownerApi.agregarFoto(cancha.id, url);
          } catch (_) {
            fallidas++;
          }
        }
        if (!mounted) return;
        setState(() => _estadoSubida = null);
        if (fallidas > 0) {
          rtcToast(
            context,
            '$fallidas foto(s) no se pudieron subir. Puedes reintentarlo '
            'desde Fotos.',
            tipo: RtcToastTipo.advertencia,
          );
        }
      }

      if (!mounted) return;
      rtcToast(context, '¡Cancha publicada!');
      rtcIrAlPanel('/dashboard/propetario/canchas');
    } on RtcApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _publicando = false;
        _estadoSubida = null;
      });
      rtcToast(context, e.message, tipo: RtcToastTipo.error);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _publicando = false;
        _estadoSubida = null;
      });
      rtcToast(context, 'Error al crear la cancha', tipo: RtcToastTipo.error);
    }
  }

  /// El mapa rellena los campos, pero no los bloquea: Nominatim no conoce
  /// todos los barrios.
  void _aplicarDireccion(DireccionResuelta r) {
    setState(() {
      if (r.address.isNotEmpty) _direccion.text = r.address;
      if (r.city.isNotEmpty) _ciudad.text = r.city;
      if (r.department.isNotEmpty) _departamento.text = r.department;
    });
  }

  // ── VISTA ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: RtcSpace.s12),
      children: [
        _volver(),
        const SizedBox(height: RtcSpace.s5),
        _encabezado(),
        const SizedBox(height: RtcSpace.s5),
        Container(
          padding: const EdgeInsets.all(RtcSpace.s6),
          decoration: BoxDecoration(
            color: Slate.c50,
            borderRadius: BorderRadius.circular(24), // rounded-3xl
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StepWizard(
                steps: [
                  for (final p in _pasos)
                    WizardStep(title: p.titulo, hint: p.pista),
                ],
                step: _paso,
                dir: _dir,
                onGoTo: _irA,
                child: switch (_paso) {
                  0 => _pasoDeporte(),
                  1 => _pasoDatos(),
                  2 => _pasoPrecio(),
                  3 => _pasoFotos(),
                  4 => _pasoComodidades(),
                  _ => _pasoResumen(),
                },
              ),
              const SizedBox(height: RtcSpace.s6),
              _nav(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _volver() {
    return Align(
      alignment: Alignment.centerLeft,
      child: RtcPressable(
        behavior: HitTestBehavior.opaque,
        onTap: () => rtcIrAlPanel('/dashboard/propetario/canchas'),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Gray.c200),
              ),
              child: Icon(LucideIcons.arrowLeft, size: 16, color: Gray.c500),
            ),
            const SizedBox(width: RtcSpace.s2),
            Text(
              'Volver',
              style: RtcType.sm.copyWith(
                fontWeight: RtcType.semibold,
                color: Gray.c500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _encabezado() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nueva cancha',
          style: RtcType.sm.copyWith(
            color: Green.c700,
            fontWeight: RtcType.semibold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Publicar cancha',
          style: RtcType.xl3.copyWith(
            letterSpacing: -0.4,
            fontWeight: FontWeight.w900,
            color: Gray.c900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Son ${_pasos.length} pasos cortos. Puedes volver atrás cuando '
          'quieras.',
          style: RtcType.sm.copyWith(color: Gray.c500),
        ),
      ],
    );
  }

  // ── PASO 1: deporte ──────────────────────────────────────────────────

  Widget _pasoDeporte() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // `IntrinsicHeight` porque `stretch` dentro de un scroll vertical mide
        // contra un alto infinito y la fila entera colapsa a cero SIN error.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _deportes.length; i++) ...[
                if (i > 0) const SizedBox(width: RtcSpace.s3),
                Expanded(child: _tarjetaDeporte(_deportes[i])),
              ],
            ],
          ),
        ),
        if (_errores['sport'] != null)
          Padding(
            padding: const EdgeInsets.only(top: RtcSpace.s2),
            child: Text(
              _errores['sport']!,
              style: RtcType.xs.copyWith(color: Red.c500),
            ),
          ),
        // `initial={{ opacity: 0, y: 10 }}` con 0.3s y WIZARD_EASE.
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: RtcCurves.framerExpo,
          alignment: Alignment.topCenter,
          child: _deporte != 'futbol'
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: RtcSpace.s5),
                  child: _bloqueModalidad(),
                ),
        ),
      ],
    );
  }

  Widget _tarjetaDeporte(({String valor, String etiqueta, String desc}) d) {
    final activa = _deporte == d.valor;
    return _Presionable(
      escala: 0.97,
      onTap: () => setState(() {
        _deporte = d.valor;
        _errores.remove('sport');
        if (d.valor != 'futbol') {
          _modalidad = null;
          _errores.remove('futbolModalidad');
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: RtcSpace.s5),
        decoration: BoxDecoration(
          color: activa ? Green.c50 : Superficie.tarjeta,
          borderRadius: RtcRadius.brXxl,
          border: Border.all(color: activa ? Green.c500 : Gray.c200, width: 2),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                SportIcon(
                  sport: d.valor,
                  size: 32,
                  color: activa ? Green.c600 : Gray.c400,
                ),
                const SizedBox(height: RtcSpace.s2),
                Text(
                  d.etiqueta,
                  textAlign: TextAlign.center,
                  style: RtcType.xs.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Gray.c800,
                  ),
                ),
                const SizedBox(height: RtcSpace.s2),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    d.desc,
                    textAlign: TextAlign.center,
                    style: RtcType.xs.copyWith(fontSize: 11, color: Gray.c500),
                  ),
                ),
              ],
            ),
            if (activa)
              const Positioned(top: 0, right: 0, child: _CheckResorte()),
          ],
        ),
      ),
    );
  }

  Widget _bloqueModalidad() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(LucideIcons.users, size: 12, color: Gray.c500),
            const SizedBox(width: 4),
            Expanded(child: _etiqueta('Modalidad', obligatorio: true)),
          ],
        ),
        const SizedBox(height: RtcSpace.s2),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _modalidades.length; i++) ...[
                if (i > 0) const SizedBox(width: RtcSpace.s2),
                Expanded(child: _tarjetaModalidad(_modalidades[i])),
              ],
            ],
          ),
        ),
        if (_errores['futbolModalidad'] != null)
          Padding(
            padding: const EdgeInsets.only(top: RtcSpace.s2),
            child: Text(
              _errores['futbolModalidad']!,
              style: RtcType.xs.copyWith(color: Red.c500),
            ),
          ),
      ],
    );
  }

  Widget _tarjetaModalidad(
    ({String valor, String etiqueta, String jugadores, String desc}) m,
  ) {
    final activa = _modalidad == m.valor;
    return _Presionable(
      escala: 0.97,
      onTap: () => setState(() {
        _modalidad = m.valor;
        _errores.remove('futbolModalidad');
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: RtcSpace.s3),
        decoration: BoxDecoration(
          color: activa ? Green.c50 : Superficie.tarjeta,
          borderRadius: RtcRadius.brXl,
          border: Border.all(color: activa ? Green.c500 : Gray.c200, width: 2),
        ),
        child: Column(
          children: [
            Text(
              m.etiqueta.split(' ')[1],
              style: RtcType.lg.copyWith(
                fontWeight: FontWeight.w900,
                color: Green.c700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              m.etiqueta,
              style: RtcType.xs.copyWith(
                fontWeight: RtcType.bold,
                color: Gray.c700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              m.desc,
              textAlign: TextAlign.center,
              style: RtcType.xs.copyWith(fontSize: 11, color: Gray.c500),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(LucideIcons.users, size: 10, color: Gray.c500),
                const SizedBox(width: 2),
                Text(
                  m.jugadores,
                  style: RtcType.xs.copyWith(fontSize: 11, color: Gray.c500),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── PASO 2: datos y ubicacion ────────────────────────────────────────

  Widget _pasoDatos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _campo(
          'Nombre de la cancha',
          _nombre,
          'Ej: Cancha Sintética El Estadio',
          obligatorio: true,
          error: _errores['name'],
        ),
        const SizedBox(height: RtcSpace.s4),
        _campo(
          'Descripción',
          _descripcion,
          'Superficie, capacidad, características especiales...',
          opcional: '(opcional)',
          lineas: 3,
        ),
        const SizedBox(height: RtcSpace.s4),
        _campo(
          'Dirección',
          _direccion,
          'Ej: Calle 72 #45-23, Barrio El Centro',
          obligatorio: true,
          error: _errores['address'],
        ),
        const SizedBox(height: RtcSpace.s4),
        // `grid-cols-1 sm:grid-cols-2`: en movil van uno debajo del otro.
        _campo(
          'Ciudad',
          _ciudad,
          'Villavicencio',
          obligatorio: true,
          error: _errores['city'],
        ),
        const SizedBox(height: RtcSpace.s4),
        _campo(
          'Departamento',
          _departamento,
          'Meta',
          obligatorio: true,
          error: _errores['department'],
        ),
        const SizedBox(height: RtcSpace.s5),
        _etiqueta('Punto en el mapa', opcional: '(recomendado)'),
        const SizedBox(height: RtcSpace.s2),
        LocationPicker(
          value: _pin,
          city: _ciudad.text,
          onChange: (v) => setState(() => _pin = v),
          onResolve: _aplicarDireccion,
        ),
      ],
    );
  }

  // ── PASO 3: precio y disponibilidad ──────────────────────────────────

  Widget _pasoPrecio() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(LucideIcons.dollarSign, size: 12, color: Gray.c500),
            const SizedBox(width: 4),
            Expanded(child: _etiqueta('Precio por hora', obligatorio: true)),
          ],
        ),
        const SizedBox(height: RtcSpace.s2),
        TextField(
          controller: _precio,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: RtcType.sm.copyWith(color: Gray.c900),
          decoration: _decoracion('80000', error: _errores['pricePerHour'])
              .copyWith(
                prefixIcon: Padding(
                  padding: const EdgeInsets.only(left: RtcSpace.s4, right: 4),
                  child: Text(
                    '\$',
                    style: RtcType.sm.copyWith(
                      color: Gray.c500,
                      fontWeight: RtcType.bold,
                    ),
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0),
              ),
        ),
        if (_errores['pricePerHour'] != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _errores['pricePerHour']!,
              style: RtcType.xs.copyWith(color: Red.c500),
            ),
          ),
        const SizedBox(height: RtcSpace.s4),
        _etiqueta('Moneda'),
        const SizedBox(height: RtcSpace.s2),
        RtcSelectField(
          value: _moneda,
          opciones: _monedas,
          titulo: 'Moneda',
          onChange: (v) => setState(() => _moneda = v),
        ),
        const SizedBox(height: RtcSpace.s5),
        _etiqueta('Días de atención', obligatorio: true),
        const SizedBox(height: RtcSpace.s2),
        AvailabilityEditor(
          value: _disponibilidad,
          onChange: (v) => setState(() => _disponibilidad = v),
        ),
      ],
    );
  }

  // ── PASO 4: fotos ────────────────────────────────────────────────────

  Widget _pasoFotos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Presionable(
          escala: 1,
          onTap: _elegirFotos,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: RtcSpace.s6,
              vertical: RtcSpace.s10,
            ),
            decoration: ShapeDecoration(
              color: Superficie.tarjeta,
              shape: RtcBordePunteado(
                color: Gray.c300,
                radio: RtcRadius.xxl,
                grosor: 2,
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Green.c50,
                    borderRadius: RtcRadius.brXl,
                  ),
                  child: const Icon(
                    LucideIcons.upload,
                    size: 20,
                    color: Green.c600,
                  ),
                ),
                const SizedBox(height: RtcSpace.s2),
                Text(
                  // En movil no se arrastra: el toque abre la galeria.
                  'Toca aquí para elegir tus fotos',
                  textAlign: TextAlign.center,
                  style: RtcType.sm.copyWith(
                    fontWeight: RtcType.bold,
                    color: Gray.c700,
                  ),
                ),
                const SizedBox(height: RtcSpace.s2),
                Text(
                  'JPG o PNG · hasta $_maxFotos fotos · la primera será la '
                  'principal',
                  textAlign: TextAlign.center,
                  style: RtcType.xs.copyWith(color: Gray.c500),
                ),
              ],
            ),
          ),
        ),
        if (_fotos.isNotEmpty) ...[
          const SizedBox(height: RtcSpace.s4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: _fotos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: RtcSpace.s3,
              mainAxisSpacing: RtcSpace.s3,
              childAspectRatio: 16 / 9, // aspect-video
            ),
            itemBuilder: (context, i) => _miniatura(i),
          ),
        ],
        const SizedBox(height: RtcSpace.s4),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: 'Puedes saltarte este paso y subirlas después desde ',
              ),
              TextSpan(
                text: 'Fotos',
                style: RtcType.xs.copyWith(
                  fontWeight: RtcType.semibold,
                  color: Gray.c500,
                ),
              ),
              const TextSpan(text: ' en el panel.'),
            ],
          ),
          style: RtcType.xs.copyWith(color: Gray.c500),
        ),
        if (!cloudinaryConfigurado) ...[
          const SizedBox(height: RtcSpace.s2),
          Text(
            'Esta compilación no trae el preset de Cloudinary: las fotos no '
            'se van a poder subir.',
            style: RtcType.xs.copyWith(color: Red.c500),
          ),
        ],
      ],
    );
  }

  Widget _miniatura(int i) {
    return ClipRRect(
      borderRadius: RtcRadius.brXl,
      child: Container(
        decoration: BoxDecoration(
          color: Gray.c100,
          border: Border.all(color: Gray.c200),
          borderRadius: RtcRadius.brXl,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.file(File(_fotos[i].path), fit: BoxFit.cover),
            if (i == 0)
              Positioned(
                top: 6,
                left: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: RtcSpace.s2,
                    vertical: 2,
                  ),
                  decoration: const BoxDecoration(
                    color: Green.c600,
                    borderRadius: RtcRadius.brFull,
                  ),
                  child: Text(
                    'Principal',
                    style: RtcType.xs.copyWith(
                      fontSize: 11,
                      fontWeight: RtcType.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            // En la web el boton aparece con `group-hover`; en movil no hay
            // hover, asi que se queda visible.
            Positioned(
              top: 6,
              right: 6,
              child: RtcPressable(
                behavior: HitTestBehavior.opaque,
                onTap: () => _quitarFoto(i),
                child: Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.90),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.trash2,
                    size: 14,
                    color: Red.c600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── PASO 5: comodidades ──────────────────────────────────────────────

  Widget _pasoComodidades() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _etiqueta('Comodidades', opcional: '(opcional)'),
        const SizedBox(height: RtcSpace.s2),
        Wrap(
          spacing: RtcSpace.s2,
          runSpacing: RtcSpace.s2,
          children: [for (final a in kAmenidades) _chipComodidad(a)],
        ),
        const SizedBox(height: RtcSpace.s3),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text:
                    'Aparecen en la ficha de tu cancha. Puedes cambiarlas '
                    'después desde ',
              ),
              TextSpan(
                text: 'Editar cancha',
                style: RtcType.xs.copyWith(
                  fontWeight: RtcType.semibold,
                  color: Gray.c500,
                ),
              ),
              const TextSpan(text: '.'),
            ],
          ),
          style: RtcType.xs.copyWith(color: Gray.c500),
        ),
      ],
    );
  }

  Widget _chipComodidad(String a) {
    final activa = _comodidades.contains(a);
    return _Presionable(
      escala: 0.95,
      onTap: () => setState(() {
        _comodidades = activa
            ? _comodidades.where((x) => x != a).toList()
            : [..._comodidades, a];
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(
          horizontal: RtcSpace.s3,
          vertical: RtcSpace.s2,
        ),
        decoration: BoxDecoration(
          color: activa ? Green.c50 : Superficie.tarjeta,
          borderRadius: RtcRadius.brFull,
          border: Border.all(color: activa ? Green.c500 : Gray.c200, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (activa) ...[
              Icon(LucideIcons.circleCheck, size: 12, color: Green.c700),
              const SizedBox(width: 6),
            ],
            Text(
              a,
              style: RtcType.xs.copyWith(
                fontWeight: RtcType.semibold,
                color: activa ? Green.c700 : Gray.c500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── PASO 6: revision final ───────────────────────────────────────────

  Widget _pasoResumen() {
    final deporte = _deportes
        .where((d) => d.valor == _deporte)
        .map((d) => d.etiqueta)
        .firstOrNull;
    final modalidad = _modalidades
        .where((m) => m.valor == _modalidad)
        .map((m) => m.etiqueta)
        .firstOrNull;
    final precio = int.tryParse(_precio.text.trim());

    final filas = <(String, String, int)>[
      ('Deporte', [deporte, modalidad].nonNulls.join(' · '), 0),
      ('Nombre', _nombre.text.trim(), 1),
      ('Dirección', _direccion.text.trim(), 1),
      (
        'Ciudad',
        [
          _ciudad.text.trim(),
          _departamento.text.trim(),
        ].where((s) => s.isNotEmpty).join(', '),
        1,
      ),
      (
        'Mapa',
        _pin == null
            ? 'Sin punto exacto (se ubica por ciudad)'
            : '${_pin!.latitude.toStringAsFixed(5)}, '
                  '${_pin!.longitude.toStringAsFixed(5)}',
        1,
      ),
      (
        'Precio',
        precio == null ? '' : '\$${formatCop(precio)} $_moneda / hora',
        2,
      ),
      (
        'Días',
        _disponibilidad
            .map((s) => AvailabilityEditor.dias[s.dayOfWeek])
            .join(', '),
        2,
      ),
      (
        'Fotos',
        _fotos.isEmpty
            ? 'Ninguna'
            : '${_fotos.length} seleccionada${_fotos.length > 1 ? 's' : ''}',
        3,
      ),
      (
        'Comodidades',
        _comodidades.isEmpty ? 'Ninguna' : _comodidades.join(', '),
        4,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Superficie.tarjeta,
        borderRadius: RtcRadius.brXxl,
        border: Border.all(color: Gray.c200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: Slate.c50,
            padding: const EdgeInsets.symmetric(
              horizontal: RtcSpace.s4,
              vertical: RtcSpace.s3,
            ),
            child: Text(
              'RESUMEN DE LA CANCHA',
              style: RtcType.xs.copyWith(
                fontWeight: FontWeight.w900,
                color: Gray.c900,
                letterSpacing: 1.6,
              ),
            ),
          ),
          for (final (etiqueta, valor, paso) in filas)
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Gray.c100)),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: RtcSpace.s4,
                  vertical: 10, // py-2.5
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 84,
                      child: Text(
                        etiqueta,
                        style: RtcType.xs.copyWith(color: Gray.c500),
                      ),
                    ),
                    const SizedBox(width: RtcSpace.s3),
                    Expanded(
                      child: Text(
                        valor.isEmpty ? '—' : valor,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: RtcType.sm.copyWith(
                          fontWeight: RtcType.semibold,
                          color: Gray.c800,
                        ),
                      ),
                    ),
                    const SizedBox(width: RtcSpace.s3),
                    RtcPressable(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _irA(paso),
                      child: Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          LucideIcons.pencil,
                          size: 14,
                          color: Gray.c300,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── NAVEGACION ───────────────────────────────────────────────────────

  Widget _nav() {
    return Row(
      children: [
        _Presionable(
          escala: _paso > 0 ? 0.97 : 1,
          onTap: _publicando
              ? null
              : () => _paso > 0
                    ? _irA(_paso - 1)
                    : rtcIrAlPanel('/dashboard/propetario/canchas'),
          child: Opacity(
            opacity: _publicando ? 0.6 : 1,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: RtcSpace.s5,
                vertical: RtcSpace.s4,
              ),
              decoration: BoxDecoration(
                color: Superficie.tarjeta,
                border: Border.all(color: Gray.c200),
                borderRadius: RtcRadius.brXxl,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_paso > 0) ...[
                    Icon(LucideIcons.chevronLeft, size: 16, color: Gray.c600),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    _paso > 0 ? 'Atrás' : 'Cancelar',
                    style: RtcType.sm.copyWith(
                      fontWeight: RtcType.bold,
                      color: Gray.c600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: RtcSpace.s3),
        Expanded(
          child: _Presionable(
            escala: 0.98,
            onTap: _publicando
                ? null
                : (_paso < _ultimo ? _siguiente : _publicar),
            child: Opacity(
              opacity: _publicando ? 0.6 : 1,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: RtcSpace.s4),
                decoration: BoxDecoration(
                  color: Green.c600,
                  borderRadius: RtcRadius.brXxl,
                  boxShadow: [
                    cssShadow(
                      dy: 10,
                      blur: 15,
                      color: Green.c600.withValues(alpha: 0.20),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_publicando) ...[
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: RtcSpace.s2),
                      Flexible(
                        child: Text(
                          _estadoSubida ?? 'Publicando...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RtcType.base.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ] else if (_paso < _ultimo) ...[
                      Text(
                        'Continuar',
                        style: RtcType.base.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: RtcSpace.s2),
                      const Icon(
                        LucideIcons.chevronRight,
                        size: 20,
                        color: Colors.white,
                      ),
                    ] else ...[
                      const Icon(
                        LucideIcons.plus,
                        size: 20,
                        color: Colors.white,
                      ),
                      const SizedBox(width: RtcSpace.s2),
                      Text(
                        'Publicar cancha',
                        style: RtcType.base.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── PIEZAS ───────────────────────────────────────────────────────────

  Widget _etiqueta(String texto, {bool obligatorio = false, String? opcional}) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: texto.toUpperCase()),
          if (obligatorio)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Red.c500),
            ),
          if (opcional != null)
            TextSpan(
              text: ' $opcional',
              style: RtcType.xs.copyWith(
                color: Gray.c500,
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

  InputDecoration _decoracion(String hint, {String? error}) {
    final mal = error != null;
    final borde = OutlineInputBorder(
      borderRadius: RtcRadius.brXl,
      borderSide: BorderSide(color: mal ? Red.c300 : Gray.c200),
    );
    return InputDecoration(
      isDense: true,
      hintText: hint,
      hintStyle: RtcType.sm.copyWith(color: Gray.c500),
      filled: true,
      fillColor: Superficie.tarjeta,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s4,
        vertical: RtcSpace.s3,
      ),
      border: borde,
      enabledBorder: borde,
      focusedBorder: OutlineInputBorder(
        borderRadius: RtcRadius.brXl,
        borderSide: BorderSide(color: mal ? Red.c300 : Green.c400, width: 2),
      ),
    );
  }

  Widget _campo(
    String etiqueta,
    TextEditingController controller,
    String hint, {
    bool obligatorio = false,
    String? opcional,
    String? error,
    int lineas = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _etiqueta(etiqueta, obligatorio: obligatorio, opcional: opcional),
        const SizedBox(height: RtcSpace.s2),
        TextField(
          controller: controller,
          maxLines: lineas,
          // `max(300)` de la descripcion.
          maxLength: lineas > 1 ? 300 : null,
          buildCounter:
              (_, {required currentLength, required isFocused, maxLength}) =>
                  null,
          style: RtcType.sm.copyWith(color: Gray.c900),
          decoration: _decoracion(hint, error: error),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(error, style: RtcType.xs.copyWith(color: Red.c500)),
          ),
      ],
    );
  }
}

/// `whileTap={{ scale }}` de framer-motion.
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

/// El tilde de la tarjeta activa: `scale 0 → 1` con resorte 500/22.
class _CheckResorte extends StatefulWidget {
  const _CheckResorte();

  @override
  State<_CheckResorte> createState() => _CheckResorteState();
}

class _CheckResorteState extends State<_CheckResorte>
    with SingleTickerProviderStateMixin {
  /// `type: 'spring', stiffness: 500, damping: 22` — el mismo resorte del
  /// stepper, resuelto de verdad y no aproximado con una curva.
  static const _resorte = SpringDescription(
    mass: 1,
    stiffness: 500,
    damping: 22,
  );

  late final AnimationController _c = AnimationController.unbounded(vsync: this)
    ..animateWith(SpringSimulation(_resorte, 0, 1, 0));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Opacity(
        opacity: _c.value.clamp(0.0, 1.0),
        child: Transform.scale(scale: _c.value, child: child),
      ),
      child: const Icon(LucideIcons.circleCheck, size: 16, color: Green.c600),
    );
  }
}
