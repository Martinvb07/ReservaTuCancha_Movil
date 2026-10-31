import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../step_wizard.dart';

/// Port de `Frontend/src/components/dashboard/CuentaPagosWizard.tsx`.
///
/// Con cuenta ya guardada arranca en modo resumen; el asistente de tres pasos
/// se abre al tocar Editar.
class CuentaPagosWizard extends StatefulWidget {
  const CuentaPagosWizard({
    super.key,
    required this.actual,
    required this.guardando,
    required this.onGuardar,
  });

  /// Lo que ya esta guardado, si el club lo configuro antes.
  final Map<String, dynamic>? actual;

  final bool guardando;
  final ValueChanged<Map<String, dynamic>> onGuardar;

  @override
  State<CuentaPagosWizard> createState() => _CuentaPagosWizardState();
}

/// `METODOS`. Debe coincidir con `METODOS_PAGO` del backend.
const _metodos =
    <({String clave, String nombre, String desc, IconData icono, Color color})>[
      (
        clave: 'bancolombia',
        nombre: 'Bancolombia',
        desc: 'Cuenta de ahorros o corriente',
        icono: LucideIcons.landmark,
        color: Color(0xFFCA8A04), // yellow-600
      ),
      (
        clave: 'nequi',
        nombre: 'Nequi',
        desc: 'A tu número de celular',
        icono: LucideIcons.smartphone,
        color: Color(0xFFC026D3), // fuchsia-600
      ),
      (
        clave: 'daviplata',
        nombre: 'Daviplata',
        desc: 'A tu número de celular',
        icono: LucideIcons.smartphone,
        color: Color(0xFFDC2626), // red-600
      ),
      (
        clave: 'breb',
        nombre: 'Llave Bre-B',
        desc: 'Con tu llave, sin número de cuenta',
        icono: LucideIcons.keyRound,
        color: Color(0xFF2563EB), // blue-600
      ),
    ];

/// `TIPOS_LLAVE`.
const _tiposLlave = <({String clave, String etiqueta, String ejemplo})>[
  (clave: 'alfanumerica', etiqueta: 'Alfanumérica', ejemplo: '@micancha'),
  (clave: 'celular', etiqueta: 'Celular', ejemplo: '3001234567'),
  (clave: 'correo', etiqueta: 'Correo', ejemplo: 'club@correo.com'),
  (clave: 'documento', etiqueta: 'Documento', ejemplo: '1.234.567.890'),
];

/// `PASOS`.
const _pasos = [
  WizardStep(title: 'Método', hint: 'Por dónde quieres recibir'),
  WizardStep(title: 'Datos', hint: 'A nombre de quién giramos'),
  WizardStep(title: 'Confirma', hint: 'Revisa antes de guardar'),
];

/// `etiquetaMetodo`.
String etiquetaMetodo(String? m) {
  for (final x in _metodos) {
    if (x.clave == m) return x.nombre;
  }
  return (m == null || m.isEmpty) ? '—' : m;
}

/// `resumenFilas`: lo que se le muestra al club de su cuenta.
List<(String, String)> _resumenFilas(Map<String, dynamic> d) {
  String s(String k) {
    final v = d[k] as String?;
    return (v == null || v.isEmpty) ? '—' : v;
  }

  final metodo = d['metodo'] as String?;
  final filas = <(String, String)>[
    ('Método', etiquetaMetodo(metodo)),
    ('Titular', s('titular')),
    ('Cédula o NIT', s('documento')),
  ];

  if (metodo == 'bancolombia') {
    filas.add((
      'Tipo de cuenta',
      d['tipoCuenta'] == 'corriente' ? 'Corriente' : 'Ahorros',
    ));
    filas.add(('Número de cuenta', s('numero')));
  } else if (metodo == 'breb') {
    final tipo = _tiposLlave
        .where((t) => t.clave == d['tipoLlave'])
        .map((t) => t.etiqueta)
        .firstOrNull;
    filas.add(('Tipo de llave', tipo ?? '—'));
    filas.add(('Llave', s('llave')));
  } else {
    filas.add(('Celular', s('numero')));
  }
  return filas;
}

class _CuentaPagosWizardState extends State<CuentaPagosWizard> {
  late bool _editando = !_yaConfigurada;
  int _paso = 0;
  int _dir = 1;
  String? _error;

  String? _metodo;
  String _tipoCuenta = 'ahorros';
  String _tipoLlave = 'alfanumerica';

  final _titular = TextEditingController();
  final _documento = TextEditingController();
  final _numero = TextEditingController();
  final _llave = TextEditingController();

  bool get _yaConfigurada =>
      ((widget.actual?['metodo'] as String?) ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    final a = widget.actual ?? const <String, dynamic>{};
    _metodo = a['metodo'] as String?;
    _tipoCuenta = (a['tipoCuenta'] as String?) ?? 'ahorros';
    _tipoLlave = (a['tipoLlave'] as String?) ?? 'alfanumerica';
    _titular.text = (a['titular'] as String?) ?? '';
    _documento.text = (a['documento'] as String?) ?? '';
    _numero.text = (a['numero'] as String?) ?? '';
    _llave.text = (a['llave'] as String?) ?? '';
  }

  @override
  void dispose() {
    for (final c in [_titular, _documento, _numero, _llave]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _esBanco => _metodo == 'bancolombia';
  bool get _esBreb => _metodo == 'breb';

  /// `faltante`: las mismas reglas del DTO del backend.
  String? get _faltante {
    if (_paso == 0 && (_metodo == null || _metodo!.isEmpty)) {
      return 'Elige por dónde quieres recibir tus pagos';
    }
    if (_paso == 1) {
      if (_titular.text.trim().length < 3) {
        return 'Escribe el nombre completo del titular';
      }
      if (_documento.text.trim().length < 5) {
        return 'La cédula o NIT parece incompleto';
      }
      if (_esBreb && _llave.text.trim().isEmpty) {
        return 'Escribe tu llave Bre-B';
      }
      if (!_esBreb && _numero.text.trim().isEmpty) {
        return _esBanco
            ? 'Falta el número de cuenta'
            : 'Falta el número de celular';
      }
    }
    return null;
  }

  void _irA(int destino) => setState(() {
    _dir = destino > _paso ? 1 : -1;
    _paso = destino;
    _error = null;
  });

  void _siguiente() {
    final falta = _faltante;
    if (falta != null) {
      setState(() => _error = falta);
      return;
    }
    FocusScope.of(context).unfocus();
    _irA(_paso + 1 > _pasos.length - 1 ? _pasos.length - 1 : _paso + 1);
  }

  /// Lo que se manda, armado por metodo como en la web.
  Map<String, dynamic> get _formulario => {
    'metodo': _metodo,
    'titular': _titular.text.trim(),
    'documento': _documento.text.trim(),
    if (_esBanco) ...{
      'banco': 'Bancolombia',
      'tipoCuenta': _tipoCuenta,
      'numero': _numero.text.trim(),
    } else if (_esBreb) ...{
      'llave': _llave.text.trim(),
      'tipoLlave': _tipoLlave,
    } else
      'numero': _numero.text.trim(),
  };

  @override
  Widget build(BuildContext context) {
    if (!_editando) return _resumen();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!_yaConfigurada) ...[
          _aviso(
            icono: LucideIcons.circleAlert,
            fondoIcono: const Color(0xFFF59E0B), // amber-500
            fondo: const Color(0xFFFFFBEB), // amber-50
            borde: const Color(0xFFFDE68A), // amber-200
            titulo: 'Falta tu cuenta de pagos',
            texto:
                'Sin estos datos no podemos girarte lo recaudado. Son tres '
                'pasos cortos.',
          ),
          const SizedBox(height: RtcSpace.s4),
        ],
        Container(
          padding: const EdgeInsets.all(RtcSpace.s4),
          decoration: BoxDecoration(
            color: Slate.c50,
            borderRadius: BorderRadius.circular(24), // rounded-3xl
            border: Border.all(color: Gray.c100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StepWizard(
                steps: _pasos,
                step: _paso,
                dir: _dir,
                // `onGoTo={(i) => i < paso && irA(i)}`
                onGoTo: (i) {
                  if (i < _paso) _irA(i);
                },
                child: switch (_paso) {
                  0 => _pasoMetodo(),
                  1 => _pasoDatos(),
                  _ => _pasoRevisar(),
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: RtcSpace.s4),
                _cajaError(_error!),
              ],
              const SizedBox(height: RtcSpace.s6),
              _botonera(),
            ],
          ),
        ),
      ],
    );
  }

  // ── MODO RESUMEN ─────────────────────────────────────────────────────

  Widget _resumen() {
    final a = widget.actual ?? const <String, dynamic>{};
    final metodo = _metodos.where((m) => m.clave == a['metodo']).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _aviso(
          icono: LucideIcons.circleCheck,
          fondoIcono: Green.c600,
          fondo: Green.c50,
          borde: const Color(0xFFBBF7D0), // green-200
          titulo: 'Cuenta registrada',
          texto:
              'Acá te transferimos tu liquidación cada lunes. Mantenla al día.',
        ),
        const SizedBox(height: RtcSpace.s4),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: RtcRadius.brXxl,
            border: Border.all(color: Gray.c200),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(RtcSpace.s4),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Gray.c100)),
                ),
                child: Row(
                  children: [
                    if (metodo != null) ...[
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Gray.c50,
                          borderRadius: RtcRadius.brXl,
                        ),
                        child: Icon(
                          metodo.icono,
                          size: 20,
                          color: metodo.color,
                        ),
                      ),
                      const SizedBox(width: RtcSpace.s3),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            etiquetaMetodo(a['metodo'] as String?),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RtcType.base.copyWith(
                              fontWeight: FontWeight.w900,
                              color: Gray.c900,
                            ),
                          ),
                          Text(
                            (a['titular'] as String?) ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: RtcType.xs.copyWith(color: Gray.c500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: RtcSpace.s3),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() {
                        _editando = true;
                        _paso = 0;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: RtcSpace.s3,
                          vertical: RtcSpace.s2,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: RtcRadius.brXl,
                          border: Border.all(color: Gray.c200, width: 2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.pencil,
                              size: 14,
                              color: Gray.c700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Editar',
                              style: RtcType.sm.copyWith(
                                fontSize: 13,
                                fontWeight: RtcType.bold,
                                color: Gray.c700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              for (final (etiqueta, valor) in _resumenFilas(a))
                _filaResumen(etiqueta, valor, conBorde: true),
            ],
          ),
        ),
      ],
    );
  }

  Widget _filaResumen(String etiqueta, String valor, {bool conBorde = false}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: conBorde
            ? const Border(top: BorderSide(color: Gray.c100))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RtcSpace.s4,
          vertical: RtcSpace.s3,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(etiqueta, style: RtcType.sm.copyWith(color: Gray.c500)),
            const SizedBox(width: RtcSpace.s4),
            Expanded(
              child: Text(
                valor,
                textAlign: TextAlign.right,
                style: RtcType.sm.copyWith(
                  fontWeight: RtcType.bold,
                  color: Gray.c900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── PASOS ────────────────────────────────────────────────────────────

  Widget _pasoMetodo() {
    // `grid-cols-1 sm:grid-cols-2`: en movil uno debajo del otro.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _metodos.length; i++) ...[
          if (i > 0) const SizedBox(height: RtcSpace.s3),
          _tarjetaMetodo(_metodos[i]),
        ],
      ],
    );
  }

  Widget _tarjetaMetodo(
    ({String clave, String nombre, String desc, IconData icono, Color color}) m,
  ) {
    final activo = _metodo == m.clave;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        _metodo = m.clave;
        _error = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(RtcSpace.s4),
        decoration: BoxDecoration(
          color: activo ? Green.c50 : Colors.white,
          borderRadius: RtcRadius.brXxl,
          border: Border.all(
            color: activo ? const Color(0xFF22C55E) : Gray.c200,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Gray.c50,
                borderRadius: RtcRadius.brXl,
              ),
              child: Icon(m.icono, size: 20, color: m.color),
            ),
            const SizedBox(width: RtcSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    m.nombre,
                    style: RtcType.sm.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Gray.c900,
                    ),
                  ),
                  Text(
                    m.desc,
                    style: RtcType.xs.copyWith(color: Gray.c500, height: 1.35),
                  ),
                ],
              ),
            ),
            if (activo) ...[
              const SizedBox(width: RtcSpace.s3),
              const Icon(LucideIcons.circleCheck, size: 20, color: Green.c600),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pasoDatos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _campo(
          'Titular de la cuenta',
          _titular,
          'Nombre como aparece en el banco',
        ),
        const SizedBox(height: RtcSpace.s4),
        _campo('Cédula o NIT', _documento, '1.234.567.890'),
        if (_esBanco) ...[
          const SizedBox(height: RtcSpace.s4),
          _etiqueta('Tipo de cuenta'),
          const SizedBox(height: RtcSpace.s2),
          Row(
            children: [
              for (final (v, l) in const [
                ('ahorros', 'Ahorros'),
                ('corriente', 'Corriente'),
              ]) ...[
                if (v != 'ahorros') const SizedBox(width: RtcSpace.s3),
                Expanded(
                  child: _botonOpcion(
                    etiqueta: l,
                    activo: _tipoCuenta == v,
                    onTap: () => setState(() => _tipoCuenta = v),
                  ),
                ),
              ],
            ],
          ),
        ],
        if (_esBreb) ...[
          const SizedBox(height: RtcSpace.s4),
          _etiqueta('Tipo de llave'),
          const SizedBox(height: RtcSpace.s2),
          // `grid-cols-2 sm:grid-cols-4`: en movil van de a dos.
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: _tiposLlave.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: RtcSpace.s2,
              mainAxisSpacing: RtcSpace.s2,
              mainAxisExtent: 62,
            ),
            itemBuilder: (context, i) {
              final t = _tiposLlave[i];
              return _botonOpcion(
                etiqueta: t.etiqueta,
                ejemplo: t.ejemplo,
                activo: _tipoLlave == t.clave,
                onTap: () => setState(() => _tipoLlave = t.clave),
              );
            },
          ),
        ],
        const SizedBox(height: RtcSpace.s4),
        if (_esBreb) ...[
          _campo(
            'Tu llave Bre-B',
            _llave,
            _tiposLlave
                    .where((t) => t.clave == _tipoLlave)
                    .map((t) => t.ejemplo)
                    .firstOrNull ??
                '@micancha',
          ),
          const SizedBox(height: 6),
          Text(
            'Escríbela tal cual la registraste en tu banco, con arroba si la '
            'tiene.',
            style: RtcType.xs.copyWith(color: Gray.c400),
          ),
        ] else ...[
          _campo(
            _esBanco ? 'Número de cuenta' : 'Número de celular',
            _numero,
            _esBanco ? '000-000000-00' : '3001234567',
            teclado: TextInputType.number,
          ),
          if (!_esBanco) ...[
            const SizedBox(height: 6),
            Text(
              'El mismo celular con el que abriste tu '
              '${etiquetaMetodo(_metodo)}.',
              style: RtcType.xs.copyWith(color: Gray.c400),
            ),
          ],
        ],
      ],
    );
  }

  Widget _pasoRevisar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: RtcRadius.brXxl,
            border: Border.all(color: Gray.c200),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _resumenFilas(_formulario).length; i++)
                _filaResumen(
                  _resumenFilas(_formulario)[i].$1,
                  _resumenFilas(_formulario)[i].$2,
                  conBorde: i > 0,
                ),
            ],
          ),
        ),
        const SizedBox(height: RtcSpace.s4),
        Container(
          padding: const EdgeInsets.all(14), // p-3.5
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF), // blue-50
            borderRadius: RtcRadius.brXxl,
            border: Border.all(color: const Color(0xFFBFDBFE)), // blue-200
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  LucideIcons.shieldCheck,
                  size: 16,
                  color: Color(0xFF2563EB), // blue-600
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Revisa que el titular y el documento coincidan con la '
                  'cuenta: si no cuadran, el banco rechaza la transferencia. '
                  'Te avisaremos por correo cada vez que estos datos cambien.',
                  style: RtcType.sm.copyWith(
                    fontSize: 13,
                    color: const Color(0xFF1E3A8A), // blue-900
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── PIEZAS ───────────────────────────────────────────────────────────

  Widget _botonera() {
    // `flex-col-reverse sm:flex-row`: en movil el principal va arriba.
    final principal = _paso < _pasos.length - 1
        ? _boton(
            etiqueta: 'Continuar',
            icono: LucideIcons.chevronRight,
            iconoAlFinal: true,
            fondo: Gray.c900,
            onTap: _siguiente,
          )
        : _boton(
            etiqueta: widget.guardando ? 'Guardando…' : 'Guardar cuenta',
            icono: LucideIcons.save,
            fondo: Green.c600,
            cargando: widget.guardando,
            onTap: widget.guardando
                ? null
                : () => widget.onGuardar(_formulario),
          );

    final secundario = (_paso > 0 || _yaConfigurada)
        ? GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.guardando
                ? null
                : () => _paso > 0
                      ? _irA(_paso - 1)
                      : setState(() => _editando = false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14), // py-3.5
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: RtcRadius.brXxl,
                border: Border.all(color: Gray.c200, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    LucideIcons.chevronLeft,
                    size: 16,
                    color: Gray.c700,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _paso > 0 ? 'Atrás' : 'Cancelar',
                    style: RtcType.base.copyWith(
                      fontWeight: RtcType.bold,
                      color: Gray.c700,
                    ),
                  ),
                ],
              ),
            ),
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        principal,
        if (secundario != null) ...[
          const SizedBox(height: RtcSpace.s3),
          secundario,
        ],
      ],
    );
  }

  Widget _boton({
    required String etiqueta,
    required IconData icono,
    required Color fondo,
    required VoidCallback? onTap,
    bool iconoAlFinal = false,
    bool cargando = false,
  }) {
    final grafico = cargando
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
        : Icon(icono, size: iconoAlFinal ? 16 : 20, color: Colors.white);

    final texto = Text(
      etiqueta,
      style: RtcType.base.copyWith(
        fontWeight: FontWeight.w900,
        color: Colors.white,
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        opacity: cargando ? 0.6 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: fondo,
            borderRadius: RtcRadius.brXxl,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: iconoAlFinal
                ? [texto, const SizedBox(width: 6), grafico]
                : [grafico, const SizedBox(width: RtcSpace.s2), texto],
          ),
        ),
      ),
    );
  }

  Widget _botonOpcion({
    required String etiqueta,
    required bool activo,
    required VoidCallback onTap,
    String? ejemplo,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          vertical: ejemplo == null ? RtcSpace.s3 : 10,
          horizontal: RtcSpace.s2,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: activo ? Green.c50 : Colors.white,
          borderRadius: RtcRadius.brXl,
          border: Border.all(
            color: activo ? const Color(0xFF22C55E) : Gray.c200,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              etiqueta,
              style: RtcType.sm.copyWith(
                fontSize: ejemplo == null ? null : 13,
                fontWeight: RtcType.bold,
                color: activo ? const Color(0xFF166534) : Gray.c700,
              ),
            ),
            if (ejemplo != null)
              Text(
                ejemplo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: RtcType.xs.copyWith(fontSize: 10, color: Gray.c400),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cajaError(String texto) {
    return Container(
      padding: const EdgeInsets.all(RtcSpace.s3),
      decoration: BoxDecoration(
        color: Red.c50,
        borderRadius: RtcRadius.brXl,
        border: Border.all(color: Red.c200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.circleAlert, size: 16, color: Red.c500),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: RtcType.sm.copyWith(fontSize: 13, color: Red.c700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _aviso({
    required IconData icono,
    required Color fondoIcono,
    required Color fondo,
    required Color borde,
    required String titulo,
    required String texto,
  }) {
    return Container(
      padding: const EdgeInsets.all(RtcSpace.s4),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: RtcRadius.brXxl,
        border: Border.all(color: borde),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fondoIcono,
              borderRadius: RtcRadius.brXl,
            ),
            child: Icon(icono, size: 20, color: Colors.white),
          ),
          const SizedBox(width: RtcSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: RtcType.sm.copyWith(
                    fontWeight: RtcType.bold,
                    color: Gray.c900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(texto, style: RtcType.sm.copyWith(color: Gray.c600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _etiqueta(String texto) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: texto.toUpperCase()),
          const TextSpan(
            text: ' *',
            style: TextStyle(color: Red.c500),
          ),
        ],
      ),
      style: RtcType.xs.copyWith(
        fontWeight: FontWeight.w900,
        color: Gray.c500,
        letterSpacing: 1.6,
      ),
    );
  }

  Widget _campo(
    String etiqueta,
    TextEditingController controller,
    String hint, {
    TextInputType? teclado,
  }) {
    final borde = OutlineInputBorder(
      borderRadius: RtcRadius.brXl,
      borderSide: const BorderSide(color: Gray.c200),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _etiqueta(etiqueta),
        const SizedBox(height: RtcSpace.s2),
        TextField(
          controller: controller,
          keyboardType: teclado,
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          style: RtcType.sm.copyWith(color: Gray.c900),
          decoration: InputDecoration(
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
          ),
        ),
      ],
    );
  }
}
