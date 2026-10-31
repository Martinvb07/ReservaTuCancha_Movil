import 'package:flutter/material.dart';
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
import '../widgets/section_heading.dart';
import '../widgets/star_rating.dart';

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

class _CourtDetailScreenState extends State<CourtDetailScreen> {
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

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        _hero(court, sport, photos.first),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            RtcSpace.s4,
            RtcSpace.s6,
            RtcSpace.s4,
            RtcSpace.s6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // `order-1`: en una sola columna la columna de reserva va
              // primero, y dentro de ella el formulario va antes del recuadro.
              BookingForm(
                courtId: court.id,
                courtName: court.name,
                pricePerHour: court.pricePerHour,
                availability: court.availability,
                initialDate: widget.initialDate,
                initialStart: widget.initialStart,
              ),
              const SizedBox(height: RtcSpace.s4),
              _infoBox(),
              const SizedBox(height: RtcSpace.s8),
              if (photos.length > 1) ...[
                _galeria(court, photos),
                const SizedBox(height: RtcSpace.s8),
              ],
              if (court.description != null &&
                  court.description!.trim().isNotEmpty) ...[
                const BarHeading(title: 'Sobre esta cancha'),
                const SizedBox(height: RtcSpace.s3),
                Text(
                  court.description!,
                  style: RtcType.base.copyWith(color: Gray.c600),
                ),
                const SizedBox(height: RtcSpace.s8),
              ],
              if (court.amenities.isNotEmpty) ...[
                const BarHeading(title: 'Instalaciones'),
                const SizedBox(height: RtcSpace.s3),
                _instalaciones(court.amenities),
                const SizedBox(height: RtcSpace.s8),
              ],
              const BarHeading(title: 'Dónde queda'),
              const SizedBox(height: RtcSpace.s3),
              CourtLocationMap(
                coordinates: court.coordinates,
                city: court.city,
                address: court.address,
                seed: court.id,
                name: court.name,
              ),
              const SizedBox(height: RtcSpace.s8),
              BarHeading(
                title: 'Reseñas',
                trailing: _reviews.isEmpty ? null : '(${_reviews.length})',
              ),
              const SizedBox(height: RtcSpace.s4),
              _resenas(),
            ],
          ),
        ),
      ],
    );
  }

  // ── HERO ─────────────────────────────────────────────────────────────
  // h-64 con la foto al 55% y el degradado que sube desde gray-900.
  Widget _hero(Court court, SportMeta sport, String photo) {
    return SizedBox(
      height: 256, // h-64
      child: Stack(
        fit: StackFit.expand,
        children: [
          ColoredBox(color: Gray.c900),
          Opacity(
            opacity: 0.55,
            child: RemoteImage(url: photo, sport: court.sport),
          ),
          // from-gray-900 via-gray-900/50 to-gray-900/20
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Gray.c900,
                  Gray.c900.withValues(alpha: 0.50),
                  Gray.c900.withValues(alpha: 0.20),
                ],
              ),
            ),
          ),
          // Volver a canchas
          Positioned(
            top: RtcSpace.s4,
            left: RtcSpace.s4,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => rtcNavigate('/empresas'),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14, // px-3.5
                  vertical: RtcSpace.s2,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),
                  borderRadius: RtcRadius.brFull,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.arrowLeft,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: RtcSpace.s2),
                    Text(
                      'Volver a canchas',
                      style: RtcType.sm.copyWith(
                        color: Colors.white,
                        fontWeight: RtcType.medium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: RtcSpace.s4,
            right: RtcSpace.s4,
            bottom: RtcSpace.s4,
            child: _heroTitulo(court, sport),
          ),
        ],
      ),
    );
  }

  Widget _heroTitulo(Court court, SportMeta sport) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // La pildora lima con el icono del deporte.
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: RtcSpace.s3,
                  vertical: 4,
                ),
                decoration: const BoxDecoration(
                  color: Lime.c400,
                  borderRadius: RtcRadius.brFull,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SportIcon(sport: court.sport, size: 14, color: Gray.c900),
                    const SizedBox(width: 6), // gap-1.5
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
              const SizedBox(height: 10), // mb-2.5
              Text(
                court.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RtcType.xl2.copyWith(
                  color: Colors.white,
                  fontWeight: RtcType.bold,
                ),
              ),
              const SizedBox(height: RtcSpace.s2),
              Row(
                children: [
                  const Icon(LucideIcons.mapPin, size: 16, color: Lime.c400),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      [
                        court.address,
                        court.city,
                      ].where((s) => s.isNotEmpty).join(', '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: RtcType.sm.copyWith(color: Gray.c200),
                    ),
                  ),
                ],
              ),
              if (court.totalReviews > 0) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const RtcStar(
                      size: 16,
                      fill: Yellow.c400,
                      stroke: Yellow.c400,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      court.averageRating.toStringAsFixed(1),
                      style: RtcType.sm.copyWith(
                        color: Gray.c200,
                        fontWeight: RtcType.semibold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '· ${court.totalReviews} reseñas',
                      style: RtcType.sm.copyWith(color: Gray.c400),
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
              '\$${formatCop(court.pricePerHour)}',
              style: RtcType.xl2.copyWith(
                color: Lime.c400,
                fontWeight: RtcType.bold,
              ),
            ),
            Text('COP / hora', style: RtcType.xs.copyWith(color: Gray.c400)),
          ],
        ),
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
      itemBuilder: (context, i) => ClipRRect(
        borderRadius: RtcRadius.brXl,
        child: RemoteImage(url: photos[i], sport: court.sport),
      ),
    );
  }

  // ── INSTALACIONES ────────────────────────────────────────────────────
  Widget _instalaciones(List<String> amenities) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: amenities.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        // p-2.5 con un icono de 32: la fila mide 52 de alto.
        mainAxisExtent: 52,
      ),
      itemBuilder: (context, i) {
        final a = amenities[i];
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: RtcRadius.brXl,
            border: Border.all(color: Gray.c100),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Green.c50,
                  borderRadius: RtcRadius.brLg,
                ),
                child: Icon(amenityIcon(a), size: 16, color: Green.c600),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  a,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RtcType.sm.copyWith(
                    color: Gray.c700,
                    fontWeight: RtcType.medium,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── RESENAS ──────────────────────────────────────────────────────────
  Widget _resenas() {
    if (_reviews.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: RtcSpace.s10),
        decoration: BoxDecoration(
          color: Gray.c50,
          borderRadius: RtcRadius.brXxl,
          border: Border.all(color: Gray.c100),
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
        color: Gray.c50,
        borderRadius: RtcRadius.brXxl,
        border: Border.all(color: Gray.c100),
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
        Container(height: 256, color: Gray.c900),
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
      decoration: BoxDecoration(color: Gray.c200, borderRadius: RtcRadius.brXl),
    ),
  );
}
