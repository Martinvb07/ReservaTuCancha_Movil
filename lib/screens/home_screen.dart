import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/analytics_api.dart';
import '../api/courts_api.dart';
import '../api/rtc_api.dart';
import '../app/nav_state.dart';
import '../app/routes.dart';
import '../models/court.dart';
import '../theme/palette.dart';
import '../theme/shadows.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/icons/sport_icon.dart';
import '../widgets/mobile_search_sheet.dart';
import '../widgets/modo_toggle.dart';
import '../widgets/motion/rtc_motion.dart';
import '../widgets/remote_image.dart';
import '../widgets/rtc_bottom_nav.dart';
import '../data/preferencias.dart';
import '../widgets/boton_favorito.dart';
import '../data/ubicacion.dart';
import '../widgets/rtc_toast.dart';
import '../api/bookings_api.dart';
import '../models/fechas.dart';
import '../widgets/etiqueta_cupo.dart';
import 'court_detail_screen.dart' show tagFotoCancha;
import '../widgets/motion/rtc_pressable.dart';
import '../data/mis_turnos.dart';
import '../models/booking.dart';
import '../widgets/mi_turno.dart';
import '../widgets/icons/icono_deporte_3d.dart';
import '../widgets/foto_ciudad.dart';
import '../data/ciudades.dart';

/// Inicio de la app.
///
/// No es el landing de la web: arriba el saludo y el buscador, debajo los
/// deportes como chips que filtran el carrusel de canchas, y una lista de las
/// mejor calificadas. Lo informativo (como funciona, preguntas) vive en
/// Soporte y en Para clubes, dentro de la pestaña "Más".
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Court> _canchas = const [];
  bool _cargando = true;

  /// "Mi turno": el próximo turno del jugador y las canchas donde ya jugó.
  ResumenTurnos _turnos = const ResumenTurnos();
  bool _miTurno = false;
  final _canchasFrecuentes = <String, Court>{};
  final _cupoFrecuentes = <String, Disponibilidad>{};
  bool _turnosCargados = false;

  /// Junta las reservas guardadas en el teléfono con las del correo del
  /// jugador. Si el turno es hoy, el inicio abre directo en "Mi turno".
  Future<void> _cargarTurnos() async {
    final email = Preferencias.instance.jugador.email;
    final locales = await MisTurnos.instance.locales();
    var remotas = const <Booking>[];
    if (email.isNotEmpty) {
      try {
        remotas = await bookingsApi.search(guestEmail: email);
      } on RtcApiException {
        // Sin red se queda con las del teléfono.
      }
    }
    if (!mounted) return;
    final resumen = resumirTurnos(remotas, locales, ahoraEnBogota());
    final hoy = fechaIso(ahoraEnBogota());
    setState(() {
      _turnos = resumen;
      final p = resumen.proximo;
      if (!_turnosCargados && p != null && fechaIso(p.date) == hoy) {
        _miTurno = true;
      }
      if (!resumen.hayAlgo) _miTurno = false;
      _turnosCargados = true;
    });
    // Fotos y horario libre de hoy de las canchas a las que vuelve.
    for (final f in resumen.frecuentes) {
      try {
        if (!_canchasFrecuentes.containsKey(f.courtId)) {
          final ya = _canchas.where((c) => c.id == f.courtId);
          _canchasFrecuentes[f.courtId] = ya.isNotEmpty
              ? ya.first
              : await courtsApi.getById(f.courtId);
        }
        final cupo = await bookingsApi.disponibilidad(
          [f.courtId],
          hoy,
          desde: f.horaUsual,
        );
        if (cupo[f.courtId] != null) {
          _cupoFrecuentes[f.courtId] = cupo[f.courtId]!;
        }
      } on RtcApiException {
        // Una cancha que ya no existe o sin red: la tarjeta sale igual.
      }
      if (mounted) setState(() {});
    }
  }

  /// El deporte elegido en los chips; null es "Todas".
  String? _deporte;

  /// Con "Cerca de mí" activo: la posicion del jugador. El carrusel se ordena
  /// por distancia y cada tarjeta dice a cuanto queda.
  Position? _posicion;
  bool _ubicando = false;

  Future<void> _alternarCerca() async {
    if (_posicion != null) {
      setState(() => _posicion = null);
      return;
    }
    setState(() => _ubicando = true);
    final (pos, error) = await Ubicacion.obtener();
    if (!mounted) return;
    setState(() {
      _posicion = pos;
      _ubicando = false;
    });
    if (error != null) rtcToast(context, error, tipo: RtcToastTipo.error);
  }

  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _cargar();
    _cargarTurnos();
    MisTurnos.instance.cambios.addListener(_cargarTurnos);
    // Cuando el buscador sale de la pantalla por arriba, la barra de abajo
    // muestra la lupa a su lado: es el acople del buscador al navbar de la
    // web, pero abajo, donde llega el pulgar.
    _scroll.addListener(() {
      RtcNavScope.read(context).docked = _scroll.offset > _alturaHastaBuscador;
    });
  }

  @override
  void dispose() {
    MisTurnos.instance.cambios.removeListener(_cargarTurnos);
    _scroll.dispose();
    super.dispose();
  }

  /// Las destacadas de `/analytics/public` y, si vienen pocas, se completan
  /// con el listado general para que el carrusel no quede vacio.
  Future<void> _cargar() async {
    final stats = await analyticsApi.public();
    var canchas = stats.featuredCourts;
    if (canchas.length < 6) {
      try {
        final pagina = await courtsApi.getAll(limit: 12);
        final ids = canchas.map((c) => c.id).toSet();
        canchas = [
          ...canchas,
          ...pagina.data.where((c) => !ids.contains(c.id)),
        ];
      } on RtcApiException {
        // Con las destacadas alcanza.
      }
    }
    if (!mounted) return;
    setState(() {
      _canchas = canchas;
      _cargando = false;
    });
    // El cupo de hoy llega despues: las tarjetas se ven sin esperarlo.
    final cupo = await bookingsApi.disponibilidad(
      canchas.map((c) => c.id).toList(),
      fechaIso(ahoraEnBogota()),
    );
    if (mounted) setState(() => _cupo = cupo);
  }

  /// Turnos libres hoy por cancha.
  Map<String, Disponibilidad> _cupo = const {};

  List<Court> get _filtradas {
    final lista = _deporte == null
        ? [..._canchas]
        : _canchas.where((c) => c.sport == _deporte).toList();
    final pos = _posicion;
    if (pos != null) {
      // Las que no tienen coordenadas van al final.
      double d(Court c) => Ubicacion.km(pos, c) ?? double.infinity;
      lista.sort((a, b) => d(a).compareTo(d(b)));
    }
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    final filtradas = _filtradas;
    final populares = [..._canchas]
      ..sort((a, b) => b.averageRating.compareTo(a.averageRating));

    return RefreshIndicator(
      onRefresh: _cargar,
      color: Green.c600,
      child: _lista(filtradas, populares),
    );
  }

  Widget _lista(List<Court> filtradas, List<Court> populares) {
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.only(
        // La franja de arriba va pegada al borde, con su propio relleno.
        top: 0,
        bottom: kBottomNavEspacio + RtcSpace.s6,
      ),
      children: [
        _Franja(
          elegido: _deporte,
          // Una pestaña a la vez: elegir un deporte apaga "Cerca de mí".
          onElegir: (d) => setState(() {
            _deporte = d;
            _miTurno = false;
            _posicion = null;
          }),
          cerca: _posicion != null && !_miTurno,
          ubicando: _ubicando,
          onCerca: () {
            setState(() {
              _miTurno = false;
              _deporte = null;
            });
            if (_posicion == null) _alternarCerca();
          },
          conMiTurno: _turnos.hayAlgo,
          miTurnoActivo: _miTurno,
          avisoMiTurno: _turnos.proximo != null,
          onMiTurno: () => setState(() => _miTurno = true),
        ),
        const SizedBox(height: RtcSpace.s6),
        if (_miTurno) ...[
          MiTurnoSeccion(
            resumen: _turnos,
            canchas: _canchasFrecuentes,
            cupo: _cupoFrecuentes,
          ),
          const SizedBox(height: RtcSpace.s8),
          const _BannerClubes(),
        ] else ...[
          _Titulo(
            'Canchas para hoy',
            accion: 'Ver todas',
            onAccion: () => rtcBuscarCanchas(sport: _deporte ?? ''),
          ),
          const SizedBox(height: RtcSpace.s3),
          if (_cargando)
            const _CarruselEsqueleto()
          else if (filtradas.isEmpty)
            _SinCanchas(
              deporte: _deporte,
              onVerTodas: () => setState(() => _deporte = null),
            )
          else
            _Carrusel(canchas: filtradas, posicion: _posicion, cupo: _cupo),
          // Las favoritas, si hay alguna entre las canchas cargadas.
          ValueListenableBuilder<Set<String>>(
            valueListenable: Preferencias.instance.favoritos,
            builder: (context, favs, _) {
              final favoritas = _canchas
                  .where((c) => favs.contains(c.id))
                  .toList();
              if (favoritas.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: RtcSpace.s8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Titulo('Tus favoritas'),
                    const SizedBox(height: RtcSpace.s3),
                    for (final c in favoritas.take(3))
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          RtcSpace.s5,
                          0,
                          RtcSpace.s5,
                          RtcSpace.s3,
                        ),
                        child: _FilaCancha(court: c),
                      ),
                  ],
                ),
              );
            },
          ),
          if (populares.isNotEmpty) ...[
            const SizedBox(height: RtcSpace.s8),
            _Titulo(
              'Mejor calificadas',
              accion: 'Ver todas',
              onAccion: () => rtcNavigate('/empresas'),
            ),
            const SizedBox(height: RtcSpace.s3),
            for (var i = 0; i < populares.length && i < 4; i++)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  RtcSpace.s5,
                  0,
                  RtcSpace.s5,
                  RtcSpace.s3,
                ),
                child: RtcFadeUp(
                  delay: Duration(milliseconds: i * 60),
                  child: _FilaCancha(court: populares[i]),
                ),
              ),
          ],
          const SizedBox(height: RtcSpace.s8),
          const _ExploraCiudades(),
          const SizedBox(height: RtcSpace.s5),
          const _BannerClubes(),
        ],
      ],
    );
  }
}

/// Lo que mide la pantalla desde arriba hasta el borde inferior del buscador:
/// padding, cabecera, espacio y la pildora. Pasado eso, se acopla abajo.
const _alturaHastaBuscador = 12.0 + 48 + 14 + 56;

// ── FRANJA DE ARRIBA ─────────────────────────────────────────────────────
// La misma de la web: marca, la píldora "Empieza tu búsqueda" y las
// pestañas de deporte con sus íconos 3D y un subrayado que se desliza.

class _Franja extends StatelessWidget {
  const _Franja({
    required this.elegido,
    required this.onElegir,
    required this.cerca,
    required this.ubicando,
    required this.onCerca,
    required this.conMiTurno,
    required this.miTurnoActivo,
    required this.avisoMiTurno,
    required this.onMiTurno,
  });

  final String? elegido;
  final ValueChanged<String?> onElegir;
  final bool cerca;
  final bool ubicando;
  final VoidCallback onCerca;
  final bool conMiTurno;
  final bool miTurnoActivo;
  final bool avisoMiTurno;
  final VoidCallback onMiTurno;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Superficie.tarjeta, Fondo.app],
        ),
        border: Border(bottom: BorderSide(color: Gray.c100)),
      ),
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Marca + cambio a Para clubes
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s5),
            child: SizedBox(
              height: 48,
              child: Row(
                children: [
                  Image.asset('assets/images/logo.png', width: 38, height: 38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text.rich(
                      const TextSpan(
                        children: [
                          TextSpan(text: 'Reserva'),
                          TextSpan(
                            text: 'TuCancha',
                            style: TextStyle(color: Green.c600),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RtcType.lg.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Gray.c900,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const ModoToggle(clubes: false),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Titular: dice qué es la app antes del buscador (igual que la web).
          RtcFadeUp(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    const TextSpan(
                      children: [
                        TextSpan(text: 'Reserva tu cancha '),
                        TextSpan(
                          text: 'en segundos',
                          style: TextStyle(color: Green.c600),
                        ),
                      ],
                    ),
                    style: RtcType.xl2.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Gray.c900,
                      letterSpacing: -0.4,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Elige el horario, paga en línea y a jugar.',
                    style: RtcType.sm.copyWith(color: Gray.c500),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s5),
            child: _PildoraBuscar(onTap: () => showMobileSearchSheet(context)),
          ),
          const SizedBox(height: 6),
          _Pestanas(
            activa: miTurnoActivo
                ? '__mi_turno__'
                : cerca
                ? 'cerca'
                : (elegido ?? ''),
            opciones: [
              if (conMiTurno)
                _Opcion(
                  '__mi_turno__',
                  'Mi turno',
                  _IconoMiTurno(aviso: avisoMiTurno && !miTurnoActivo),
                  onMiTurno,
                ),
              _Opcion(
                '',
                'Todo',
                const IconoDeporte3D(clave: '', size: 30),
                () => onElegir(null),
              ),
              for (final s in sports)
                _Opcion(
                  s.key,
                  s.key == 'voley_playa' ? 'Vóley playa' : s.label,
                  IconoDeporte3D(clave: s.key, size: 30),
                  () => onElegir(s.key),
                ),
              _Opcion(
                'cerca',
                'Cerca de mí',
                ubicando
                    ? SizedBox(
                        width: 30,
                        height: 30,
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Gray.c500,
                          ),
                        ),
                      )
                    : const IconoDeporte3D(clave: 'cerca', size: 30),
                onCerca,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Empieza tu búsqueda": abre el buscador completo.
class _PildoraBuscar extends StatelessWidget {
  const _PildoraBuscar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Buscar canchas',
      child: RtcPressable(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: Superficie.tarjeta,
            borderRadius: RtcRadius.brFull,
            border: Border.all(color: Gray.c200),
            boxShadow: [
              cssShadow(
                dy: 3,
                blur: 12,
                color: Colors.black.withValues(alpha: 0.10),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.search, size: 18, color: Gray.c900),
              const SizedBox(width: 10),
              Text(
                'Empieza tu búsqueda',
                style: RtcType.base.copyWith(
                  fontWeight: RtcType.semibold,
                  color: Gray.c900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Opcion {
  const _Opcion(this.clave, this.etiqueta, this.icono, this.onTap);

  final String clave;
  final String etiqueta;
  final Widget icono;
  final VoidCallback onTap;
}

/// Fila de pestañas con un solo subrayado que viaja a la activa.
class _Pestanas extends StatefulWidget {
  const _Pestanas({required this.activa, required this.opciones});

  final String activa;
  final List<_Opcion> opciones;

  @override
  State<_Pestanas> createState() => _PestanasState();
}

class _PestanasState extends State<_Pestanas> {
  final _llaves = <String, GlobalKey>{};
  final _filaKey = GlobalKey();
  double? _left;
  double _width = 0;

  GlobalKey _llave(String clave) => _llaves.putIfAbsent(clave, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _medir(llevar: false));
  }

  @override
  void didUpdateWidget(_Pestanas old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _medir(llevar: old.activa != widget.activa),
    );
  }

  void _medir({required bool llevar}) {
    if (!mounted) return;
    final ctx = _llaves[widget.activa]?.currentContext;
    final fila = _filaKey.currentContext?.findRenderObject() as RenderBox?;
    final caja = ctx?.findRenderObject() as RenderBox?;
    if (ctx == null || fila == null || caja == null || !caja.hasSize) return;
    final x = caja.localToGlobal(Offset.zero, ancestor: fila).dx;
    if (x != _left || caja.size.width != _width) {
      setState(() {
        _left = x;
        _width = caja.size.width;
      });
    }
    // La activa a la vista, si quedó escondida al costado.
    if (llevar) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s5 - 6),
      child: Stack(
        key: _filaKey,
        children: [
          Row(
            children: [
              for (final o in widget.opciones)
                _Pestana(
                  key: _llave(o.clave),
                  opcion: o,
                  activa: o.clave == widget.activa,
                ),
            ],
          ),
          if (_left != null)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              left: _left! + 6,
              width: (_width - 12).clamp(0, double.infinity),
              bottom: 0,
              height: 3,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Gray.c900,
                  borderRadius: RtcRadius.brFull,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pestana extends StatelessWidget {
  const _Pestana({super.key, required this.opcion, required this.activa});

  final _Opcion opcion;
  final bool activa;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: activa,
      label: opcion.etiqueta,
      child: RtcPressable(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: () {
          HapticFeedback.selectionClick();
          opcion.onTap();
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedScale(
                scale: activa ? 1.1 : 1,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutBack,
                child: AnimatedOpacity(
                  opacity: activa ? 1 : 0.75,
                  duration: const Duration(milliseconds: 220),
                  child: opcion.icono,
                ),
              ),
              const SizedBox(width: 8),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                style: RtcType.sm.copyWith(
                  fontWeight: RtcType.semibold,
                  color: activa ? Gray.c900 : Gray.c500,
                ),
                child: Text(opcion.etiqueta),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ícono de "Mi turno": boleto en un círculo lima, con punto rojo si hay
/// un turno pendiente.
class _IconoMiTurno extends StatelessWidget {
  const _IconoMiTurno({required this.aviso});

  final bool aviso;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Lime.c400,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              LucideIcons.ticket,
              size: 16,
              color: GrisFijo.c900,
            ),
          ),
          if (aviso)
            Positioned(
              top: -1,
              right: -1,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Red.c500,
                  shape: BoxShape.circle,
                  border: Border.all(color: Superficie.tarjeta, width: 1.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto, {this.accion, this.onAccion});

  final String texto;
  final String? accion;
  final VoidCallback? onAccion;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              texto,
              style: RtcType.lg.copyWith(
                fontWeight: FontWeight.w700,
                color: Gray.c900,
              ),
            ),
          ),
          if (accion != null)
            RtcPressable(
              behavior: HitTestBehavior.opaque,
              onTap: onAccion,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  accion!,
                  style: RtcType.sm.copyWith(
                    color: Gray.c500,
                    fontWeight: RtcType.medium,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── CARRUSEL ─────────────────────────────────────────────────────────────

const _altoCarrusel = 400.0;

class _Carrusel extends StatefulWidget {
  const _Carrusel({required this.canchas, this.posicion, this.cupo = const {}});

  final List<Court> canchas;
  final Position? posicion;
  final Map<String, Disponibilidad> cupo;

  @override
  State<_Carrusel> createState() => _CarruselState();
}

class _CarruselState extends State<_Carrusel> {
  final _controller = PageController(viewportFraction: 0.82);
  double _pagina = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(
      () => setState(() => _pagina = _controller.page ?? 0),
    );
  }

  @override
  void didUpdateWidget(_Carrusel old) {
    super.didUpdateWidget(old);
    // Al cambiar de deporte el carrusel vuelve al principio.
    if (old.canchas != widget.canchas && _controller.hasClients) {
      _controller.jumpToPage(0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _altoCarrusel,
      child: PageView.builder(
        controller: _controller,
        padEnds: false,
        itemCount: widget.canchas.length,
        itemBuilder: (context, i) {
          // La tarjeta que no esta al frente se achica un poco, para que el
          // carrusel se lea como una pila.
          final distancia = (_pagina - i).abs().clamp(0.0, 1.0);
          return Padding(
            padding: EdgeInsets.only(
              left: i == 0 ? RtcSpace.s5 : RtcSpace.s2,
              right: RtcSpace.s2,
            ),
            child: Transform.scale(
              scale: 1 - distancia * 0.06,
              alignment: i < _pagina
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: _TarjetaGrande(
                court: widget.canchas[i],
                posicion: widget.posicion,
                cupo: widget.cupo[widget.canchas[i].id],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TarjetaGrande extends StatelessWidget {
  const _TarjetaGrande({required this.court, this.posicion, this.cupo});

  final Court court;
  final Position? posicion;
  final Disponibilidad? cupo;

  String _ubicacionTexto() {
    final pos = posicion;
    final km = pos == null ? null : Ubicacion.km(pos, court);
    return km == null
        ? court.locationLabel
        : '${court.city} · ${textoDistancia(km)}';
  }

  @override
  Widget build(BuildContext context) {
    final sport = getSport(court.sport);
    final foto = court.photos.isNotEmpty ? court.photos.first : sport.image;
    return RtcPressable(
      onTap: () => rtcOpenCourt(court.id, foto: foto),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            cssShadow(
              dy: 14,
              blur: 30,
              color: Colors.black.withValues(alpha: 0.14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Hero(
                tag: tagFotoCancha(court.id),
                child: RemoteImage(url: foto, sport: court.sport),
              ),
              // Velo arriba para el nombre y abajo para los botones.
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.35, 0.65, 1],
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.55),
                    ],
                  ),
                ),
              ),
              Positioned(
                left: RtcSpace.s5,
                right: RtcSpace.s5,
                top: RtcSpace.s5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _Vidrio(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SportIcon(
                                sport: court.sport,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                sport.label,
                                style: RtcType.xs.copyWith(
                                  color: Colors.white,
                                  fontWeight: RtcType.semibold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        if (court.averageRating > 0)
                          _Vidrio(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  LucideIcons.star,
                                  size: 13,
                                  color: Lime.c400,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  court.averageRating.toStringAsFixed(1),
                                  style: RtcType.xs.copyWith(
                                    color: Colors.white,
                                    fontWeight: RtcType.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: RtcSpace.s3),
                    Text(
                      court.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: RtcType.xl2.copyWith(
                        fontSize: 24,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.mapPin,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            _ubicacionTexto(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RtcType.sm.copyWith(
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (cupo != null) ...[
                      const SizedBox(height: 10),
                      EtiquetaCupo(disponibilidad: cupo!, sobreFoto: true),
                    ],
                  ],
                ),
              ),
              Positioned(
                left: RtcSpace.s4,
                right: RtcSpace.s4,
                bottom: RtcSpace.s4,
                child: Row(
                  children: [
                    Expanded(
                      child: _Vidrio(
                        padding: const EdgeInsets.symmetric(
                          horizontal: RtcSpace.s5,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Reservar',
                              style: RtcType.sm.copyWith(
                                color: Colors.white,
                                fontWeight: RtcType.semibold,
                              ),
                            ),
                            const Spacer(),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '\$${formatCop(court.pricePerHour)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const TextSpan(text: ' /h'),
                                ],
                              ),
                              style: RtcType.sm.copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    BotonFavorito(courtId: court.id, tamano: 50),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pildora de vidrio esmerilado sobre la foto.
class _Vidrio extends StatelessWidget {
  const _Vidrio({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: RtcRadius.brFull,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: RtcRadius.brFull,
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CarruselEsqueleto extends StatelessWidget {
  const _CarruselEsqueleto();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _altoCarrusel,
      child: Padding(
        padding: const EdgeInsets.only(left: RtcSpace.s5),
        child: Row(
          children: [
            Expanded(
              child: RtcSkeletonPulse(
                child: Container(
                  decoration: BoxDecoration(
                    color: Fondo.suave,
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
              ),
            ),
            const SizedBox(width: RtcSpace.s3),
            SizedBox(
              width: 40,
              child: RtcSkeletonPulse(
                child: Container(
                  decoration: BoxDecoration(
                    color: Fondo.suave,
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(32),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SinCanchas extends StatelessWidget {
  const _SinCanchas({required this.deporte, required this.onVerTodas});

  final String? deporte;

  /// Vuelve a la pestaña "Todo" cuando el deporte elegido no tiene canchas.
  final VoidCallback onVerTodas;

  @override
  Widget build(BuildContext context) {
    final nombre = deporte == null ? null : getSport(deporte!).label;
    final sinConexion = rtcSinConexion.value;
    return RtcFadeUp(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: RtcSpace.s5),
        padding: const EdgeInsets.symmetric(
          horizontal: RtcSpace.s6,
          vertical: RtcSpace.s8,
        ),
        decoration: BoxDecoration(
          color: Superficie.tarjeta,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sinConexion ? Red.c50 : Green.c50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                sinConexion ? LucideIcons.wifiOff : LucideIcons.searchX,
                size: 24,
                color: sinConexion ? Red.c500 : Green.c600,
              ),
            ),
            const SizedBox(height: RtcSpace.s4),
            Text(
              sinConexion
                  ? 'No pudimos cargar las canchas'
                  : nombre == null
                  ? 'Pronto verás canchas aquí'
                  : 'Aún no hay canchas de $nombre',
              textAlign: TextAlign.center,
              style: RtcType.base.copyWith(
                fontWeight: RtcType.bold,
                color: Gray.c900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sinConexion
                  ? 'Revisa tu conexión e inténtalo otra vez.'
                  : nombre == null
                  ? 'Estamos sumando los primeros clubes. Vuelve en unos días.'
                  : 'Prueba con otro deporte o mira todas las canchas.',
              textAlign: TextAlign.center,
              style: RtcType.sm.copyWith(color: Gray.c500),
            ),
            if (!sinConexion && nombre != null) ...[
              const SizedBox(height: RtcSpace.s5),
              RtcPressable(
                onTap: onVerTodas,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: RtcSpace.s5,
                    vertical: 10,
                  ),
                  decoration: const BoxDecoration(
                    color: GrisFijo.c900,
                    borderRadius: RtcRadius.brFull,
                  ),
                  child: Text(
                    'Ver todas',
                    style: RtcType.sm.copyWith(
                      fontWeight: RtcType.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── LISTA COMPACTA ───────────────────────────────────────────────────────

class _FilaCancha extends StatelessWidget {
  const _FilaCancha({required this.court});

  final Court court;

  @override
  Widget build(BuildContext context) {
    final sport = getSport(court.sport);
    final foto = court.photos.isNotEmpty ? court.photos.first : sport.image;
    return RtcPressable(
      onTap: () => rtcOpenCourt(court.id),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Superficie.tarjeta,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: 84,
                height: 84,
                child: RemoteImage(url: foto, sport: court.sport),
              ),
            ),
            const SizedBox(width: RtcSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    court.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RtcType.base.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Gray.c900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${sport.label} · ${court.city}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RtcType.xs.copyWith(color: Gray.c500),
                  ),
                  const SizedBox(height: RtcSpace.s2),
                  Row(
                    children: [
                      if (court.averageRating > 0) ...[
                        const Icon(
                          LucideIcons.star,
                          size: 13,
                          color: Amber.c500,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          court.averageRating.toStringAsFixed(1),
                          style: RtcType.xs.copyWith(
                            fontWeight: RtcType.bold,
                            color: Gray.c800,
                          ),
                        ),
                        const SizedBox(width: RtcSpace.s3),
                      ],
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '\$${formatCop(court.pricePerHour)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Green.c700,
                              ),
                            ),
                            const TextSpan(text: ' /hora'),
                          ],
                        ),
                        style: RtcType.xs.copyWith(color: GrisFijo.c500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Fondo.app,
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.chevronRight, size: 18, color: Gray.c700),
            ),
          ],
        ),
      ),
    );
  }
}

// ── EXPLORA POR CIUDAD ───────────────────────────────────────────────────
// Cada ciudad con su foto y cuántas canchas tiene (el total sale de la API,
// una consulta chica por ciudad); al tocarla, Canchas ya filtrado. Las
// ciudades sin canchas no salen.

class _ExploraCiudades extends StatefulWidget {
  const _ExploraCiudades();

  @override
  State<_ExploraCiudades> createState() => _ExploraCiudadesState();
}

class _ExploraCiudadesState extends State<_ExploraCiudades> {
  List<(String, int, String)>? _ciudades;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final lista = await Future.wait(
      kCiudades.map((ciudad) async {
        try {
          final p = await courtsApi.getAll(city: ciudad, limit: 1);
          final c = p.data.isEmpty ? null : p.data.first;
          final foto = c == null
              ? ''
              : (c.photos.isNotEmpty
                    ? c.photos.first
                    : getSport(c.sport).image);
          return (ciudad, p.total, foto);
        } on RtcApiException {
          return (ciudad, 0, '');
        }
      }),
    );
    if (!mounted) return;
    setState(() {
      _ciudades = lista.where((c) => c.$2 > 0).toList()
        ..sort((a, b) => b.$2.compareTo(a.$2));
    });
  }

  @override
  Widget build(BuildContext context) {
    final ciudades = _ciudades;
    if (ciudades != null && ciudades.isEmpty) return const SizedBox.shrink();
    final items = ciudades ?? const <(String, int, String)>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Titulo(
          'Explora por ciudad',
          accion: 'Ver todas',
          onAccion: () => rtcNavigate('/empresas'),
        ),
        const SizedBox(height: RtcSpace.s3),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s5),
          child: ciudades == null
              ? const SizedBox(height: 180)
              : GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: RtcSpace.s3,
                  crossAxisSpacing: RtcSpace.s3,
                  childAspectRatio: 0.92,
                  padding: EdgeInsets.zero,
                  children: [
                    for (final c in items)
                      _TarjetaCiudad(ciudad: c.$1, total: c.$2, respaldo: c.$3),
                  ],
                ),
        ),
      ],
    );
  }
}

class _TarjetaCiudad extends StatelessWidget {
  const _TarjetaCiudad({
    required this.ciudad,
    required this.total,
    required this.respaldo,
  });

  final String ciudad;
  final int total;
  final String respaldo;

  @override
  Widget build(BuildContext context) {
    return RtcPressable(
      onTap: () => rtcBuscarCanchas(city: ciudad),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Superficie.tarjeta,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: ColoredBox(
                  color: Fondo.suave,
                  child: FotoCiudad(ciudad: ciudad, respaldo: respaldo),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 10, 6, 4),
              child: Row(
                children: [
                  Icon(LucideIcons.mapPin, size: 14, color: Green.c600),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      ciudad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RtcType.sm.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Gray.c900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 6, 4),
              child: Text(
                '$total ${total == 1 ? 'cancha' : 'canchas'}',
                style: RtcType.xs.copyWith(color: Gray.c500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── BANNER CLUBES ────────────────────────────────────────────────────────

class _BannerClubes extends StatelessWidget {
  const _BannerClubes();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s5),
      child: RtcPressable(
        onTap: () => rtcNavigate('/para-clubes'),
        child: Container(
          padding: const EdgeInsets.all(RtcSpace.s5),
          decoration: BoxDecoration(
            color: GrisFijo.c900,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿Tienes una cancha?',
                      style: RtcType.base.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Recibe reservas pagadas en línea, sin mensualidad.',
                      style: RtcType.xs.copyWith(color: GrisFijo.c500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: RtcSpace.s3),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: RtcSpace.s4,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Lime.c400,
                  borderRadius: RtcRadius.brFull,
                ),
                child: Text(
                  'Publicar',
                  style: RtcType.sm.copyWith(
                    fontWeight: RtcType.bold,
                    color: GrisFijo.c900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
