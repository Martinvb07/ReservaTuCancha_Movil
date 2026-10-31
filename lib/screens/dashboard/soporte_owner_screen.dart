import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/faq_accordion.dart';
import '../../widgets/rtc_select_field.dart';

/// Port de `Frontend/src/app/dashboard/propetario/soporte/page.tsx`.
///
/// Tres canales de contacto, el horario, las preguntas frecuentes y un
/// formulario que —igual que en la web— NO manda nada todavia: espera 1.2s y
/// muestra el acuse.
class SoporteOwnerScreen extends StatefulWidget {
  const SoporteOwnerScreen({super.key});

  @override
  State<SoporteOwnerScreen> createState() => _SoporteOwnerScreenState();
}

/// `FAQ`.
const _faq = [
  FaqItem(
    '¿Cómo activo o desactivo una cancha?',
    'Ve a Mis Canchas → selecciona la cancha → usa el interruptor de '
        '"Estado" para activarla o desactivarla. Los clientes no podrán '
        'reservar canchas inactivas.',
  ),
  FaqItem(
    '¿Cuándo recibo el dinero de mis reservas?',
    'Al instante. Cuando el pago se aprueba, ePayco te consigna tu parte '
        'directo a tu cuenta, ya con los costos descontados. Puedes ver el '
        'detalle de cada reserva en la sección Pagos.',
  ),
  FaqItem(
    '¿Qué pasa si un cliente no puede ir?',
    'Las reservas no se reembolsan: el cliente puede mover su reserva a otro '
        'horario disponible hasta 24 horas antes del turno, y tu parte se '
        'conserva. Si eres tú quien no puede atender un turno ya pagado, '
        'escríbenos a soporte: en ese caso se le devuelve el total al cliente '
        'y se descuenta tu parte de esa reserva.',
  ),
  FaqItem(
    '¿Puedo bloquear horarios para mantenimiento?',
    'Sí. Ve a Disponibilidad → selecciona la cancha → elige el día y horario '
        '→ márcalo como "No disponible".',
  ),
  FaqItem(
    '¿Cómo cambio el precio de mi cancha?',
    'Ve a Mis Canchas → selecciona la cancha → "Editar" → cambia el precio '
        'por hora. El cambio aplica para nuevas reservas, no afecta las ya '
        'confirmadas.',
  ),
];

/// Los asuntos del `<select>`.
const _asuntos = [
  ('reservas', 'Problema con reservas'),
  ('pagos', 'Pagos y retiros'),
  ('canchas', 'Gestión de canchas'),
  ('tecnico', 'Problema técnico'),
  ('otro', 'Otro'),
];

class _SoporteOwnerScreenState extends State<SoporteOwnerScreen> {
  String? _asunto;
  final _mensaje = TextEditingController();
  bool _enviando = false;
  bool _enviado = false;

  @override
  void dispose() {
    _mensaje.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (_enviando) return;
    FocusScope.of(context).unfocus();
    // `required` de los dos campos.
    if (_asunto == null || _mensaje.text.trim().isEmpty) return;
    setState(() => _enviando = true);
    // `setTimeout(..., 1200)` de la web: todavia no hay endpoint.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() {
      _enviando = false;
      _enviado = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: RtcSpace.s12),
      children: [
        _encabezado(),
        const SizedBox(height: RtcSpace.s8),
        // `grid-cols-1 md:grid-cols-3`: en movil van uno debajo del otro.
        _canal(
          LucideIcons.messageSquare,
          'Chat en vivo',
          'Respuesta en menos de 5 min',
          'Iniciar chat',
          const Color(0xFFF0FDF4), // green-50
          Green.c600,
          // Los tres botones de la web son `<button>` sin `onClick`: no
          // llevan a ningun lado todavia. Se portan igual de inertes.
          insignia: 'Más rápido',
        ),
        const SizedBox(height: RtcSpace.s4),
        _canal(
          LucideIcons.mail,
          'Email',
          'Respondemos en 24 horas',
          'Enviar email',
          const Color(0xFFEFF6FF), // blue-50
          const Color(0xFF2563EB), // blue-600
        ),
        const SizedBox(height: RtcSpace.s4),
        _canal(
          LucideIcons.phone,
          'WhatsApp',
          'Atención personalizada',
          'Abrir chat',
          const Color(0xFFECFDF5), // emerald-50
          const Color(0xFF059669), // emerald-600
        ),
        const SizedBox(height: RtcSpace.s8),
        _horario(),
        const SizedBox(height: RtcSpace.s8),
        _titulo('Preguntas frecuentes'),
        const SizedBox(height: RtcSpace.s4),
        const FaqAccordion(items: _faq),
        const SizedBox(height: RtcSpace.s8),
        _formulario(),
      ],
    );
  }

  Widget _encabezado() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Panel propietario',
          style: RtcType.sm.copyWith(
            color: Green.c700,
            fontWeight: RtcType.semibold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Soporte',
          style: RtcType.xl3.copyWith(
            letterSpacing: -0.4,
            fontWeight: FontWeight.w900,
            color: Gray.c900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Estamos aquí para ayudarte con cualquier duda',
          style: RtcType.sm.copyWith(color: Gray.c500),
        ),
      ],
    );
  }

  Widget _canal(
    IconData icono,
    String titulo,
    String desc,
    String cta,
    Color fondo,
    Color colorIcono, {
    String? insignia,
  }) {
    return Container(
      padding: const EdgeInsets.all(RtcSpace.s5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RtcRadius.brXxl,
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: fondo,
                  borderRadius: RtcRadius.brXl,
                ),
                child: Icon(icono, size: 20, color: colorIcono),
              ),
              const SizedBox(height: RtcSpace.s4),
              Text(
                titulo,
                style: RtcType.base.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Gray.c900,
                ),
              ),
              const SizedBox(height: 4),
              Text(desc, style: RtcType.xs.copyWith(color: Gray.c500)),
              const SizedBox(height: RtcSpace.s4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cta,
                    style: RtcType.sm.copyWith(
                      fontWeight: RtcType.bold,
                      color: Green.c700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: Green.c700,
                  ),
                ],
              ),
            ],
          ),
          if (insignia != null)
            Positioned(
              top: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: RtcSpace.s2,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7), // green-100
                  borderRadius: RtcRadius.brFull,
                ),
                child: Text(
                  insignia,
                  style: RtcType.xs.copyWith(
                    fontSize: 10,
                    fontWeight: RtcType.bold,
                    color: Green.c700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _horario() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s5,
        vertical: 14, // py-3.5
      ),
      decoration: BoxDecoration(color: Gray.c50, borderRadius: RtcRadius.brXxl),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.clock, size: 16, color: Green.c600),
          ),
          const SizedBox(width: RtcSpace.s3),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'Atención: '),
                  TextSpan(
                    text: 'Lun–Vie 8am–7pm',
                    style: RtcType.sm.copyWith(
                      fontWeight: RtcType.bold,
                      color: Gray.c700,
                    ),
                  ),
                  const TextSpan(text: ' · Sáb '),
                  TextSpan(
                    text: '9am–2pm',
                    style: RtcType.sm.copyWith(
                      fontWeight: RtcType.bold,
                      color: Gray.c700,
                    ),
                  ),
                  const TextSpan(text: ' · Colombia (UTC-5)'),
                ],
              ),
              style: RtcType.sm.copyWith(color: Gray.c500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _titulo(String texto) {
    return Text(
      texto.toUpperCase(),
      style: RtcType.sm.copyWith(
        fontWeight: FontWeight.w900,
        color: Gray.c900,
        letterSpacing: 1.6,
      ),
    );
  }

  Widget _formulario() {
    return Container(
      padding: const EdgeInsets.all(RtcSpace.s6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RtcRadius.brXxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _titulo('Envíanos un mensaje'),
          ),
          const SizedBox(height: RtcSpace.s5),
          if (_enviado) _acuse() else _campos(),
        ],
      ),
    );
  }

  Widget _acuse() {
    return Column(
      children: [
        const SizedBox(height: RtcSpace.s10),
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFDCFCE7), // green-100
            shape: BoxShape.circle,
          ),
          child: const Icon(
            LucideIcons.circleCheck,
            size: 32,
            color: Green.c600,
          ),
        ),
        const SizedBox(height: RtcSpace.s3),
        Text(
          '¡Mensaje enviado!',
          style: RtcType.base.copyWith(
            fontWeight: FontWeight.w900,
            color: Gray.c900,
          ),
        ),
        const SizedBox(height: RtcSpace.s3),
        Text(
          'Te respondemos en las próximas 24 horas hábiles.',
          textAlign: TextAlign.center,
          style: RtcType.sm.copyWith(color: Gray.c500),
        ),
        const SizedBox(height: RtcSpace.s3),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() {
            _enviado = false;
            _asunto = null;
            _mensaje.clear();
          }),
          child: Text(
            'Enviar otro mensaje',
            style: RtcType.sm.copyWith(
              fontWeight: RtcType.semibold,
              color: Green.c600,
            ),
          ),
        ),
        const SizedBox(height: RtcSpace.s10),
      ],
    );
  }

  Widget _campos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _etiqueta('Asunto'),
        const SizedBox(height: RtcSpace.s2),
        RtcSelectField(
          value: _asunto,
          opciones: _asuntos,
          titulo: 'Asunto',
          placeholder: 'Selecciona un asunto',
          onChange: (v) => setState(() => _asunto = v),
        ),
        const SizedBox(height: RtcSpace.s4),
        _etiqueta('Mensaje'),
        const SizedBox(height: RtcSpace.s2),
        TextField(
          controller: _mensaje,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
          style: RtcType.sm.copyWith(color: Gray.c900),
          decoration: _decoracion(
            'Describe tu problema con el mayor detalle posible...',
          ),
        ),
        const SizedBox(height: RtcSpace.s4),
        _boton(),
      ],
    );
  }

  Widget _boton() {
    final listo = _asunto != null && _mensaje.text.trim().isNotEmpty;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: listo ? _enviar : null,
      child: Opacity(
        // La web no deshabilita por campos vacios (lo hace `required`), pero
        // en movil no hay validacion nativa: sin esto el boton no diria nada.
        opacity: _enviando || !listo ? 0.6 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14), // py-3.5
          decoration: BoxDecoration(
            color: Green.c600,
            borderRadius: RtcRadius.brXxl,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_enviando) ...[
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: RtcSpace.s2),
                Text(
                  'Enviando...',
                  style: RtcType.base.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ] else ...[
                const Icon(LucideIcons.send, size: 16, color: Colors.white),
                const SizedBox(width: RtcSpace.s2),
                Text(
                  'Enviar mensaje',
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
    );
  }

  Widget _etiqueta(String texto) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        texto.toUpperCase(),
        style: RtcType.xs.copyWith(
          fontWeight: FontWeight.w900,
          color: Gray.c500,
          letterSpacing: 1.6,
        ),
      ),
    );
  }

  InputDecoration _decoracion(String hint) {
    final borde = OutlineInputBorder(
      borderRadius: RtcRadius.brXl,
      borderSide: const BorderSide(color: Gray.c200),
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
        borderSide: const BorderSide(color: Green.c400, width: 2),
      ),
    );
  }
}
