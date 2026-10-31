import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/courts_api.dart';
import '../../api/owner_api.dart';
import '../../api/rtc_api.dart';
import '../../app/routes.dart';
import '../../models/constantes.dart';
import '../../models/court.dart';
import '../../theme/palette.dart';
import '../../theme/shadows.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/dashboard/availability_editor.dart';
import '../../widgets/dashboard/location_picker.dart';
import '../../widgets/icons/sport_icon.dart';
import '../../widgets/motion/rtc_motion.dart';
import '../../widgets/rtc_select_field.dart';
import '../../widgets/rtc_toast.dart';

/// Port de
/// `Frontend/src/app/dashboard/propetario/canchas/[id]/editar/page.tsx`.
///
/// Cinco secciones —informacion, ubicacion, precio, disponibilidad y
/// comodidades— con el conmutador de `SettingsTabs`, y la barra de guardado
/// pegada abajo para no perderla al cambiar de seccion.
class EditarCanchaScreen extends StatefulWidget {
  const EditarCanchaScreen({super.key, required this.courtId});

  final String courtId;

  @override
  State<EditarCanchaScreen> createState() => _EditarCanchaScreenState();
}

/// `SECTION_FIELDS`: que campo vive en cada seccion. Sirve para marcar el
/// punto rojo y para saltar a la seccion correcta cuando falla el guardado.
const _camposPorSeccion = <String, List<String>>{
  'info': ['name'],
  'ubicacion': ['address', 'city', 'department'],
  'precio': ['pricePerHour'],
  'disponibilidad': [],
  'comodidades': [],
};

class _EditarCanchaScreenState extends State<EditarCanchaScreen> {
  final _nombre = TextEditingController();
  final _descripcion = TextEditingController();
  final _direccion = TextEditingController();
  final _ciudad = TextEditingController();
  final _departamento = TextEditingController();
  final _precio = TextEditingController();

  Court? _cancha;
  bool _cargando = true;
  bool _guardando = false;
  String _seccion = 'info';

  List<AvailabilitySlot> _disponibilidad = const [];

  /// El punto exacto en el mapa. `_pinSucio` porque el pin no pasa por el
  /// formulario y sin el el aviso de "cambios sin guardar" se quedaria corto.
  LatLng? _pin;
  bool _pinSucio = false;

  /// Comodidades del catalogo marcadas. `_extras` guarda lo que la cancha ya
  /// tenia y NO esta en el catalogo — el asistente de creacion mete ahi la
  /// modalidad, "Fútbol 7". Sin separarlas, guardar desde aca la borraria.
  List<String> _comodidades = const [];
  List<String> _extras = const [];
  bool _comodidadesSucias = false;

  bool _sucio = false;
  final _errores = <String, String>{};

  @override
  void initState() {
    super.initState();
    _cargar();
    for (final c in [
      _nombre,
      _descripcion,
      _direccion,
      _ciudad,
      _departamento,
      _precio,
    ]) {
      c.addListener(_marcarSucio);
    }
  }

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

  void _marcarSucio() {
    if (!_sucio && !_cargando) setState(() => _sucio = true);
  }

  Future<void> _cargar() async {
    try {
      final cancha = await courtsApi.getById(widget.courtId);
      if (!mounted) return;
      _nombre.text = cancha.name;
      _descripcion.text = cancha.description ?? '';
      _direccion.text = cancha.address;
      _ciudad.text = cancha.city;
      _departamento.text = cancha.department;
      _precio.text = '${cancha.pricePerHour}';

      final guardadas = cancha.amenities;
      final coords = cancha.coordinates;
      setState(() {
        _cancha = cancha;
        _disponibilidad = cancha.availability;
        _comodidades = guardadas.where(kAmenidades.contains).toList();
        _extras = guardadas.where((a) => !kAmenidades.contains(a)).toList();
        _comodidadesSucias = false;
        // El backend las guarda [lng, lat]; el mapa las quiere al reves.
        if (coords != null &&
            coords.length == 2 &&
            coords[0].isFinite &&
            coords[1].isFinite) {
          _pin = LatLng(coords[1], coords[0]);
        }
        _cargando = false;
        _sucio = false;
      });
    } on RtcApiException catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      rtcToast(context, e.message, tipo: RtcToastTipo.error);
    }
  }

  /// El esquema de zod de la pagina.
  bool _validar() {
    final errores = <String, String>{};
    if (_nombre.text.trim().length < 3) {
      errores['name'] = 'Mínimo 3 caracteres';
    }
    if (_direccion.text.trim().length < 5) {
      errores['address'] = 'Ingresa la dirección';
    }
    if (_ciudad.text.trim().length < 2) errores['city'] = 'Ingresa la ciudad';
    if (_departamento.text.trim().length < 2) {
      errores['department'] = 'Ingresa el departamento';
    }
    final precio = int.tryParse(_precio.text.trim()) ?? 0;
    if (precio < 1000) {
      errores['pricePerHour'] = 'Precio mínimo \$1.000 COP';
    }
    setState(() {
      _errores
        ..clear()
        ..addAll(errores);
    });
    return errores.isEmpty;
  }

  Future<void> _guardar() async {
    if (_guardando) return;
    if (!_validar()) {
      // `onInvalid`: abre la seccion que tiene el error.
      for (final entrada in _camposPorSeccion.entries) {
        if (entrada.value.any(_errores.containsKey)) {
          setState(() => _seccion = entrada.key);
          break;
        }
      }
      rtcToast(
        context,
        'Revisa los campos marcados en rojo.',
        tipo: RtcToastTipo.error,
      );
      return;
    }

    setState(() => _guardando = true);
    try {
      await ownerApi.actualizarCancha(
        widget.courtId,
        nombre: _nombre.text.trim(),
        descripcion: _descripcion.text.trim(),
        direccion: _direccion.text.trim(),
        ciudad: _ciudad.text.trim(),
        departamento: _departamento.text.trim(),
        // Mongo guarda GeoJSON: [lng, lat]
        coordenadas: _pin == null ? null : [_pin!.longitude, _pin!.latitude],
        precioPorHora: int.parse(_precio.text.trim()),
        disponibilidad: _disponibilidad,
        // Los extras van primero, igual que al crear: la modalidad encabeza.
        comodidades: [..._extras, ..._comodidades],
      );
      if (!mounted) return;
      rtcToast(context, '¡Cancha actualizada correctamente!');
      rtcIrAlPanel('/dashboard/propetario/canchas');
    } on RtcApiException catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      rtcToast(context, e.message, tipo: RtcToastTipo.error);
    }
  }

  /// `applyResolved`: el mapa rellena los campos, pero no los bloquea.
  void _aplicarDireccion(DireccionResuelta r) {
    if (r.address.isNotEmpty) _direccion.text = r.address;
    if (r.city.isNotEmpty) _ciudad.text = r.city;
    if (r.department.isNotEmpty) _departamento.text = r.department;
    setState(() => _sucio = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) return const _EsqueletoEditar();

    final cancha = _cancha;
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            _volver(),
            const SizedBox(height: RtcSpace.s5),
            _encabezado(cancha),
            const SizedBox(height: RtcSpace.s5),
            RtcSettingsTabs(
              secciones: [
                (
                  'info',
                  'Información',
                  'Nombre y descripción de la cancha',
                  LucideIcons.building2,
                  _camposPorSeccion['info']!.any(_errores.containsKey),
                ),
                (
                  'ubicacion',
                  'Ubicación',
                  'Dónde queda la cancha',
                  LucideIcons.mapPin,
                  _camposPorSeccion['ubicacion']!.any(_errores.containsKey),
                ),
                (
                  'precio',
                  'Precio',
                  'Tarifa por hora de juego',
                  LucideIcons.dollarSign,
                  _camposPorSeccion['precio']!.any(_errores.containsKey),
                ),
                (
                  'disponibilidad',
                  'Disponibilidad',
                  'Días y horarios en los que atiendes',
                  LucideIcons.clock,
                  false,
                ),
                (
                  'comodidades',
                  'Comodidades',
                  'Qué ofrece tu cancha',
                  LucideIcons.sparkles,
                  false,
                ),
              ],
              activa: _seccion,
              onChange: (s) => setState(() => _seccion = s),
              child: _panel(),
            ),
          ],
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: _barraGuardado()),
      ],
    );
  }

  Widget _volver() {
    return GestureDetector(
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
            child: const Icon(
              LucideIcons.arrowLeft,
              size: 16,
              color: Gray.c500,
            ),
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
    );
  }

  Widget _encabezado(Court? cancha) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('✦', style: RtcType.sm.copyWith(color: Lime.c600)),
            const SizedBox(width: RtcSpace.s2),
            Text(
              'EDITAR CANCHA',
              style: RtcType.sm.copyWith(
                color: Lime.c600,
                fontWeight: RtcType.semibold,
                letterSpacing: 1.6,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          (cancha?.name ?? '—').toUpperCase(),
          style: RtcType.xl2.copyWith(
            fontWeight: FontWeight.w900,
            color: Gray.c900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Elige qué quieres modificar',
          style: RtcType.sm.copyWith(color: Gray.c500),
        ),
        if (cancha != null) ...[
          const SizedBox(height: RtcSpace.s4),
          // El deporte no se puede cambiar: se muestra como dato fijo.
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: RtcSpace.s4,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: RtcRadius.brXxl,
              border: Border.all(color: Gray.c100),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SportIcon(sport: cancha.sport, size: 24, color: Green.c600),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      getSport(cancha.sport).label,
                      style: RtcType.sm.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Gray.c900,
                      ),
                    ),
                    Text(
                      'No se puede cambiar',
                      style: RtcType.xs.copyWith(
                        fontSize: 11,
                        color: Gray.c400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _panel() {
    switch (_seccion) {
      case 'ubicacion':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _campo(
              'Dirección',
              _direccion,
              'Ej: Calle 72 #45-23',
              obligatorio: true,
              error: _errores['address'],
            ),
            const SizedBox(height: RtcSpace.s4),
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
              onChange: (v) => setState(() {
                _pin = v;
                _pinSucio = true;
              }),
              onResolve: _aplicarDireccion,
            ),
          ],
        );

      case 'precio':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _etiqueta('Precio por hora (COP)', obligatorio: true),
            const SizedBox(height: RtcSpace.s2),
            TextField(
              controller: _precio,
              keyboardType: TextInputType.number,
              style: RtcType.sm.copyWith(color: Gray.c900),
              decoration: _decoracion('80000', error: _errores['pricePerHour'])
                  .copyWith(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(
                        left: RtcSpace.s4,
                        right: 4,
                      ),
                      child: Text(
                        '\$',
                        style: RtcType.sm.copyWith(
                          color: Gray.c400,
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
          ],
        );

      case 'disponibilidad':
        return AvailabilityEditor(
          value: _disponibilidad,
          onChange: (v) => setState(() {
            _disponibilidad = v;
            _sucio = true;
          }),
        );

      case 'comodidades':
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
            Text(
              'Se muestran en la ficha pública de tu cancha.'
              '${_extras.isEmpty ? '' : ' La modalidad (${_extras.join(', ')}) se conserva aparte.'}',
              style: RtcType.xs.copyWith(color: Gray.c400),
            ),
          ],
        );

      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _campo(
              'Nombre',
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
              lineas: 4,
            ),
          ],
        );
    }
  }

  Widget _chipComodidad(String a) {
    final activa = _comodidades.contains(a);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        _comodidadesSucias = true;
        _comodidades = activa
            ? (_comodidades.where((x) => x != a).toList())
            : [..._comodidades, a];
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: RtcSpace.s3,
          vertical: RtcSpace.s2,
        ),
        decoration: BoxDecoration(
          color: activa ? Green.c50 : Colors.white,
          borderRadius: RtcRadius.brFull,
          border: Border.all(
            color: activa ? const Color(0xFF22C55E) : Gray.c200,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (activa) ...[
              const Icon(LucideIcons.circleCheck, size: 12, color: Green.c700),
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

  InputDecoration _decoracion(String hint, {String? error}) {
    final mal = error != null;
    final borde = OutlineInputBorder(
      borderRadius: RtcRadius.brXl,
      borderSide: BorderSide(color: mal ? Red.c300 : Gray.c200),
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

  /// La barra pegada abajo, con el degradado que la despega del contenido.
  Widget _barraGuardado() {
    return Container(
      // Sin padding horizontal: el armazon del panel ya aplica el suyo. La web
      // hace lo mismo con `-mx-4 px-4` — se sale del padding del contenedor y
      // pone el propio, para quedar al mismo ras que el contenido. Sumarlos
      // dejaba los botones angostos y el texto partido en dos lineas.
      padding: const EdgeInsets.only(top: RtcSpace.s6, bottom: RtcSpace.s4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Slate.c50.withValues(alpha: 0), Slate.c50, Slate.c50],
          stops: const [0, 0.45, 1],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _guardando
                      ? null
                      : () => rtcIrAlPanel('/dashboard/propetario/canchas'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: RtcSpace.s4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: RtcRadius.brXxl,
                      border: Border.all(color: Gray.c200, width: 2),
                    ),
                    child: Text(
                      'Cancelar',
                      style: RtcType.base.copyWith(
                        fontWeight: RtcType.bold,
                        color: Gray.c700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: RtcSpace.s3),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _guardando ? null : _guardar,
                  child: Opacity(
                    opacity: _guardando ? 0.6 : 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: RtcSpace.s4,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Green.c600,
                        borderRadius: RtcRadius.brXxl,
                        boxShadow: [
                          cssShadow(
                            dy: 10,
                            blur: 15,
                            spread: -3,
                            color: Green.c600.withValues(alpha: 0.20),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_guardando)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          else
                            const Icon(
                              LucideIcons.save,
                              size: 20,
                              color: Colors.white,
                            ),
                          const SizedBox(width: RtcSpace.s2),
                          Flexible(
                            child: Text(
                              _guardando ? 'Guardando...' : 'Guardar cambios',
                              maxLines: 1,
                              style: RtcType.base.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_sucio || _pinSucio || _comodidadesSucias) ...[
            const SizedBox(height: RtcSpace.s2),
            Text(
              'Tienes cambios sin guardar',
              style: RtcType.xs.copyWith(color: Gray.c400),
            ),
          ],
        ],
      ),
    );
  }
}

/// El esqueleto que muestra la web mientras carga la cancha.
class _EsqueletoEditar extends StatelessWidget {
  const _EsqueletoEditar();

  @override
  Widget build(BuildContext context) {
    return RtcSkeletonPulse(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              height: 32,
              width: 192,
              decoration: BoxDecoration(
                color: Gray.c200,
                borderRadius: RtcRadius.brXl,
              ),
            ),
          ),
          const SizedBox(height: RtcSpace.s5),
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: Gray.c100,
              borderRadius: RtcRadius.brXxl,
            ),
          ),
          const SizedBox(height: RtcSpace.s5),
          Container(
            height: 288,
            decoration: BoxDecoration(
              color: Gray.c100,
              borderRadius: RtcRadius.brXxl,
            ),
          ),
        ],
      ),
    );
  }
}
