import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/motion.dart';
import '../theme/palette.dart';
import '../theme/shadows.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../app/routes.dart';
import '../widgets/step_wizard.dart';
import '../widgets/motion/rtc_pressable.dart';

/// Port de `Frontend/src/app/(public)/solicitar-acceso/page.tsx`.
///
/// Tres pasos con el mismo wizard de la web: datos, negocio y confirmacion.
/// Las reglas de validacion son las del schema de zod, campo por campo.
class SolicitarAccesoScreen extends StatefulWidget {
  const SolicitarAccesoScreen({super.key});

  @override
  State<SolicitarAccesoScreen> createState() => _SolicitarAccesoScreenState();
}

/// `STEPS` — `fields` es lo que se valida antes de dejar avanzar.
const _steps = <({String title, String hint, List<String> fields})>[
  (
    title: 'Tus datos',
    hint: 'Para poder contactarte',
    fields: ['firstName', 'lastName', 'email', 'phone'],
  ),
  (
    title: 'Tu negocio',
    hint: 'Datos del complejo deportivo',
    fields: ['businessName', 'nit', 'city', 'department'],
  ),
  (title: 'Confirmar', hint: 'Revisa y envía tu solicitud', fields: []),
];

const _last = 2;

class _SolicitarAccesoScreenState extends State<SolicitarAccesoScreen> {
  final _fields = <String, TextEditingController>{
    for (final k in [
      'firstName',
      'lastName',
      'email',
      'phone',
      'businessName',
      'nit',
      'city',
      'department',
      'message',
    ])
      k: TextEditingController(),
  };

  final _errors = <String, String>{};

  int _step = 0;

  /// Direccion del ultimo movimiento: define hacia donde se desliza el paso.
  int _dir = 1;

  bool _loading = false;
  bool _submitted = false;

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// El `schema` de zod, traducido campo por campo.
  String? _validate(String key) {
    final v = _fields[key]!.text.trim();
    return switch (key) {
      'firstName' || 'lastName' => v.length < 2 ? 'Mínimo 2 caracteres' : null,
      'email' =>
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v)
            ? null
            : 'Email inválido',
      'phone' => v.length < 7 ? 'Teléfono inválido' : null,
      'businessName' => v.length < 2 ? 'Ingresa el nombre del complejo' : null,
      'nit' => v.length < 5 ? 'NIT o cédula inválido' : null,
      'city' => v.length < 2 ? 'Ingresa la ciudad' : null,
      'department' => v.length < 2 ? 'Ingresa el departamento' : null,
      _ => null,
    };
  }

  void _goTo(int target) => setState(() {
    _dir = target > _step ? 1 : -1;
    _step = target;
  });

  /// `next`: valida solo los campos de este paso antes de avanzar.
  void _next() {
    var ok = true;
    setState(() {
      for (final f in _steps[_step].fields) {
        final err = _validate(f);
        if (err == null) {
          _errors.remove(f);
        } else {
          _errors[f] = err;
          ok = false;
        }
      }
    });
    if (ok) _goTo((_step + 1).clamp(0, _last));
  }

  Future<void> _submit() async {
    // Si el envio final falla, vuelve al primer paso que tenga el error.
    for (var i = 0; i <= _last; i++) {
      for (final f in _steps[i].fields) {
        final err = _validate(f);
        if (err != null) {
          setState(() => _errors[f] = err);
          _goTo(i);
          return;
        }
      }
    }

    setState(() => _loading = true);
    // Aca ira `solicitudesApi.create(data)` cuando entre el cliente HTTP.
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _loading = false;
      _submitted = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _success();

    return ListView(padding: EdgeInsets.zero, children: [_hero(), _form()]);
  }

  // ── HERO ─────────────────────────────────────────────────────────────
  Widget _hero() {
    return ClipRect(
      child: DecoratedBox(
        decoration: BoxDecoration(
          // from-gray-900 via-gray-800 to-green-900
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [GrisFijo.c900, GrisFijo.c800, Green.c900],
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -192,
              top: -192,
              child: Opacity(
                opacity: 0.10,
                child: Container(
                  width: 384,
                  height: 384,
                  decoration: const BoxDecoration(
                    color: Lime.c400,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: RtcSpace.s4,
                  vertical: RtcSpace.s12 + RtcSpace.s2, // py-14
                ),
                child: Column(
                  children: [
                    Text(
                      '✦ PARA PROPIETARIOS DE CANCHAS',
                      textAlign: TextAlign.center,
                      style: RtcType.sm.copyWith(
                        color: Lime.c400,
                        fontWeight: RtcType.semibold,
                        letterSpacing: 1.4,
                      ),
                    ),
                    const SizedBox(height: RtcSpace.s4),
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(
                            text: 'PUBLICA TU CANCHA Y EMPIEZA A\n',
                          ),
                          TextSpan(
                            text: 'RECIBIR RESERVAS HOY',
                            style: const TextStyle(color: Lime.c400),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: RtcType.xl4.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: RtcSpace.s4),
                    Text(
                      'Son 3 pasos rápidos. Validamos tu información en menos '
                      'de 48 horas.',
                      textAlign: TextAlign.center,
                      style: RtcType.sm.copyWith(color: Gray.c300),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── FORMULARIO ───────────────────────────────────────────────────────
  Widget _form() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s4,
        vertical: RtcSpace.s12 + RtcSpace.s4, // py-16
      ),
      child: Container(
        padding: const EdgeInsets.all(RtcSpace.s6),
        decoration: BoxDecoration(
          color: Gray.c50,
          border: Border.all(color: Gray.c100),
          borderRadius: BorderRadius.circular(24), // rounded-3xl
          boxShadow: RtcShadows.card,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StepWizard(
              steps: [
                for (final s in _steps)
                  WizardStep(title: s.title, hint: s.hint),
              ],
              step: _step,
              dir: _dir,
              onGoTo: _goTo,
              child: switch (_step) {
                0 => _stepDatos(),
                1 => _stepNegocio(),
                _ => _stepConfirmar(),
              },
            ),
            const SizedBox(height: RtcSpace.s6),
            _nav(),
            if (_step == _last) ...[
              const SizedBox(height: RtcSpace.s4),
              Text(
                'Al enviar aceptas nuestros términos de uso y política de '
                'privacidad.',
                textAlign: TextAlign.center,
                style: RtcType.xs.copyWith(color: Gray.c500),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stepDatos() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _field('firstName', 'Nombre', 'Juan')),
            const SizedBox(width: RtcSpace.s4),
            Expanded(child: _field('lastName', 'Apellido', 'Pérez')),
          ],
        ),
        const SizedBox(height: RtcSpace.s4),
        _field(
          'email',
          'Email',
          'juan@email.com',
          keyboard: TextInputType.emailAddress,
        ),
        const SizedBox(height: RtcSpace.s4),
        _field(
          'phone',
          'Teléfono',
          '+57 300 123 4567',
          keyboard: TextInputType.phone,
        ),
      ],
    );
  }

  Widget _stepNegocio() {
    return Column(
      children: [
        _field(
          'businessName',
          'Nombre del complejo / negocio',
          'Ej: Complejo Deportivo Los Campeones',
        ),
        const SizedBox(height: RtcSpace.s4),
        _field('nit', 'NIT / Cédula', '900.123.456-7'),
        const SizedBox(height: RtcSpace.s4),
        Row(
          children: [
            Expanded(child: _field('city', 'Ciudad', 'Ej: Villavicencio')),
            const SizedBox(width: RtcSpace.s4),
            Expanded(child: _field('department', 'Departamento', 'Ej: Meta')),
          ],
        ),
      ],
    );
  }

  Widget _stepConfirmar() {
    String v(String k) => _fields[k]!.text.trim();
    final resumen = <(String, String, int)>[
      ('Nombre', '${v('firstName')} ${v('lastName')}'.trim(), 0),
      ('Email', v('email'), 0),
      ('Teléfono', v('phone'), 0),
      ('Negocio', v('businessName'), 1),
      ('NIT / Cédula', v('nit'), 1),
      (
        'Ubicación',
        [v('city'), v('department')].where((s) => s.isNotEmpty).join(', '),
        1,
      ),
    ];

    return Column(
      children: [
        _field(
          'message',
          'Mensaje adicional',
          'Más info sobre tu negocio, redes sociales, cantidad de canchas...',
          optional: true,
          lines: 3,
        ),
        const SizedBox(height: RtcSpace.s4),
        Container(
          decoration: BoxDecoration(
            color: Superficie.tarjeta,
            border: Border.all(color: Gray.c200),
            borderRadius: RtcRadius.brXxl,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                color: Gray.c50,
                padding: const EdgeInsets.symmetric(
                  horizontal: RtcSpace.s4,
                  vertical: RtcSpace.s3,
                ),
                child: Text(
                  'RESUMEN DE TU SOLICITUD',
                  style: RtcType.xs.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Gray.c900,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              for (final (label, value, target) in resumen)
                Container(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: Gray.c100)),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: RtcSpace.s4,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 92,
                        child: Text(
                          label,
                          style: RtcType.xs.copyWith(color: Gray.c500),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          value.isEmpty ? '—' : value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: RtcType.sm.copyWith(
                            fontWeight: RtcType.semibold,
                            color: Gray.c800,
                          ),
                        ),
                      ),
                      RtcPressable(
                        onTap: () => _goTo(target),
                        child: Icon(
                          LucideIcons.pencil,
                          size: 14,
                          color: Gray.c300,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Campo con su etiqueta y el error que entra desde -4px.
  Widget _field(
    String key,
    String label,
    String hint, {
    bool optional = false,
    int lines = 1,
    TextInputType? keyboard,
  }) {
    final error = _errors[key];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${label.toUpperCase()} '),
              optional
                  ? TextSpan(
                      text: '(opcional)',
                      style: RtcType.xs.copyWith(
                        color: Gray.c500,
                        fontWeight: RtcType.medium,
                      ),
                    )
                  : const TextSpan(
                      text: '*',
                      style: TextStyle(color: Red.c500),
                    ),
            ],
          ),
          style: RtcType.xs.copyWith(
            fontWeight: RtcType.bold,
            color: Gray.c600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _fields[key],
          keyboardType: keyboard,
          maxLines: lines,
          onChanged: (_) {
            if (_errors.containsKey(key)) {
              setState(() => _errors.remove(key));
            }
          },
          style: RtcType.sm.copyWith(color: Gray.c900),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: RtcType.sm.copyWith(color: Gray.c500),
            filled: true,
            fillColor: Superficie.tarjeta,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: RtcSpace.s4,
              vertical: RtcSpace.s3,
            ),
            border: OutlineInputBorder(
              borderRadius: RtcRadius.brXl,
              borderSide: BorderSide(color: Gray.c200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: RtcRadius.brXl,
              borderSide: BorderSide(color: Gray.c200),
            ),
            // focus:ring-2 ring-green-400
            focusedBorder: const OutlineInputBorder(
              borderRadius: RtcRadius.brXl,
              borderSide: BorderSide(color: Green.c400, width: 2),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topLeft,
          child: error == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    error,
                    style: RtcType.xs.copyWith(color: Red.c500),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _nav() {
    return Row(
      children: [
        if (_step > 0) ...[
          RtcPressable(
            onTap: () => _goTo(_step - 1),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: RtcSpace.s5,
                vertical: RtcSpace.s4,
              ),
              decoration: BoxDecoration(
                color: Superficie.tarjeta,
                border: Border.all(color: Gray.c200),
                borderRadius: RtcRadius.brXxl,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.chevronLeft, size: 16, color: Gray.c600),
                  const SizedBox(width: 6),
                  Text(
                    'Atrás',
                    style: RtcType.sm.copyWith(
                      fontWeight: RtcType.bold,
                      color: Gray.c600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: RtcSpace.s3),
        ],
        Expanded(
          child: RtcPressable(
            onTap: _loading ? null : (_step < _last ? _next : _submit),
            child: Opacity(
              opacity: _loading ? 0.6 : 1,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: RtcSpace.s4),
                decoration: BoxDecoration(
                  color: Green.c600,
                  borderRadius: RtcRadius.brXxl,
                  boxShadow: [
                    cssShadow(
                      dy: 10,
                      blur: 15,
                      color: Green.c600.withValues(alpha: 0.20),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_loading) ...[
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
                        'Enviando solicitud...',
                        style: RtcType.base.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ] else ...[
                      Text(
                        _step < _last ? 'Continuar' : 'Enviar solicitud',
                        style: RtcType.base.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: RtcSpace.s2),
                      const Icon(
                        LucideIcons.chevronRight,
                        size: 20,
                        color: Colors.white,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── SUCCESS ──────────────────────────────────────────────────────────
  Widget _success() {
    // En la web el exito vive dentro del <main>, asi que el navbar sigue
    // arriba. Aca pasa lo mismo: es contenido, no una pantalla aparte.
    return ColoredBox(
      color: GrisFijo.c900,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(RtcSpace.s4),
        child: Center(child: _SuccessBody(onBack: () => rtcNavigate('/'))),
      ),
    );
  }
}

/// El check entra con resorte (320/18) y el bloque sube 16px en 400ms.
class _SuccessBody extends StatefulWidget {
  const _SuccessBody({required this.onBack});

  final VoidCallback onBack;

  @override
  State<_SuccessBody> createState() => _SuccessBodyState();
}

class _SuccessBodyState extends State<_SuccessBody>
    with TickerProviderStateMixin {
  late final AnimationController _block = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  )..forward();

  @override
  void dispose() {
    _block.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _block,
      builder: (context, child) {
        final t = RtcCurves.framerExpo.transform(_block.value);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - t)),
            child: child,
          ),
        );
      },
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Lime.c400,
              shape: BoxShape.circle,
              boxShadow: RtcShadows.cardRaised,
            ),
            child: const Icon(
              LucideIcons.circleCheckBig,
              size: 40,
              color: GrisFijo.c900,
            ),
          ),
          const SizedBox(height: RtcSpace.s6),
          Text(
            '¡SOLICITUD ENVIADA!',
            textAlign: TextAlign.center,
            style: RtcType.xl3.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: RtcSpace.s2),
          Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text:
                      'Revisaremos tu información y te contactaremos en las '
                      'próximas ',
                ),
                TextSpan(
                  text: '24–48 horas hábiles',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: RtcType.semibold,
                  ),
                ),
                const TextSpan(text: ' para activar tu cuenta.'),
              ],
            ),
            textAlign: TextAlign.center,
            style: RtcType.base.copyWith(color: GrisFijo.c500),
          ),
          const SizedBox(height: RtcSpace.s6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(RtcSpace.s5),
            decoration: BoxDecoration(
              color: GrisFijo.c800,
              border: Border.all(color: Gray.c700),
              borderRadius: RtcRadius.brXxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '✉️ Revisa tu bandeja de entrada y spam.',
                  style: RtcType.sm.copyWith(color: GrisFijo.c500),
                ),
                Text(
                  '🔑 Recibirás tus credenciales por email.',
                  style: RtcType.sm.copyWith(color: GrisFijo.c500),
                ),
              ],
            ),
          ),
          const SizedBox(height: RtcSpace.s6),
          RtcPressable(
            onTap: widget.onBack,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: RtcSpace.s8,
                vertical: 14,
              ),
              decoration: const BoxDecoration(
                color: Lime.c400,
                borderRadius: RtcRadius.brFull,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Volver al inicio',
                    style: RtcType.base.copyWith(
                      fontWeight: RtcType.bold,
                      color: GrisFijo.c900,
                    ),
                  ),
                  const SizedBox(width: RtcSpace.s2),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 20,
                    color: GrisFijo.c900,
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
