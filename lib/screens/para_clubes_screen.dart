import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/analytics_api.dart';
import '../models/court.dart' show formatCop;
import '../theme/motion.dart';
import '../theme/palette.dart';
import '../theme/shadows.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../app/routes.dart';
import '../widgets/motion/rtc_motion.dart';
import '../widgets/remote_image.dart';
import '../widgets/modo_toggle.dart';
import '../widgets/motion/rtc_pressable.dart';

/// Port de `Frontend/src/app/(public)/para-clubes/page.tsx`.
class ParaClubesScreen extends StatefulWidget {
  const ParaClubesScreen({super.key});

  static const heroImage =
      'https://images.unsplash.com/photo-1459865264687-595d652de67e?w=1600&q=80';

  @override
  State<ParaClubesScreen> createState() => _ParaClubesScreenState();
}

/// `BENEFITS`.
const _benefits = <(IconData, String, String)>[
  (
    LucideIcons.layoutDashboard,
    'Panel en tiempo real',
    'Ve tus reservas, ingresos y ocupación al instante desde cualquier '
        'dispositivo.',
  ),
  (
    LucideIcons.creditCard,
    'Pagos automáticos',
    'Tus clientes pagan online con Nequi, DaviPlata, PSE o tarjeta, y ePayco '
        'te consigna tu parte al instante.',
  ),
  (
    LucideIcons.calendarCheck,
    'Cero dobles reservas',
    'El sistema bloquea el horario apenas alguien reserva. Se acabaron los '
        'cruces.',
  ),
  (
    LucideIcons.bell,
    'Notificaciones al instante',
    'Te avisamos cada nueva reserva y pago en el momento en que ocurre.',
  ),
  (
    LucideIcons.trendingUp,
    'Analytics de tu negocio',
    'Conoce tus horas pico, canchas más rentables y tendencias para decidir '
        'mejor.',
  ),
  (
    LucideIcons.lock,
    'Control de horarios',
    'Bloquea horarios por mantenimiento o eventos privados con un clic.',
  ),
];

/// `STEPS`.
const _steps = <(IconData, String, String, String)>[
  (
    LucideIcons.fileText,
    '1',
    'Solicita acceso',
    'Cuéntanos de tu club. Validamos tus datos y activamos tu cuenta.',
  ),
  (
    LucideIcons.building2,
    '2',
    'Carga tus canchas',
    'Sube fotos, precios, amenidades y tus horarios de atención.',
  ),
  (
    LucideIcons.creditCard,
    '3',
    'Recibe reservas y pagos',
    'Tus clientes reservan y pagan online, sin llamadas ni WhatsApp.',
  ),
  (
    LucideIcons.layoutDashboard,
    '4',
    'Gestiona todo',
    'Controla reservas, pagos y estadísticas desde tu panel.',
  ),
];

/// `FAQ` de los clubes.
const _faq = <(String, String)>[
  (
    '¿Cuánto cuesta?',
    'No hay mensualidad ni contrato. Al jugador se le suma una tarifa de '
        'servicio de \$2.000 sobre el precio de tu cancha, y de lo recaudado '
        'salen la pasarela y nuestra parte: frente a tu precio de lista eso es '
        'cerca de un 5%, y menos cuando la cancha es más cara. Si nadie '
        'reserva, no pagas nada.',
  ),
  (
    '¿Cómo recibo los pagos?',
    'Tus clientes pagan con Nequi, DaviPlata, PSE o tarjeta, y ePayco divide '
        'el cobro en el momento: tu parte te llega directo a tu cuenta, ya con '
        'los costos descontados. No retenemos tu dinero. Solo necesitas '
        'conectar tu propia cuenta de ePayco una vez desde el panel.',
  ),
  (
    '¿Puedo bloquear horarios?',
    'Sí. Bloqueas horarios por mantenimiento, torneos o eventos privados cuando '
        'quieras, desde el panel.',
  ),
  (
    '¿Mis clientes necesitan registrarse?',
    'No. Reservan con su nombre, email y teléfono. Menos fricción, más reservas '
        'para ti.',
  ),
];

class _ParaClubesScreenState extends State<ParaClubesScreen> {
  /// Las cifras del bloque oscuro: la web las recibe del server component.
  PublicStats _stats = PublicStats.fallback;

  /// Los `id` de la web: `#beneficios`, `#como-funciona`, `#faq`.
  final _sections = {
    'beneficios': GlobalKey(),
    'como-funciona': GlobalKey(),
    'faq': GlobalKey(),
  };

  @override
  void initState() {
    super.initState();
    _loadStats();
    rtcPendingAnchor.addListener(_goToAnchor);
    // Al llegar desde otra pantalla el ancla ya esta puesta, pero las
    // secciones todavia no tienen contexto: hay que esperar al primer frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _goToAnchor());
  }

  @override
  void dispose() {
    rtcPendingAnchor.removeListener(_goToAnchor);
    super.dispose();
  }

  Future<void> _loadStats() async {
    final stats = await analyticsApi.public();
    if (!mounted) return;
    setState(() => _stats = stats);
  }

  void _goToAnchor() {
    final anchor = rtcPendingAnchor.value;
    if (anchor == null) return;
    final target = _sections[anchor]?.currentContext;
    if (target == null) return;

    rtcPendingAnchor.value = null;
    // La web salta de golpe (no declara scroll-behavior). En movil un salto
    // seco se siente roto, asi que va animado y corto.
    Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 400),
      curve: RtcCurves.framerExpo,
    );
  }

  void _solicitar() => rtcNavigate('/solicitar-acceso');

  @override
  Widget build(BuildContext context) {
    // SingleChildScrollView y no ListView: el ListView construye solo lo que
    // se ve, y entonces las secciones de mas abajo no existen todavia y el
    // ancla no tiene a donde saltar. En la web el div SIEMPRE esta en el DOM
    // — por eso los anchors funcionan — y esto es el equivalente.
    return SingleChildScrollView(
      child: Column(
        children: [
          _hero(),
          KeyedSubtree(key: _sections['beneficios'], child: _beneficios()),
          _statsSection(),
          KeyedSubtree(key: _sections['como-funciona'], child: _comoFunciona()),
          _testimonio(),
          KeyedSubtree(key: _sections['faq'], child: _faqSection()),
          _ctaFinal(),
        ],
      ),
    );
  }

  // ── HERO ─────────────────────────────────────────────────────────────
  Widget _hero() {
    return Container(
      color: Gray.c900,
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.25,
              child: RemoteImage(
                url: ParaClubesScreen.heroImage,
                placeholderColor: Gray.c900,
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Gray.c900.withValues(alpha: 0.70), Gray.c900],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: RtcSpace.s4,
              vertical: RtcSpace.s10 * 2, // py-20
            ),
            child: Column(
              children: [
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
                      const Icon(LucideIcons.store, size: 14, color: Gray.c900),
                      const SizedBox(width: 6),
                      Text(
                        'Para clubes y empresas',
                        style: RtcType.xs.copyWith(
                          fontWeight: RtcType.bold,
                          color: Gray.c900,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: RtcSpace.s5),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Llena tu cancha. '),
                      TextSpan(
                        text: 'Nosotros nos encargamos del resto.',
                        style: const TextStyle(color: Lime.c400),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: RtcType.xl3.copyWith(
                    color: Colors.white,
                    fontWeight: RtcType.bold,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: RtcSpace.s5),
                Text(
                  'Recibe reservas y pagos online 24/7, sin secretarias ni '
                  'dobles reservas. Gestiona tus canchas, horarios y pagos '
                  'desde un solo panel.',
                  textAlign: TextAlign.center,
                  style: RtcType.base.copyWith(color: Gray.c300),
                ),
                const SizedBox(height: RtcSpace.s8),
                _PillButton(
                  label: 'Solicitar acceso',
                  icon: LucideIcons.chevronRight,
                  background: Lime.c400,
                  foreground: Gray.c900,
                  bold: true,
                  onTap: _solicitar,
                ),
                const SizedBox(height: RtcSpace.s3),
                _PillButton(
                  label: 'Ya tengo cuenta',
                  background: Colors.white.withValues(alpha: 0.10),
                  borderColor: Colors.white.withValues(alpha: 0.20),
                  foreground: Colors.white,
                  onTap: () => rtcNavigate('/auth/login'),
                ),
              ],
            ),
          ),
          // El cambio de modo, en la misma esquina que en el inicio.
          const Positioned(
            top: RtcSpace.s4,
            right: RtcSpace.s5,
            child: ModoToggle(clubes: true, sobreOscuro: true),
          ),
        ],
      ),
    );
  }

  // ── BENEFICIOS ───────────────────────────────────────────────────────
  Widget _beneficios() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s4,
        vertical: RtcSpace.s12 + RtcSpace.s2, // py-14
      ),
      child: Column(
        children: [
          const _SectionTitle(
            eyebrow: 'Beneficios',
            title: 'Todo para gestionar tu negocio',
          ),
          const SizedBox(height: RtcSpace.s10),
          for (var i = 0; i < _benefits.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: RtcSpace.s5),
              // FadeIn delay={i * 70}
              child: RtcFadeUp(
                delay: Duration(milliseconds: i * 70),
                child: _InfoCard(
                  icon: _benefits[i].$1,
                  title: _benefits[i].$2,
                  desc: _benefits[i].$3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── STATS ────────────────────────────────────────────────────────────
  Widget _statsSection() {
    // Los mismos cuatro de la web, con los mismos formatos:
    // `+${totalCourts}`, `+${totalBookings.toLocaleString('es-CO')}`,
    // `+${totalCities}` y `${avgRating}`, este ultimo sin signo.
    final stats = <(String, String)>[
      ('+${_stats.totalCourts}', 'Canchas registradas'),
      ('+${formatCop(_stats.totalBookings)}', 'Reservas realizadas'),
      ('+${_stats.totalCities}', 'Ciudades de Colombia'),
      (_stats.avgRatingLabel, 'Calificación promedio'),
    ];
    return Container(
      color: Gray.c900,
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s4,
        vertical: RtcSpace.s12,
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = (c.maxWidth - RtcSpace.s6) / 2; // grid-cols-2 gap-6
          return Wrap(
            spacing: RtcSpace.s6,
            runSpacing: RtcSpace.s6,
            children: [
              for (final (n, label) in stats)
                SizedBox(
                  width: w,
                  child: Column(
                    children: [
                      Text(
                        n,
                        style: RtcType.xl2.copyWith(
                          color: Lime.c400,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: RtcSpace.s2),
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        style: RtcType.xs.copyWith(
                          color: Colors.white.withValues(alpha: 0.60),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ── CÓMO FUNCIONA ────────────────────────────────────────────────────
  Widget _comoFunciona() {
    return ColoredBox(
      color: Gray.c50,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RtcSpace.s4,
          vertical: RtcSpace.s12 + RtcSpace.s2,
        ),
        child: Column(
          children: [
            const _SectionTitle(
              eyebrow: 'Cómo funciona',
              title: 'Empieza en 4 pasos',
            ),
            const SizedBox(height: RtcSpace.s10),
            for (var i = 0; i < _steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: RtcSpace.s5),
                child: RtcFadeUp(
                  delay: Duration(milliseconds: i * 70),
                  child: _InfoCard(
                    icon: _steps[i].$1,
                    title: _steps[i].$3,
                    desc: _steps[i].$4,
                    step: _steps[i].$2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── TESTIMONIO ───────────────────────────────────────────────────────
  Widget _testimonio() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s4,
        vertical: RtcSpace.s12 + RtcSpace.s2,
      ),
      child: Container(
        padding: const EdgeInsets.all(RtcSpace.s8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Gray.c100),
          borderRadius: BorderRadius.circular(24), // rounded-3xl
          boxShadow: RtcShadows.card,
        ),
        child: Stack(
          children: [
            Positioned(
              right: 0,
              top: 0,
              child: Icon(
                LucideIcons.quote,
                size: 40,
                color: Lime.c400.withValues(alpha: 0.40),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '"Desde que usamos ReservaTuCancha mis canchas están llenas. '
                  'Las reservas online me ahorraron una secretaria y dejé de '
                  'perder clientes por no contestar el teléfono."',
                  style: RtcType.lg.copyWith(
                    color: Gray.c700,
                    fontStyle: FontStyle.italic,
                    height: 1.625,
                  ),
                ),
                const SizedBox(height: RtcSpace.s6),
                const Divider(height: 1, thickness: 1, color: Gray.c100),
                const SizedBox(height: RtcSpace.s6),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Lime.c100,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        'L',
                        style: RtcType.base.copyWith(
                          fontWeight: RtcType.bold,
                          color: const Color(0xFF4D7C0F), // lime-700
                        ),
                      ),
                    ),
                    const SizedBox(width: RtcSpace.s3),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Laura G.',
                          style: RtcType.base.copyWith(
                            fontWeight: RtcType.bold,
                            color: Gray.c900,
                          ),
                        ),
                        Text(
                          'Propietaria de club — Villavicencio',
                          style: RtcType.sm.copyWith(color: Gray.c500),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── FAQ ──────────────────────────────────────────────────────────────
  Widget _faqSection() {
    return ColoredBox(
      color: Gray.c50,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RtcSpace.s4,
          vertical: RtcSpace.s12 + RtcSpace.s2,
        ),
        child: Column(
          children: [
            const _SectionTitle(
              eyebrow: 'Preguntas frecuentes',
              title: 'Lo que los clubes preguntan',
            ),
            const SizedBox(height: RtcSpace.s10),
            for (final (q, a) in _faq)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: RtcSpace.s4),
                padding: const EdgeInsets.all(RtcSpace.s5),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Gray.c100),
                  borderRadius: RtcRadius.brXxl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(
                            LucideIcons.circleCheck,
                            size: 20,
                            color: Green.c600,
                          ),
                        ),
                        const SizedBox(width: RtcSpace.s2),
                        Expanded(
                          child: Text(
                            q,
                            style: RtcType.base.copyWith(
                              fontWeight: RtcType.semibold,
                              color: Gray.c900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: RtcSpace.s2),
                    Padding(
                      padding: const EdgeInsets.only(left: 28), // pl-7
                      child: Text(
                        a,
                        style: RtcType.sm.copyWith(
                          color: Gray.c500,
                          height: 1.625,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── CTA FINAL ────────────────────────────────────────────────────────
  Widget _ctaFinal() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s4,
        vertical: RtcSpace.s12 + RtcSpace.s2,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Container(
          color: Gray.c900,
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.2,
                  child: RemoteImage(
                    url: ParaClubesScreen.heroImage,
                    placeholderColor: Gray.c900,
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Gray.c900,
                        Gray.c900.withValues(alpha: 0.85),
                        Gray.c900.withValues(alpha: 0.40),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: RtcSpace.s6,
                  vertical: RtcSpace.s8 + 4, // py-9
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Para clubes y empresas',
                      style: RtcType.xs.copyWith(
                        color: Lime.c400,
                        fontWeight: RtcType.semibold,
                      ),
                    ),
                    const SizedBox(height: RtcSpace.s1),
                    Text(
                      '¿Tienes una cancha? Publícala con nosotros.',
                      style: RtcType.xl2.copyWith(
                        color: Colors.white,
                        fontWeight: RtcType.bold,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: RtcSpace.s2),
                    Text(
                      'Recibe reservas y pagos online, sin dobles reservas. '
                      'Gestiona todo desde un panel.',
                      style: RtcType.sm.copyWith(color: Gray.c300),
                    ),
                    const SizedBox(height: RtcSpace.s5),
                    _PillButton(
                      label: 'Publica tu cancha',
                      icon: LucideIcons.chevronRight,
                      background: Lime.c400,
                      foreground: Gray.c900,
                      bold: true,
                      onTap: _solicitar,
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
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.eyebrow, required this.title});

  final String eyebrow;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          eyebrow,
          style: RtcType.sm.copyWith(
            color: Lime.c600,
            fontWeight: RtcType.semibold,
          ),
        ),
        const SizedBox(height: RtcSpace.s1),
        Text(
          title,
          textAlign: TextAlign.center,
          style: RtcType.xl2.copyWith(
            fontWeight: RtcType.bold,
            color: Gray.c900,
          ),
        ),
      ],
    );
  }
}

/// Tarjeta de beneficio o paso. Con `step` pinta el numero gigante detras.
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.desc,
    this.step,
  });

  final IconData icon;
  final String title;
  final String desc;
  final String? step;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(RtcSpace.s6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Gray.c100),
        borderRadius: RtcRadius.brXxl,
      ),
      child: Stack(
        children: [
          if (step != null)
            Positioned(
              right: 0,
              top: 0,
              child: Text(
                step!,
                style: RtcType.xl4.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Gray.c100,
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Green.c50,
                  borderRadius: RtcRadius.brXl,
                ),
                child: Icon(icon, size: 24, color: Green.c600),
              ),
              const SizedBox(height: RtcSpace.s4),
              Text(
                title,
                style: RtcType.base.copyWith(
                  fontWeight: RtcType.bold,
                  color: Gray.c900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                desc,
                style: RtcType.sm.copyWith(color: Gray.c500, height: 1.625),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.foreground,
    required this.onTap,
    this.icon,
    this.background,
    this.borderColor,
    this.bold = false,
  });

  final String label;
  final Color foreground;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? background;
  final Color? borderColor;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return RtcPressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: RtcSpace.s3),
        decoration: BoxDecoration(
          color: background,
          borderRadius: RtcRadius.brFull,
          border: borderColor != null ? Border.all(color: borderColor!) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: RtcType.base.copyWith(
                fontWeight: bold ? RtcType.bold : RtcType.semibold,
                color: foreground,
              ),
            ),
            if (icon != null) ...[
              const SizedBox(width: RtcSpace.s2),
              Icon(icon, size: 20, color: foreground),
            ],
          ],
        ),
      ),
    );
  }
}
