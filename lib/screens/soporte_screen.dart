import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/floating_actions.dart';
import '../theme/palette.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/faq_accordion.dart';
import '../widgets/pill_tabs.dart';
import '../widgets/rtc_bottom_nav.dart' show kBottomNavEspacio;
import '../widgets/motion/rtc_pressable.dart';

/// Port de `Frontend/src/app/(public)/soporte/page.tsx`.
///
/// Es el soporte de quien RESERVA: administrar canchas y pagos vive
/// en /que-ofrecemos y en el panel del club.
class SoporteScreen extends StatefulWidget {
  const SoporteScreen({super.key});

  @override
  State<SoporteScreen> createState() => _SoporteScreenState();
}

const _email = 'soporte@reservatucancha.site';

/// Abre un enlace externo. En la web son `<a target="_blank">`; aca salen a
/// al cliente de correo del telefono.
Future<void> _open(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// El `abrirAsistente` de la pagina: la web despacha el evento ABRIR_SOPORTE
/// y el chat, que vive en el layout, lo escucha. Aca es el mismo camino.
void _abrirAsistente() => FloatingActions.abrirSoporte.value++;

/// `CANALES`. `href` en null = el asistente, que en la web dispara el evento
/// ABRIR_SOPORTE del chat.
List<
  ({
    IconData icon,
    String title,
    String desc,
    String cta,
    String? badge,
    String? href,
    Color background,
    Color iconColor,
  })
>
get _canales =>
    <
      ({
        IconData icon,
        String title,
        String desc,
        String cta,
        String? badge,
        String? href,
        Color background,
        Color iconColor,
      })
    >[
      (
        icon: LucideIcons.messageSquare,
        title: 'Asistente virtual',
        desc:
            'Te responde al instante las dudas más comunes y te pasa a un humano '
            'si hace falta.',
        cta: 'Abrir asistente',
        badge: 'Más rápido',
        href: null,
        background: Green.c50,
        iconColor: Green.c600,
      ),
      (
        icon: LucideIcons.mail,
        title: 'Correo',
        desc: 'Escríbenos a $_email y te respondemos dentro de las 24 horas.',
        cta: 'Enviar correo',
        badge: null,
        href: 'mailto:$_email',
        background: Blue.c50,
        iconColor: Blue.c600,
      ),
    ];

/// `FAQ`, con sus cuatro categorias.
Map<String, List<(String, String)>>
get _faq => <String, List<(String, String)>>{
  'Reservar': [
    (
      '¿Necesito crear una cuenta?',
      'No. Eliges la cancha, el día y la hora, y solo pones tu nombre, correo '
          'y teléfono. Sin contraseñas ni registro.',
    ),
    (
      '¿Cómo sé que mi reserva quedó lista?',
      'Apenas se aprueba el pago te llega un correo con el código de tu '
          'reserva. Si no lo ves, revisa la carpeta de spam: llega desde '
          'notificaciones@reservatucancha.site.',
    ),
    (
      '¿Dónde veo mis reservas?',
      'En "Mis reservas", arriba en el menú. Con el correo que usaste al '
          'reservar te aparecen todas.',
    ),
    (
      '¿Puedo reservar varias horas seguidas?',
      'Sí. Al elegir la hora puedes marcar varios turnos seguidos y se cobran '
          'juntos como una sola reserva.',
    ),
  ],
  'Pagos': [
    (
      '¿Cómo puedo pagar?',
      'Con tarjeta de crédito o débito, PSE, Nequi o DaviPlata. El pago se '
          'procesa con ePayco. Al precio de la cancha se le suma una tarifa de '
          'servicio de \$2.000 por reserva, que ves desglosada antes de pagar.',
    ),
    (
      '¿Puedo pagar en efectivo en la cancha?',
      'No. Todas las reservas se pagan en línea al momento de reservar; así el '
          'horario te queda apartado de verdad y nadie más lo puede tomar.',
    ),
    (
      '¿A nombre de quién aparece el cobro?',
      'El pago lo procesa ePayco a través de ReservaTuCancha. En el mismo '
          'momento se reparte: el club recibe su parte y nosotros la tarifa de '
          'servicio.',
    ),
    (
      'Me cobraron pero no me llegó la confirmación',
      'Espera unos minutos y revisa spam. Si sigue sin llegar, escríbenos por '
          'correo con el número de tu transacción y lo revisamos de inmediato.',
    ),
  ],
  'Cambios': [
    (
      '¿Puedo cambiar el horario de mi reserva?',
      'Sí. En el correo de confirmación tienes el botón "Cambiar mi horario": '
          'eliges otro día y hora entre los turnos libres del club, sin costo '
          'adicional.',
    ),
    (
      '¿Hasta cuándo puedo cambiarlo?',
      'Hasta 24 horas antes de tu turno. Después de ese momento el club ya no '
          'alcanza a revender el horario, así que el cambio se cierra.',
    ),
    (
      '¿Puedo cancelar y que me devuelvan el dinero?',
      'No manejamos devoluciones. Si no puedes ir, mueve tu reserva a otro día '
          'u hora: el valor que ya pagaste se conserva completo.',
    ),
    (
      '¿Y si me pasé del plazo?',
      'Escríbenos por correo y hablamos con el club para ver qué se puede '
          'hacer. No lo prometemos, pero siempre lo intentamos.',
    ),
  ],
  'Canchas': [
    (
      '¿Ustedes son dueños de las canchas?',
      'No. Cada cancha pertenece a un club independiente que la administra y la '
          'opera. Nosotros somos la plataforma que te conecta con ellos y '
          'maneja la reserva y el pago.',
    ),
    (
      '¿Cómo llego a la cancha?',
      'En la página de cada cancha hay un mapa con su ubicación y un botón '
          '"Cómo llegar" que te abre la ruta en Google Maps.',
    ),
    (
      '¿Puedo dejar una reseña?',
      'Sí, y solo puede hacerlo quien reservó de verdad. Después de jugar te '
          'llega un correo con el enlace para calificar la cancha.',
    ),
    (
      'Llegué y la cancha estaba ocupada',
      'Escríbenos por correo con tu código de reserva. Hablamos con el club y '
          'te ayudamos a resolverlo.',
    ),
  ],
};

class _SoporteScreenState extends State<SoporteScreen> {
  String _cat = _faq.keys.first;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: kBottomNavEspacio),
      children: [_hero(), _canalesSection(), _faqSection(), _cierre()],
    );
  }

  // ── CABECERA ─────────────────────────────────────────────────────────
  Widget _hero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        RtcSpace.s5,
        RtcSpace.s4,
        RtcSpace.s5,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Soporte',
            style: RtcType.sm.copyWith(
              color: Green.c700,
              fontWeight: RtcType.semibold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '¿En qué te\nayudamos?',
            style: RtcType.xl2.copyWith(
              fontSize: 28,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: Gray.c900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: RtcSpace.s2),
          Text(
            'Resuelve tu duda acá mismo o escríbenos. Si es sobre una reserva, '
            'ten a mano tu código.',
            style: RtcType.sm.copyWith(color: Gray.c500),
          ),
        ],
      ),
    );
  }

  // ── CANALES ──────────────────────────────────────────────────────────
  Widget _canalesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s4,
        vertical: RtcSpace.s12,
      ),
      child: Column(
        children: [
          for (final c in _canales)
            Padding(
              padding: const EdgeInsets.only(bottom: RtcSpace.s4),
              child: _CanalCard(
                icon: c.icon,
                title: c.title,
                desc: c.desc,
                cta: c.cta,
                badge: c.badge,
                background: c.background,
                iconColor: c.iconColor,
                onTap: c.href == null ? _abrirAsistente : () => _open(c.href!),
              ),
            ),
        ],
      ),
    );
  }

  // ── PREGUNTAS FRECUENTES ─────────────────────────────────────────────
  Widget _faqSection() {
    return ColoredBox(
      color: Gray.c50,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RtcSpace.s4,
          vertical: RtcSpace.s12,
        ),
        child: Column(
          children: [
            Text(
              'Preguntas frecuentes',
              textAlign: TextAlign.center,
              style: RtcType.xl2.copyWith(
                fontWeight: FontWeight.w900,
                color: Gray.c900,
              ),
            ),
            const SizedBox(height: RtcSpace.s6),
            PillTabs(
              tabs: _faq.keys.toList(),
              active: _cat,
              onChange: (t) => setState(() => _cat = t),
            ),
            const SizedBox(height: RtcSpace.s6),
            FaqAccordion(
              resetKey: _cat,
              items: [for (final (q, a) in _faq[_cat]!) FaqItem(q, a)],
            ),
          ],
        ),
      ),
    );
  }

  // ── CIERRE ───────────────────────────────────────────────────────────
  Widget _cierre() {
    return Container(
      color: GrisFijo.c900,
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s4,
        vertical: RtcSpace.s12,
      ),
      child: Column(
        children: [
          Text(
            '¿No encontraste tu respuesta?',
            textAlign: TextAlign.center,
            style: RtcType.xl2.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: RtcSpace.s3),
          Text(
            'Escríbenos por correo con tu código de reserva y lo revisamos '
            'contigo.',
            textAlign: TextAlign.center,
            style: RtcType.sm.copyWith(color: GrisFijo.c500),
          ),
          const SizedBox(height: RtcSpace.s6 + 4), // mt-7
          _CtaButton(
            icon: LucideIcons.mail,
            label: 'Escribir por correo',
            background: Lime.c400,
            foreground: GrisFijo.c900,
            onTap: () => _open('mailto:$_email'),
          ),
          const SizedBox(height: RtcSpace.s3),
          _CtaButton(
            icon: LucideIcons.messageSquare,
            label: 'Probar el asistente',
            foreground: Colors.white,
            borderColor: Colors.white.withValues(alpha: 0.30),
            onTap: _abrirAsistente,
          ),
          const SizedBox(height: RtcSpace.s8),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: '¿Tienes una cancha y quieres publicarla? ',
                ),
                TextSpan(
                  text: 'Mira cómo funciona para clubes',
                  style: TextStyle(
                    color: Gray.c300,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: RtcType.xs.copyWith(color: Gray.c500),
          ),
        ],
      ),
    );
  }
}

class _CanalCard extends StatelessWidget {
  const _CanalCard({
    required this.icon,
    required this.title,
    required this.desc,
    required this.cta,
    required this.badge,
    required this.background,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String desc;
  final String cta;
  final String? badge;
  final Color background;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return RtcPressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(RtcSpace.s5),
        decoration: BoxDecoration(
          color: Superficie.tarjeta,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: RtcRadius.brXxl,
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                const Spacer(),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Green.c100,
                      borderRadius: RtcRadius.brFull,
                    ),
                    child: Text(
                      badge!,
                      style: RtcType.xs.copyWith(
                        fontSize: 11,
                        fontWeight: RtcType.bold,
                        color: Green.c700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: RtcSpace.s4),
            Text(
              title,
              style: RtcType.base.copyWith(
                fontWeight: FontWeight.w900,
                color: Gray.c900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              desc,
              style: RtcType.sm.copyWith(color: Gray.c500, height: 1.625),
            ),
            const SizedBox(height: RtcSpace.s4),
            Row(
              children: [
                Text(
                  cta,
                  style: RtcType.sm.copyWith(
                    fontWeight: RtcType.bold,
                    color: Green.c700,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(LucideIcons.arrowRight, size: 16, color: Green.c700),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.onTap,
    this.background,
    this.borderColor,
  });

  final IconData icon;
  final String label;
  final Color foreground;
  final Color? background;
  final Color? borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RtcPressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: RtcRadius.brFull,
          border: borderColor != null
              ? Border.all(color: borderColor!, width: 2)
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: foreground),
            const SizedBox(width: RtcSpace.s2),
            Text(
              label,
              style: RtcType.base.copyWith(
                fontWeight: background != null ? FontWeight.w900 : RtcType.bold,
                color: foreground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
