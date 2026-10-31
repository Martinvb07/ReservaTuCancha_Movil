import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/analytics_api.dart';
import '../models/court.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/court_card.dart';
import '../widgets/mobile_search_sheet.dart';
import '../widgets/mobile_search_trigger.dart';
import '../widgets/motion/rtc_motion.dart';

import '../app/nav_state.dart';
import '../widgets/rtc_navbar.dart' show kDockTrigger, kNavHeight;
import '../widgets/remote_image.dart';
import '../widgets/section_heading.dart';
import '../app/routes.dart';

/// Port de `Frontend/src/app/(public)/HomeClient.tsx`, rama movil.
///
/// Solo se porta lo que la web muestra en telefono: donde el markup dice
/// `hidden lg:block` (el buscador grande) va la pildora, y las grillas
/// `md:grid-cols-*` quedan en una columna.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static const heroImage =
      'https://www.unila.edu.mx/wp-content/uploads/2025/09/los-5-deportes-mas-populares-del-mundo.jpg';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// `SEARCH_ANCHOR_ID` de la web: el bloque del buscador dentro del hero.
  /// Aca no hay ids, asi que se mide con una key.
  final _anchorKey = GlobalKey();

  /// Distancia del borde inferior del buscador al tope del contenido.
  double? _anchorBottom;

  /// `getPublicStats()` de la web: alimenta las canchas destacadas. Si falla
  /// cae a los valores por defecto y la seccion simplemente no aparece, igual
  /// que cuando el fetch del server component se cae.
  PublicStats _stats = PublicStats.fallback;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await analyticsApi.public();
    if (!mounted) return;
    setState(() => _stats = stats);
  }

  /// Port de `useSearchDock`: docked cuando el borde inferior del buscador ya
  /// paso por encima del navbar. En la web es `rect.bottom <= TRIGGER`; aca
  /// hay que sumarle la barra de estado, que en el navegador no cuenta.
  ///
  /// Se mide con `getOffsetToReveal`, que da el offset de scroll al que el
  /// buscador quedaria pegado al tope del viewport — o sea, su posicion dentro
  /// del contenido. No sirve `localToGlobal`: dentro de un viewport devuelve la
  /// posicion en el contenido y no en pantalla, asi que no cambia al scrollear.
  ///
  /// Se refresca mientras el buscador sigue vivo y despues se usa el ultimo
  /// valor, porque el ListView destruye los hijos que salen de pantalla.
  void _readDock(double pixels) {
    final box = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.attached && box.hasSize) {
      final viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport != null) {
        _anchorBottom =
            viewport.getOffsetToReveal(box, 0).offset + box.size.height;
      }
    }
    if (_anchorBottom == null) return;

    // El viewport ya arranca DEBAJO del navbar, asi que del TRIGGER de la web
    // solo queda su margen de 6px.
    const trigger = kDockTrigger - kNavHeight;
    // El dock vive en el header, que es unico para toda la app.
    RtcNavScope.read(context).docked = _anchorBottom! - pixels <= trigger;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        _readDock(n.metrics.pixels);
        return false;
      },
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Hero(image: HomeScreen.heroImage, anchorKey: _anchorKey),
          const _ServiciosSection(),
          const _DeportesSection(),
          if (_stats.featuredCourts.isNotEmpty)
            _DestacadasSection(courts: _stats.featuredCourts),
          const _PorQueSection(),
          const _FaqSection(),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// HERO — h-[500px] con la foto, el velo negro al 55% y la pildora de busqueda
// ───────────────────────────────────────────────────────────────────────────

class _Hero extends StatelessWidget {
  const _Hero({required this.image, required this.anchorKey});

  final String image;

  /// Se mide para saber cuando el buscador se acopla al navbar.
  final GlobalKey anchorKey;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 500,
      child: Stack(
        fit: StackFit.expand,
        children: [
          RemoteImage(url: image, placeholderColor: Gray.c800),
          // bg-black/55
          ColoredBox(color: Colors.black.withValues(alpha: 0.55)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'PARTIDO HOY?',
                    textAlign: TextAlign.center,
                    style: RtcType.xs.copyWith(
                      color: Lime.c400,
                      fontWeight: RtcType.semibold,
                      letterSpacing: 0.5, // tracking-wide
                    ),
                  ),
                  const SizedBox(height: RtcSpace.s4),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'RESERVA CANCHAS DEPORTIVAS O '),
                        TextSpan(
                          text: 'UNETE A EMOCIONANTES EVENTOS',
                          style: const TextStyle(color: Lime.c400),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: RtcType.xl2.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900, // font-black
                      height: 1.25, // leading-tight
                    ),
                  ),
                  const SizedBox(height: RtcSpace.s4),
                  Text(
                    'Conectamos jugadores con clubes deportivos independientes '
                    'de Colombia. Tu eliges donde jugar; nosotros ponemos la '
                    'reserva y el pago seguro.',
                    textAlign: TextAlign.center,
                    style: RtcType.xs.copyWith(color: Gray.c200),
                  ),
                  const SizedBox(height: RtcSpace.s4),
                  MobileSearchTrigger(
                    key: anchorKey,
                    onTap: () => showMobileSearchSheet(context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// SERVICIOS — los 4 pasos y el collage de fotos
// ───────────────────────────────────────────────────────────────────────────

const _steps = <(int, IconData, String)>[
  (1, LucideIcons.search, 'Busca experiencias'),
  (2, LucideIcons.calendar, 'Elige Fecha'),
  (3, LucideIcons.creditCard, 'Paga Online'),
  (4, LucideIcons.smile, 'Diviertete'),
];

class _ServiciosSection extends StatelessWidget {
  const _ServiciosSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s4,
        vertical: RtcSpace.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
            eyebrow: 'Servicios',
            title: 'ENCUENTRA TU LUGAR EN LA CANCHA',
            subtitle:
                'Canchas de clubes verificados, reservas en segundos y '
                'eventos que unen a la comunidad.',
          ),
          const SizedBox(height: RtcSpace.s6),

          // grid-cols-2 gap-2 en movil
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: RtcSpace.s2,
            mainAxisSpacing: RtcSpace.s2,
            childAspectRatio: 3.4,
            children: [
              for (final (n, icon, label) in _steps)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: RtcSpace.s2,
                    vertical: RtcSpace.s2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Gray.c200),
                    borderRadius: RtcRadius.brXl,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 16, color: Gray.c600),
                      const SizedBox(width: RtcSpace.s2),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '$n. ',
                                style: const TextStyle(
                                  fontWeight: RtcType.bold,
                                ),
                              ),
                              TextSpan(text: label),
                            ],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: RtcType.xs.copyWith(
                            fontWeight: RtcType.medium,
                            color: Gray.c700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: RtcSpace.s8),

          // El collage: en movil las tres fotos van una debajo de otra.
          for (final url in const [
            'https://imagenes2.eltiempo.com/files/image_1200_675/uploads/2025/02/08/67a826ea4f6fb.jpeg',
            'https://lajauladelangel.com.co/vivaenvigado/wp-content/uploads/2025/01/IMG_0146-scaled.jpg',
            'https://images.unsplash.com/photo-1459865264687-595d652de67e?w=1200&q=80',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: RtcSpace.s3),
              child: ClipRRect(
                borderRadius: RtcRadius.brXl,
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: RemoteImage(url: url),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// EXPLORA POR DEPORTE — tarjetas de 200px con degradado y texto abajo
// ───────────────────────────────────────────────────────────────────────────

/// El collage de deportes: etiqueta, bajada, foto y la clave del deporte, que
/// da el color del hueco mientras la foto carga.
const _gallery = <(String, String, String, String)>[
  (
    'Futbol',
    'La adrenalina y el trabajo en equipo se fusionan.',
    'https://images.unsplash.com/photo-1529900748604-07564a03e7a6?w=1200&q=80',
    'futbol',
  ),
  (
    'Padel',
    'Canchas diseñadas para jugadores que buscan emocion.',
    'https://imagenes2.eltiempo.com/files/image_1200_675/uploads/2025/02/08/67a826ea4f6fb.jpeg',
    'padel',
  ),
  (
    'Voley Playa',
    'Arena profesional para partidos epicos.',
    'https://lajauladelangel.com.co/vivaenvigado/wp-content/uploads/2025/01/IMG_0146-scaled.jpg',
    'voley_playa',
  ),
];

class _DeportesSection extends StatelessWidget {
  const _DeportesSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s4,
        vertical: RtcSpace.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
            title: 'EXPLORA POR DEPORTE',
            subtitle:
                'Clubes con iluminacion nocturna, cesped de primera y mas.',
          ),
          const SizedBox(height: RtcSpace.s6),
          for (final (label, desc, img, deporte) in _gallery)
            Padding(
              padding: const EdgeInsets.only(bottom: RtcSpace.s4),
              child: ClipRRect(
                borderRadius: RtcRadius.brXxl,
                child: SizedBox(
                  height: 200,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      RemoteImage(url: img, sport: deporte),
                      // from-black/85 via-black/20 to-transparent
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.85),
                              Colors.black.withValues(alpha: 0.20),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        left: RtcSpace.s4,
                        right: RtcSpace.s4,
                        bottom: RtcSpace.s4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              label,
                              style: RtcType.lg.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: RtcSpace.s1),
                            Text(
                              desc,
                              style: RtcType.xs.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// CANCHAS DESTACADAS — bg-gray-50, las tarjetas entran escalonadas cada 80ms
// ───────────────────────────────────────────────────────────────────────────

class _DestacadasSection extends StatelessWidget {
  const _DestacadasSection({required this.courts});

  /// `featured.slice(0, 4)` de HomeClient: vienen de `/analytics/public`.
  final List<Court> courts;

  @override
  Widget build(BuildContext context) {
    final visible = courts.take(4).toList();
    return ColoredBox(
      color: Gray.c50,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RtcSpace.s4,
          vertical: RtcSpace.s8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CANCHAS DESTACADAS',
              style: RtcType.xl2.copyWith(
                fontWeight: FontWeight.w900,
                color: Gray.c900,
              ),
            ),
            const SizedBox(height: RtcSpace.s4),
            for (var i = 0; i < visible.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: RtcSpace.s3),
                // FadeIn delay={i * 80} en la web
                child: RtcFadeUp(
                  delay: Duration(milliseconds: i * 80),
                  child: CourtCard(
                    court: visible[i],
                    onTap: () => rtcOpenCourt(visible[i].id),
                  ),
                ),
              ),
            const SizedBox(height: RtcSpace.s2),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => rtcNavigate('/empresas'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Ver todas',
                    style: RtcType.sm.copyWith(
                      fontWeight: RtcType.semibold,
                      color: Gray.c700,
                    ),
                  ),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 20,
                    color: Gray.c700,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────────────────────
// POR QUE ELEGIRNOS
// ───────────────────────────────────────────────────────────────────────────

const _razones = <(IconData, String, String)>[
  (
    LucideIcons.shield,
    'PAGO 100% SEGURO',
    'Procesamos pagos con Wompi, la plataforma mas segura de Colombia. '
        'Nequi, Daviplata y tarjetas.',
  ),
  (
    LucideIcons.users,
    'SIN REGISTRO',
    'Reserva en segundos sin crear cuenta. Solo nombre, email y telefono. '
        'Asi de facil.',
  ),
  (
    LucideIcons.trendingUp,
    'TIENES UNA CANCHA?',
    'Publica tu club y administralo desde tu panel: reservas en tiempo real, '
        'pagos automaticos y analytics.',
  ),
];

class _PorQueSection extends StatelessWidget {
  const _PorQueSection();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Gray.c50,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RtcSpace.s4,
          vertical: RtcSpace.s8,
        ),
        child: Column(
          children: [
            Text(
              'POR QUE ELEGIRNOS',
              textAlign: TextAlign.center,
              style: RtcType.xl2.copyWith(
                fontWeight: FontWeight.w900,
                color: Gray.c900,
              ),
            ),
            const SizedBox(height: RtcSpace.s8),
            for (var i = 0; i < _razones.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: RtcSpace.s4),
                child: RtcFadeUp(
                  delay: Duration(milliseconds: i * 90),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(RtcSpace.s6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: RtcRadius.brXxl,
                      border: Border.all(color: Gray.c100),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            color: Lime.c100,
                            borderRadius: RtcRadius.brXxl,
                          ),
                          child: Icon(
                            _razones[i].$1,
                            size: 28,
                            color: Lime.c600,
                          ),
                        ),
                        const SizedBox(height: RtcSpace.s3),
                        Text(
                          _razones[i].$2,
                          textAlign: TextAlign.center,
                          style: RtcType.sm.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Gray.c900,
                          ),
                        ),
                        const SizedBox(height: RtcSpace.s3),
                        Text(
                          _razones[i].$3,
                          textAlign: TextAlign.center,
                          style: RtcType.sm.copyWith(
                            color: Gray.c500,
                            height: 1.625, // leading-relaxed
                          ),
                        ),
                      ],
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

// ───────────────────────────────────────────────────────────────────────────
// FAQ — acordeon
// ───────────────────────────────────────────────────────────────────────────

const _faq = <(String, String)>[
  (
    'Necesito crear una cuenta para reservar?',
    'No. Solo ingresas tu nombre, email y telefono al momento de reservar. '
        'Sin contrasenas, sin registro.',
  ),
  (
    'Como cancelo mi reserva?',
    'Recibes un link en tu email para soltar tu horario hasta 24 horas antes '
        'del turno. El pago ya quedo procesado, asi que no hacemos '
        'devoluciones: si lo que necesitas es jugar otro dia, escribenos a '
        'soporte y te movemos la reserva.',
  ),
  (
    'Cuales son los metodos de pago?',
    'Aceptamos tarjetas de credito/debito, Nequi, Daviplata y PSE a traves de '
        'Wompi, la plataforma de pagos mas segura de Colombia.',
  ),
  (
    'Como recibo la confirmacion?',
    'Al instante por email. Incluye los datos de la cancha, horario y el link '
        'para cancelar si lo necesitas.',
  ),
];

class _FaqSection extends StatefulWidget {
  const _FaqSection();

  @override
  State<_FaqSection> createState() => _FaqSectionState();
}

class _FaqSectionState extends State<_FaqSection> {
  int? _open;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        RtcSpace.s4,
        RtcSpace.s8,
        RtcSpace.s4,
        RtcSpace.s12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(eyebrow: 'FAQ', title: 'PREGUNTAS FRECUENTES'),
          const SizedBox(height: RtcSpace.s6),
          for (var i = 0; i < _faq.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: RtcSpace.s3),
              child: _FaqItem(
                question: _faq[i].$1,
                answer: _faq[i].$2,
                open: _open == i,
                onTap: () => setState(() => _open = _open == i ? null : i),
              ),
            ),
          const SizedBox(height: RtcSpace.s4),
          for (final t in const [
            'Sin registro requerido',
            'Pago seguro',
            'Confirmacion inmediata',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: RtcSpace.s2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    LucideIcons.circleCheck,
                    size: 16,
                    color: Lime.c500,
                  ),
                  const SizedBox(width: 6),
                  Text(t, style: RtcType.xs.copyWith(color: Gray.c500)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({
    required this.question,
    required this.answer,
    required this.open,
    required this.onTap,
  });

  final String question;
  final String answer;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(RtcSpace.s3),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: open ? Lime.c400 : Gray.c200),
          borderRadius: RtcRadius.brXl,
          // shadow-[0_14px_40px_-20px_rgba(132,204,22,0.7)] al abrirse
          boxShadow: open
              ? [
                  BoxShadow(
                    color: Lime.c500.withValues(alpha: 0.7),
                    offset: const Offset(0, 14),
                    blurRadius: 34,
                    spreadRadius: -20,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    question,
                    style: RtcType.xs.copyWith(
                      fontWeight: RtcType.semibold,
                      color: Gray.c800,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    LucideIcons.chevronDown,
                    size: 16,
                    color: Gray.c500,
                  ),
                ),
              ],
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: RtcSpace.s2),
                child: Text(
                  answer,
                  style: RtcType.xs.copyWith(color: Gray.c500, height: 1.625),
                ),
              ),
              crossFadeState: open
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
              sizeCurve: Curves.easeOut,
            ),
          ],
        ),
      ),
    );
  }
}
