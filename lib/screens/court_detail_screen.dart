import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/courts_api.dart';
import '../api/reviews_api.dart';
import '../api/rtc_api.dart';
import '../app/routes.dart';
import '../models/court.dart';
import '../models/review.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/booking_form.dart';
import '../widgets/court_location_map.dart';
import '../widgets/icons/sport_icon.dart';
import '../widgets/motion/rtc_motion.dart';
import '../widgets/remote_image.dart';
import '../widgets/review_card.dart';
import '../widgets/star_rating.dart';
import '../widgets/boton_favorito.dart';
import '../widgets/galeria_fotos.dart';

/// Port de `Frontend/src/app/(public)/canchas/[id]/page.tsx`, rama movil.
///
/// La web es una grilla `lg:grid-cols-3` donde la reserva va a la derecha y
/// pegada; en telefono las dos columnas se apilan y el `order-1` pone la
/// reserva ARRIBA de la galeria. Eso se respeta aca.
///
/// La pagina de la web se arma en el servidor con dos peticiones en paralelo
/// (`Promise.all`); aca se hace lo mismo en `initState`.
class CourtDetailScreen extends StatefulWidget {
  const CourtDetailScreen({
    super.key,
    required this.courtId,
    this.initialDate,
    this.initialStart,
  });

  final String courtId;

  /// Preseleccion que llega desde el buscador (`?date=`, `?start=`): la
  /// consume el formulario de reserva.
  final String? initialDate;
  final String? initialStart;

  @override
  State<CourtDetailScreen> createState() => _CourtDetailScreenState();
}

/// Alto de la foto de arriba, sin contar la barra de estado.
const _altoFoto = 340.0;

/// Cuanto sube la hoja blanca sobre la foto.
const _solape = 32.0;

/// Alto aproximado de la barra de reserva, para que el final del scroll no
/// quede tapado.
const _altoBarra = 96.0;

class _CourtDetailScreenState extends State<CourtDetailScreen> {
  /// El titulo de la seccion de reserva: el boton de abajo lleva hasta aca.
  final _reservaKey = GlobalKey();

  Court? _court;
  List<Review> _reviews = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // `Promise.all([getCourt(id), getReviews(id)])`.
      final results = await Future.wait([
        courtsApi.getById(widget.courtId),
        // Las resenas no deben tumbar la ficha si fallan: la web las pide sin
        // cache y devuelve [] cuando la respuesta no es ok.
        reviewsApi.byCourt(widget.courtId).catchError((_) => <Review>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _court = results[0] as Court;
        _reviews = results[1] as List<Review>;
        _loading = false;
      });
    } on RtcApiException catch (e) {
      if (!mounted) return;
      setState(() {
        // `notFound()` de la web.
        _error = e.notFound ? 'Cancha no encontrada' : e.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const _DetalleSkeleton();
    if (_error != null) return _errorState();

    final court = _court!;
    final sport = getSport(court.sport);
    // `court.photos?.length ? court.photos : [sport.img]`
    final photos = court.photos.isNotEmpty ? court.photos : [sport.image];

    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.only(bottom: _altoBarra + RtcSpace.s6),
          children: [
            _hero(court, photos),
            // La hoja blanca sube sobre la foto, como en las apps de reserva.
            Transform.translate(
              offset: const Offset(0, -_solape),
              child: _hoja(court, sport, photos),
            ),
          ],
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: _barraReserva(court)),
      ],
    );
  }

  /// Lleva al formulario de reserva desde la barra de abajo.
  void _irAReservar() {
    HapticFeedback.lightImpact();
    final destino = _reservaKey.currentContext;
    if (destino == null) return;
    Scrollable.ensureVisible(
      destino,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: 0.02,
    );
  }

  Widget _hoja(Court court, SportMeta sport, List<String> photos) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        RtcSpace.s5,
        RtcSpace.s6,
        RtcSpace.s5,
        RtcSpace.s4,
      ),
      decoration: const BoxDecoration(
        color: Fondo.app,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _titulo(court, sport),
          if (court.amenities.isNotEmpty) ...[
            const SizedBox(height: RtcSpace.s6),
            Row(
              children: [
                Expanded(child: _seccion('Lo que ofrece')),
                if (court.amenities.length > 4)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _verTodas(court.amenities),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Ver todas',
                        style: RtcType.sm.copyWith(
                          color: Gray.c500,
                          fontWeight: RtcType.medium,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: RtcSpace.s3),
            _instalaciones(court.amenities),
          ],
          const SizedBox(height: RtcSpace.s6),
          _seccion('Reserva tu turno', key: _reservaKey),
          const SizedBox(height: RtcSpace.s3),
          BookingForm(
            courtId: court.id,
            courtName: court.name,
            pricePerHour: court.pricePerHour,
            availability: court.availability,
            initialDate: widget.initialDate,
            initialStart: widget.initialStart,
          ),
          const SizedBox(height: RtcSpace.s3),
          _infoBox(),
          if (court.description != null &&
              court.description!.trim().isNotEmpty) ...[
            const SizedBox(height: RtcSpace.s6),
            _seccion('Sobre esta cancha'),
            const SizedBox(height: RtcSpace.s2),
            Text(
              court.description!,
              style: RtcType.sm.copyWith(color: Gray.c600, height: 1.5),
            ),
          ],
          if (photos.length > 1) ...[
            const SizedBox(height: RtcSpace.s6),
            _seccion('Fotos'),
            const SizedBox(height: RtcSpace.s3),
            _galeria(court, photos),
          ],
          const SizedBox(height: RtcSpace.s6),
          _seccion('Dónde queda'),
          const SizedBox(height: RtcSpace.s3),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: CourtLocationMap(
              coordinates: court.coordinates,
              city: court.city,
              address: court.address,
              seed: court.id,
              name: court.name,
            ),
          ),
          const SizedBox(height: RtcSpace.s6),
          _seccion(
            _reviews.isEmpty ? 'Reseñas' : 'Reseñas (${_reviews.length})',
          ),
          const SizedBox(height: RtcSpace.s3),
          _resenas(),
        ],
      ),
    );
  }

  Widget _seccion(String texto, {Key? key}) => Text(
    texto,
    key: key,
    style: RtcType.lg.copyWith(fontWeight: FontWeight.w700, color: Gray.c900),
  );

  /// Precio fijo abajo y el boton que lleva al formulario: el precio siempre
  /// a la vista, como la barra de "Book now" de las apps de reserva.
  Widget _barraReserva(Court court) {
    final abajo = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(
        RtcSpace.s5,
        RtcSpace.s4,
        RtcSpace.s5,
        RtcSpace.s4 + abajo,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Precio', style: RtcType.xs.copyWith(color: Gray.c500)),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '\$${formatCop(court.pricePerHour)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Gray.c900,
                      ),
                    ),
                    const TextSpan(text: ' /hora'),
                  ],
                ),
                style: RtcType.sm.copyWith(color: Gray.c500),
              ),
            ],
          ),
          const SizedBox(width: RtcSpace.s4),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _irAReservar,
              child: Container(
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Green.c600,
                  borderRadius: RtcRadius.brFull,
                ),
                child: Text(
                  'Reservar',
                  style: RtcType.base.copyWith(
                    fontWeight: RtcType.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── HERO ─────────────────────────────────────────────────────────────
  // La foto a todo el ancho, debajo de la barra de estado, con los botones
  // flotando encima.
  Widget _hero(Court court, List<String> photos) {
    final arriba = MediaQuery.paddingOf(context).top;
    return SizedBox(
      height: _altoFoto + arriba,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Tocar la foto abre todas a pantalla completa.
          GestureDetector(
            onTap: () =>
                abrirGaleria(context, fotos: photos, sport: court.sport),
            child: RemoteImage(url: photos.first, sport: court.sport),
          ),
          // Velo arriba para que la barra de estado y los botones se lean.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.center,
                colors: [
                  Colors.black.withValues(alpha: 0.45),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          Positioned(
            top: arriba + RtcSpace.s3,
            left: RtcSpace.s5,
            child: _botonFoto(
              icono: LucideIcons.arrowLeft,
              etiqueta: 'Volver',
              onTap: () async {
                final salio = await Navigator.of(context).maybePop();
                if (!salio) rtcNavigate('/empresas');
              },
            ),
          ),
          Positioned(
            top: arriba + RtcSpace.s3,
            right: RtcSpace.s5,
            child: BotonFavorito(courtId: court.id),
          ),
          if (photos.length > 1)
            Positioned(
              bottom: _solape + RtcSpace.s4,
              right: RtcSpace.s5,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: RtcSpace.s3,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: RtcRadius.brFull,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.images,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${photos.length} fotos',
                      style: RtcType.xs.copyWith(
                        color: Colors.white,
                        fontWeight: RtcType.semibold,
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

  Widget _botonFoto({
    required IconData icono,
    required String etiqueta,
    required VoidCallback onTap,
  }) {
    return Semantics(
      button: true,
      label: etiqueta,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              ),
              child: Icon(icono, size: 20, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _titulo(Court court, SportMeta sport) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                court.name,
                style: RtcType.xl2.copyWith(
                  fontSize: 24,
                  height: 1.2,
                  fontWeight: FontWeight.w800,
                  color: Gray.c900,
                ),
              ),
            ),
            const SizedBox(width: RtcSpace.s3),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: RtcSpace.s3,
                vertical: 6,
              ),
              decoration: const BoxDecoration(
                color: Lime.c400,
                borderRadius: RtcRadius.brFull,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SportIcon(sport: court.sport, size: 14, color: Gray.c900),
                  const SizedBox(width: 6),
                  Text(
                    sport.label,
                    style: RtcType.xs.copyWith(
                      color: Gray.c900,
                      fontWeight: RtcType.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: RtcSpace.s3),
        Row(
          children: [
            const Icon(LucideIcons.mapPin, size: 16, color: Gray.c500),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                [
                  court.address,
                  court.city,
                ].where((s) => s.isNotEmpty).join(', '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: RtcType.sm.copyWith(color: Gray.c600),
              ),
            ),
          ],
        ),
        if (court.totalReviews > 0) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              const RtcStar(size: 16, fill: Yellow.c400, stroke: Yellow.c400),
              const SizedBox(width: 6),
              Text(
                court.averageRating.toStringAsFixed(1),
                style: RtcType.sm.copyWith(
                  color: Gray.c900,
                  fontWeight: RtcType.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '· ${court.totalReviews} reseñas',
                style: RtcType.sm.copyWith(color: Gray.c500),
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ── GALERIA ──────────────────────────────────────────────────────────
  // `grid-cols-2 gap-2.5`, cada foto en aspect-[4/3] rounded-xl.
  Widget _galeria(Court court, List<String> photos) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: photos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 4 / 3,
      ),
      itemBuilder: (context, i) => GestureDetector(
        onTap: () => abrirGaleria(
          context,
          fotos: photos,
          inicial: i,
          sport: court.sport,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: RemoteImage(url: photos[i], sport: court.sport),
        ),
      ),
    );
  }

  // ── INSTALACIONES ────────────────────────────────────────────────────
  // Cuatro mosaicos parejos en fila; si hay mas, "Ver todas" abre la lista
  // completa.
  Widget _instalaciones(List<String> amenities) {
    final visibles = amenities.take(4).toList();
    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: i < visibles.length
                ? _mosaico(visibles[i])
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }

  Widget _mosaico(String amenidad) {
    return AspectRatio(
      aspectRatio: 0.92,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              amenityIcon(amenidad),
              size: 24,
              color: Gray.c900,
              semanticLabel: amenidad,
            ),
            const SizedBox(height: 10),
            Text(
              amenityCorta(amenidad),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: RtcType.xs.copyWith(
                color: Gray.c700,
                fontWeight: RtcType.medium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Todas las comodidades en una hoja, cuando no caben en la fila.
  void _verTodas(List<String> amenities) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (hoja) => SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(
            RtcSpace.s5,
            RtcSpace.s4,
            RtcSpace.s5,
            RtcSpace.s5,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Gray.c200,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: RtcSpace.s4),
              _seccion('Lo que ofrece'),
              const SizedBox(height: RtcSpace.s3),
              for (final a in amenities)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Fondo.app,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(amenityIcon(a), size: 20, color: Gray.c900),
                      ),
                      const SizedBox(width: RtcSpace.s3),
                      Expanded(
                        child: Text(
                          a,
                          style: RtcType.sm.copyWith(
                            color: Gray.c800,
                            fontWeight: RtcType.medium,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── RESENAS ──────────────────────────────────────────────────────────
  Widget _resenas() {
    if (_reviews.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: RtcSpace.s10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            const RtcStar(size: 40, fill: Gray.c300, stroke: Gray.c300),
            const SizedBox(height: RtcSpace.s3),
            Text(
              'Aún no hay reseñas',
              style: RtcType.base.copyWith(
                color: Gray.c500,
                fontWeight: RtcType.medium,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '¡Sé el primero en reservar y opinar!',
              style: RtcType.sm.copyWith(color: Gray.c400),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final r in _reviews)
          Padding(
            padding: const EdgeInsets.only(bottom: RtcSpace.s3),
            child: ReviewCard(review: r),
          ),
      ],
    );
  }

  // ── INFORMACION ──────────────────────────────────────────────────────
  // El recuadro gris que en la web va debajo del formulario de reserva.
  Widget _infoBox() {
    const filas = <(IconData, String)>[
      (LucideIcons.clock, 'Duración mínima: 1 hora'),
      (LucideIcons.users, 'Sin límite de jugadores'),
      (LucideIcons.shieldCheck, 'Cambio de horario hasta 24h antes'),
    ];

    return Container(
      padding: const EdgeInsets.all(RtcSpace.s4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'INFORMACIÓN',
            style: RtcType.xs.copyWith(
              color: Gray.c500,
              fontWeight: RtcType.semibold,
              letterSpacing: 0.4, // tracking-wide
            ),
          ),
          const SizedBox(height: 10),
          for (final (icon, label) in filas)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(icon, size: 16, color: Green.c600),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      label,
                      style: RtcType.sm.copyWith(color: Gray.c600),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// `notFound()` y los fallos de red. La web tira la pagina 404 de Next; aca
  /// se ofrece volver al listado, que es lo unico util desde un telefono.
  Widget _errorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(RtcSpace.s8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(LucideIcons.searchX, size: 40, color: Gray.c300),
            const SizedBox(height: RtcSpace.s3),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: RtcType.base.copyWith(
                color: Gray.c500,
                fontWeight: RtcType.medium,
              ),
            ),
            const SizedBox(height: RtcSpace.s4),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
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
                child: Text(
                  'Ver otras canchas',
                  style: RtcType.sm.copyWith(
                    color: Colors.white,
                    fontWeight: RtcType.bold,
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

/// Mientras cargan la cancha y sus resenas. La web no tiene este estado (arma
/// la pagina en el servidor y no la manda hasta tenerla); en la app la
/// peticion sale del telefono, asi que hace falta algo mientras tanto.
class _DetalleSkeleton extends StatelessWidget {
  const _DetalleSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(height: _altoFoto, color: Gray.c200),
        Padding(
          padding: const EdgeInsets.all(RtcSpace.s4),
          child: RtcSkeletonPulse(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _barra(120, 96),
                const SizedBox(height: RtcSpace.s8),
                _barra(20, 180),
                const SizedBox(height: RtcSpace.s3),
                _barra(16, double.infinity),
                const SizedBox(height: RtcSpace.s2),
                _barra(16, double.infinity),
                const SizedBox(height: RtcSpace.s8),
                _barra(240, double.infinity),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _barra(double height, double width) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      height: height,
      width: width,
      decoration: BoxDecoration(
        color: Fondo.suave,
        borderRadius: RtcRadius.brXl,
      ),
    ),
  );
}
