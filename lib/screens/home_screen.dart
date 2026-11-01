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
import '../widgets/mobile_search_trigger.dart';
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
    // Cuando el buscador sale de la pantalla por arriba, la barra de abajo
    // muestra la lupa a su lado: es el acople del buscador al navbar de la
    // web, pero abajo, donde llega el pulgar.
    _scroll.addListener(() {
      RtcNavScope.read(context).docked = _scroll.offset > _alturaHastaBuscador;
    });
  }

  @override
  void dispose() {
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
        top: RtcSpace.s4,
        bottom: kBottomNavEspacio + RtcSpace.s6,
      ),
      children: [
        const _Cabecera(),
        const SizedBox(height: RtcSpace.s5),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s5),
          child: MobileSearchTrigger(
            suave: true,
            onTap: () => showMobileSearchSheet(context),
          ),
        ),
        const SizedBox(height: RtcSpace.s5),
        _ChipsDeporte(
          elegido: _deporte,
          onElegir: (d) => setState(() => _deporte = d),
          cerca: _posicion != null,
          ubicando: _ubicando,
          onCerca: _alternarCerca,
        ),
        const SizedBox(height: RtcSpace.s6),
        _Titulo(
          'Canchas para hoy',
          accion: 'Ver todas',
          onAccion: () => rtcBuscarCanchas(sport: _deporte ?? ''),
        ),
        const SizedBox(height: RtcSpace.s3),
        if (_cargando)
          const _CarruselEsqueleto()
        else if (filtradas.isEmpty)
          _SinCanchas(deporte: _deporte)
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
        const SizedBox(height: RtcSpace.s5),
        const _BannerClubes(),
      ],
    );
  }
}

/// Lo que mide la pantalla desde arriba hasta el borde inferior del buscador:
/// padding, cabecera, espacio y la pildora. Pasado eso, se acopla abajo.
const _alturaHastaBuscador = 16.0 + 92 + 20 + 64;

// ── CABECERA ─────────────────────────────────────────────────────────────

class _Cabecera extends StatelessWidget {
  const _Cabecera();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¿Partido hoy?',
                  style: RtcType.sm.copyWith(
                    color: Green.c700,
                    fontWeight: RtcType.semibold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Encuentra tu\ncancha ideal',
                  style: RtcType.xl2.copyWith(
                    fontSize: 28,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: Gray.c900,
                    letterSpacing: -0.4,
                  ),
                ),
              ],
            ),
          ),
          const ModoToggle(clubes: false),
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

// ── CHIPS DE DEPORTE ─────────────────────────────────────────────────────

class _ChipsDeporte extends StatelessWidget {
  const _ChipsDeporte({
    required this.elegido,
    required this.onElegir,
    required this.cerca,
    required this.ubicando,
    required this.onCerca,
  });

  final String? elegido;
  final ValueChanged<String?> onElegir;

  /// "Cerca de mí" no es un deporte: ordena lo que se vea, con cualquier
  /// deporte elegido. Por eso se prende y apaga aparte.
  final bool cerca;
  final bool ubicando;
  final VoidCallback onCerca;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s5),
        children: [
          _Chip(
            etiqueta: 'Todas',
            activo: elegido == null,
            onTap: () => onElegir(null),
            icono: (c) => Icon(LucideIcons.layoutGrid, size: 22, color: c),
          ),
          const SizedBox(width: 10),
          _Chip(
            etiqueta: 'Cerca de mí',
            activo: cerca,
            onTap: onCerca,
            icono: (c) => ubicando
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: c),
                  )
                : Icon(LucideIcons.locateFixed, size: 22, color: c),
          ),
          for (final s in sports) ...[
            const SizedBox(width: 10),
            _Chip(
              etiqueta: s.label,
              activo: elegido == s.key,
              onTap: () => onElegir(s.key),
              icono: (c) => SportIcon(sport: s.key, size: 22, color: c),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.etiqueta,
    required this.activo,
    required this.onTap,
    required this.icono,
  });

  final String etiqueta;
  final bool activo;
  final VoidCallback onTap;
  final Widget Function(Color) icono;

  @override
  Widget build(BuildContext context) {
    final color = activo ? Colors.white : Gray.c800;
    return Semantics(
      button: true,
      selected: activo,
      child: RtcPressable(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          width: 84,
          decoration: BoxDecoration(
            color: activo ? Green.c600 : Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: activo
                ? [
                    cssShadow(
                      dy: 8,
                      blur: 18,
                      color: Green.c600.withValues(alpha: 0.30),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icono(color),
              const SizedBox(height: 6),
              Text(
                etiqueta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RtcType.xs.copyWith(
                  fontWeight: RtcType.semibold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
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
                  decoration: const BoxDecoration(
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
  const _SinCanchas({required this.deporte});

  final String? deporte;

  @override
  Widget build(BuildContext context) {
    final nombre = deporte == null ? null : getSport(deporte!).label;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: RtcSpace.s5),
      padding: const EdgeInsets.all(RtcSpace.s6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.searchX, size: 32, color: Gray.c300),
          const SizedBox(height: RtcSpace.s3),
          Text(
            rtcSinConexion.value
                ? 'No pudimos cargar las canchas. Revisa tu conexión.'
                : nombre == null
                ? 'Todavía no hay canchas publicadas'
                : 'No hay canchas de $nombre por ahora',
            textAlign: TextAlign.center,
            style: RtcType.sm.copyWith(
              fontWeight: RtcType.semibold,
              color: Gray.c700,
            ),
          ),
        ],
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
          color: Colors.white,
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
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Green.c700,
                              ),
                            ),
                            const TextSpan(text: ' /hora'),
                          ],
                        ),
                        style: RtcType.xs.copyWith(color: Gray.c500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Fondo.app,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: Gray.c700,
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
            color: Gray.c900,
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
                      style: RtcType.xs.copyWith(color: Gray.c500),
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
                    color: Gray.c900,
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
