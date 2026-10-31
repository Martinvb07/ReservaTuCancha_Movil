import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/owner_api.dart';
import '../../api/rtc_api.dart';
import '../../app/routes.dart';
import '../../models/court.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/icons/sport_icon.dart';
import '../../widgets/motion/rtc_motion.dart';
import '../../widgets/rtc_select_field.dart';
import '../../widgets/star_rating.dart';
import '../../widgets/rtc_toast.dart';

/// Port de `Frontend/src/app/dashboard/propetario/canchas/page.tsx`.
///
/// Buscador por nombre o ciudad, filtro por deporte y la lista con los cuatro
/// botones redondos: ver, editar, prender/apagar y eliminar.
class MisCanchasScreen extends StatefulWidget {
  const MisCanchasScreen({super.key});

  @override
  State<MisCanchasScreen> createState() => _MisCanchasScreenState();
}

/// `SPORT_FILTERS`. El 'all' existe porque el Select de Radix no admite "".
const _filtros = <(String, String)>[
  ('all', 'Todos los deportes'),
  ('futbol', 'Fútbol'),
  ('padel', 'Pádel'),
  ('voley_playa', 'Voley Playa'),
];

class _MisCanchasScreenState extends State<MisCanchasScreen> {
  final _buscador = TextEditingController();

  List<Court> _canchas = const [];
  bool _cargando = true;
  String _busqueda = '';
  String _deporte = '';

  /// La cancha que espera confirmacion de borrado.
  Court? _aEliminar;
  bool _eliminando = false;
  String? _cambiando;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  /// Igual que en Reservas: tras prender/apagar o borrar no se repone el
  /// esqueleto, que manda el scroll al principio.
  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _cargando = true);
    try {
      final canchas = await ownerApi.misCanchas();
      if (!mounted) return;
      setState(() {
        _canchas = canchas;
        _cargando = false;
      });
    } on RtcApiException catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      rtcToast(context, e.message, tipo: RtcToastTipo.error);
    }
  }

  /// `filtered`: nombre O ciudad, y el deporte si hay uno elegido.
  List<Court> get _filtradas {
    final q = _busqueda.toLowerCase();
    return _canchas.where((c) {
      final coincideTexto =
          c.name.toLowerCase().contains(q) || c.city.toLowerCase().contains(q);
      final coincideDeporte = _deporte.isEmpty || c.sport == _deporte;
      return coincideTexto && coincideDeporte;
    }).toList();
  }

  Future<void> _alternar(Court court) async {
    setState(() => _cambiando = court.id);
    try {
      await ownerApi.activarCancha(court.id, !court.isActive);
      if (!mounted) return;
      rtcToast(context, 'Estado actualizado');
      await _cargar(silencioso: true);
    } on RtcApiException {
      if (!mounted) return;
      rtcToast(context, 'Error al cambiar estado', tipo: RtcToastTipo.error);
    } finally {
      if (mounted) setState(() => _cambiando = null);
    }
  }

  Future<void> _eliminar() async {
    final court = _aEliminar;
    if (court == null) return;
    setState(() => _eliminando = true);
    try {
      await ownerApi.eliminarCancha(court.id);
      if (!mounted) return;
      setState(() {
        _aEliminar = null;
        _eliminando = false;
      });
      rtcToast(context, 'Cancha eliminada');
      await _cargar(silencioso: true);
    } on RtcApiException {
      if (!mounted) return;
      setState(() => _eliminando = false);
      rtcToast(context, 'Error al eliminar', tipo: RtcToastTipo.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lista = _filtradas;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _cargar,
          color: Green.c600,
          child: ListView(
            padding: const EdgeInsets.only(bottom: RtcSpace.s12),
            children: [
              _encabezado(),
              const SizedBox(height: RtcSpace.s6),
              _filtrosUi(),
              const SizedBox(height: RtcSpace.s6),
              if (_cargando)
                _esqueletos()
              else if (lista.isEmpty)
                _vacio()
              else
                for (var i = 0; i < lista.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: RtcSpace.s3),
                    child: RtcFadeUp(
                      delay: Duration(milliseconds: (i < 8 ? i : 8) * 45),
                      child: _fila(lista[i]),
                    ),
                  ),
            ],
          ),
        ),
        if (_aEliminar != null) _dialogoEliminar(),
      ],
    );
  }

  Widget _encabezado() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('✦', style: RtcType.sm.copyWith(color: Lime.c600)),
                  const SizedBox(width: RtcSpace.s2),
                  Text(
                    'PANEL PROPIETARIO',
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
                'MIS CANCHAS',
                style: RtcType.xl3.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Gray.c900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_canchas.length} canchas registradas',
                style: RtcType.sm.copyWith(color: Gray.c500),
              ),
            ],
          ),
        ),
        _botonNueva(),
      ],
    );
  }

  Widget _botonNueva() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => rtcIrAlPanel('/dashboard/propetario/canchas/nueva'),
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
            const Icon(LucideIcons.plus, size: 16, color: Colors.white),
            const SizedBox(width: RtcSpace.s2),
            Text(
              'Nueva',
              style: RtcType.sm.copyWith(
                color: Colors.white,
                fontWeight: RtcType.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filtrosUi() {
    return Column(
      children: [
        TextField(
          controller: _buscador,
          onChanged: (v) => setState(() => _busqueda = v),
          style: RtcType.sm.copyWith(color: Gray.c900),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Buscar por nombre o ciudad...',
            hintStyle: RtcType.sm.copyWith(color: Gray.c400),
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
        // El `SelectField` de la web. No es una fila de pildoras: esas son las
        // del sitio publico, el panel usa un desplegable.
        RtcSelectField(
          value: _deporte.isEmpty ? 'all' : _deporte,
          opciones: _filtros,
          titulo: 'Filtrar por deporte',
          onChange: (v) => setState(() => _deporte = v == 'all' ? '' : v),
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
      padding: const EdgeInsets.symmetric(vertical: 80), // py-20
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RtcRadius.brXxl,
        border: Border.all(color: Gray.c100),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.building2, size: 48, color: Gray.c300),
          const SizedBox(height: RtcSpace.s3),
          Text(
            'NO HAY CANCHAS',
            style: RtcType.sm.copyWith(
              fontWeight: FontWeight.w900,
              color: Gray.c400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _busqueda.isNotEmpty || _deporte.isNotEmpty
                ? 'Intenta con otros filtros'
                : 'Agrega tu primera cancha',
            style: RtcType.sm.copyWith(color: Gray.c400),
          ),
        ],
      ),
    );
  }

  Widget _fila(Court court) {
    return Container(
      padding: const EdgeInsets.all(RtcSpace.s4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RtcRadius.brXxl,
        border: Border.all(color: Gray.c100),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Gray.c50,
              borderRadius: RtcRadius.brXl,
            ),
            child: SportIcon(sport: court.sport, size: 24, color: Gray.c500),
          ),
          const SizedBox(width: RtcSpace.s4),
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
                      court.name,
                      style: RtcType.base.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Gray.c900,
                      ),
                    ),
                    _pildora(
                      court.isActive ? 'Activa' : 'Inactiva',
                      court.isActive ? Green.c50 : Red.c100,
                      court.isActive ? Green.c700 : Red.c600,
                    ),
                    _pildora(getSport(court.sport).label, Gray.c100, Gray.c600),
                  ],
                ),
                const SizedBox(height: 4),
                // `flex flex-wrap gap-3`: en la web ubicacion y calificacion
                // van en una fila que envuelve. En el ancho de un telefono
                // SIEMPRE envuelve — con los cuatro botones al lado no entran
                // juntas — asi que van apiladas, que es como se ve alli.
                Row(
                  children: [
                    const Icon(LucideIcons.mapPin, size: 12, color: Gray.c500),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        court.locationLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: RtcType.xs.copyWith(color: Gray.c500),
                      ),
                    ),
                  ],
                ),
                // `court.totalReviews > 0 && (...)`
                if (court.totalReviews > 0) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const RtcStar(
                        size: 12,
                        fill: Yellow.c400,
                        stroke: Yellow.c400,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${court.averageRating.toStringAsFixed(1)} '
                          '(${court.totalReviews} reseñas)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RtcType.xs.copyWith(color: Gray.c500),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: RtcSpace.s3),
          // El precio de la web es `hidden sm:block`: en telefono NO se ve, y
          // por eso los cuatro botones entran en esta misma fila.
          _acciones(court),
        ],
      ),
    );
  }

  /// Los cuatro botones redondos, separados por `gap-3`. Se arman en una lista
  /// y se intercalan los separadores: poner el SizedBox junto a cada boton
  /// dejaba un hueco doble cuando alguno no se dibujaba.
  Widget _acciones(Court court) {
    final botones = <Widget>[
      _redondo(
        LucideIcons.eye,
        Gray.c200,
        Colors.white,
        Gray.c400,
        () => rtcOpenCourt(court.id),
      ),
      // Editar cancha.
      _redondo(
        LucideIcons.pencil,
        Gray.c200,
        Colors.white,
        Gray.c400,
        () => rtcIrAlPanel('/dashboard/propetario/canchas/${court.id}/editar'),
      ),
      _redondo(
        LucideIcons.power,
        court.isActive
            ? const Color(0xFFFDE68A) // amber-200
            : const Color(0xFFBBF7D0), // green-200
        court.isActive
            ? const Color(0xFFFFFBEB) // amber-50
            : Green.c50,
        court.isActive
            ? const Color(0xFFF59E0B) // amber-500
            : const Color(0xFF22C55E), // green-500
        _cambiando == court.id ? null : () => _alternar(court),
      ),
      _redondo(
        LucideIcons.trash2,
        Red.c200,
        Red.c50,
        Red.c400,
        () => setState(() => _aEliminar = court),
      ),
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < botones.length; i++) ...[
          if (i > 0) const SizedBox(width: RtcSpace.s3),
          botones[i],
        ],
      ],
    );
  }

  Widget _pildora(String texto, Color fondo, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s2, vertical: 2),
      decoration: BoxDecoration(color: fondo, borderRadius: RtcRadius.brFull),
      child: Text(
        texto,
        style: RtcType.xs.copyWith(
          fontSize: 10,
          color: color,
          fontWeight: RtcType.bold,
        ),
      ),
    );
  }

  Widget _redondo(
    IconData icon,
    Color borde,
    Color fondo,
    Color color,
    VoidCallback? onTap,
  ) {
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fondo,
            shape: BoxShape.circle,
            border: Border.all(color: borde),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
      ),
    );
  }

  /// El `<Dialog>` de shadcn: velo negro al 80% y la tarjeta centrada.
  Widget _dialogoEliminar() {
    final court = _aEliminar!;
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: _eliminando ? null : () => setState(() => _aEliminar = null),
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.80)),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(RtcSpace.s4),
              child: RtcSheetUp(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    padding: const EdgeInsets.all(RtcSpace.s6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: RtcRadius.brXxl,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          '¿Eliminar cancha?',
                          style: RtcType.lg.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Gray.c900,
                          ),
                        ),
                        const SizedBox(height: RtcSpace.s4),
                        Container(
                          padding: const EdgeInsets.all(RtcSpace.s4),
                          decoration: BoxDecoration(
                            color: Red.c50,
                            borderRadius: RtcRadius.brXl,
                            border: Border.all(color: Red.c100),
                          ),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                const TextSpan(text: 'Vas a eliminar '),
                                TextSpan(
                                  text: court.name,
                                  style: const TextStyle(
                                    fontWeight: RtcType.bold,
                                  ),
                                ),
                                const TextSpan(
                                  text:
                                      '. Esta acción no se puede deshacer y se '
                                      'perderán todas las reservas asociadas.',
                                ),
                              ],
                            ),
                            style: RtcType.sm.copyWith(color: Red.c700),
                          ),
                        ),
                        const SizedBox(height: RtcSpace.s4),
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _eliminando
                                    ? null
                                    : () => setState(() => _aEliminar = null),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: RtcSpace.s3,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: RtcRadius.brXl,
                                    border: Border.all(color: Gray.c200),
                                  ),
                                  child: Text(
                                    'Cancelar',
                                    style: RtcType.sm.copyWith(
                                      fontWeight: RtcType.semibold,
                                      color: Gray.c600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: RtcSpace.s2),
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: _eliminando ? null : _eliminar,
                                child: Opacity(
                                  opacity: _eliminando ? 0.6 : 1,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: RtcSpace.s3,
                                    ),
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      color: Red.c600,
                                      borderRadius: RtcRadius.brXl,
                                    ),
                                    child: Text(
                                      _eliminando
                                          ? 'Eliminando...'
                                          : 'Eliminar',
                                      style: RtcType.sm.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
