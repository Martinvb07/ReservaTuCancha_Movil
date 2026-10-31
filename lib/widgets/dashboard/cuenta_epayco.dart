/// Port de `Frontend/src/components/dashboard/CuentaEpayco.tsx`.
///
/// Reemplaza al asistente de datos bancarios: con pagos divididos la plata ya
/// no pasa por la cuenta de ReservaTuCancha, ePayco le consigna al club
/// directo en el momento del cobro. Por eso lo que hace falta no es un numero
/// de cuenta sino el id del club como receptor.
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

const _pasos = [
  'Crea tu cuenta en ePayco con el RUT y la Cámara de Comercio del club.',
  'En tu panel de ePayco, regístrate como comercio y también como receptor.',
  'Agrega a ReservaTuCancha como comercio asociado.',
  'Copia tu ID de cliente (P_CUST_ID_CLIENTE) y pégalo acá abajo.',
];

/// Mismo criterio que valida el backend: solo digitos. Avisar aca evita que el
/// club se entere del error en el primer cobro fallido.
final _idValido = RegExp(r'^\d{3,32}$');

class CuentaEpayco extends StatefulWidget {
  const CuentaEpayco({
    super.key,
    required this.actual,
    required this.guardando,
    required this.onGuardar,
  });

  /// Id ya registrado, si el club lo tiene.
  final String? actual;
  final bool guardando;
  final ValueChanged<String> onGuardar;

  @override
  State<CuentaEpayco> createState() => _CuentaEpaycoState();
}

class _CuentaEpaycoState extends State<CuentaEpayco> {
  late final _controller = TextEditingController(text: widget.actual ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _valor => _controller.text.trim();
  bool get _listo => (widget.actual ?? '').isNotEmpty;
  bool get _valido => _idValido.hasMatch(_valor);
  bool get _puedeGuardar =>
      _valido && !widget.guardando && _valor != (widget.actual ?? '');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_listo) ...[_conectada(), const SizedBox(height: RtcSpace.s5)],
        Container(
          padding: const EdgeInsets.all(RtcSpace.s5),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Gray.c200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cabecera(),
              const SizedBox(height: RtcSpace.s5),
              for (var i = 0; i < _pasos.length; i++) ...[
                _paso(i + 1, _pasos[i]),
                if (i < _pasos.length - 1) const SizedBox(height: 10),
              ],
              const SizedBox(height: RtcSpace.s4),
              _abrirCuenta(),
              const SizedBox(height: RtcSpace.s6),
              const Divider(height: 1, color: Gray.c100),
              const SizedBox(height: RtcSpace.s5),
              _campo(),
              const SizedBox(height: RtcSpace.s4),
              _boton(),
              if (!_listo) ...[
                const SizedBox(height: RtcSpace.s3),
                Text(
                  'Mientras no conectes tu cuenta, tus canchas no pueden recibir '
                  'reservas pagadas en línea.',
                  textAlign: TextAlign.center,
                  style: RtcType.xs.copyWith(color: Gray.c400, height: 1.35),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _conectada() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s4,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: Green.c50,
        borderRadius: RtcRadius.brXxl,
        border: Border.all(color: const Color(0xFFBBF7D0)), // green-200
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.circleCheck, size: 20, color: Green.c600),
          const SizedBox(width: RtcSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu cuenta está conectada',
                  style: RtcType.sm.copyWith(
                    fontWeight: RtcType.bold,
                    color: const Color(0xFF14532D), // green-900
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Cada reserva se te consigna directo, sin esperar a fin de '
                  'semana.',
                  style: RtcType.xs.copyWith(color: Green.c700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cabecera() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Gray.c900,
            borderRadius: RtcRadius.brXl,
          ),
          child: const Icon(
            LucideIcons.shieldCheck,
            size: 20,
            color: Lime.c400,
          ),
        ),
        const SizedBox(width: RtcSpace.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CUENTA DE EPAYCO',
                style: RtcType.sm.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Gray.c900,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'El pago de cada reserva se divide en el momento: a ti te llega '
                'tu parte y a nosotros la nuestra. Para eso necesitas tu propia '
                'cuenta de ePayco.',
                style: RtcType.sm.copyWith(color: Gray.c500, height: 1.35),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _paso(int n, String texto) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          margin: const EdgeInsets.only(top: 1),
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Gray.c100,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$n',
            style: RtcType.xs.copyWith(
              fontSize: 11,
              fontWeight: RtcType.bold,
              color: Gray.c600,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            texto,
            style: RtcType.sm.copyWith(color: Gray.c700, height: 1.35),
          ),
        ),
      ],
    );
  }

  Widget _abrirCuenta() {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => launchUrl(
          Uri.parse('https://epayco.com/registro'),
          mode: LaunchMode.externalApplication,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Abrir cuenta en ePayco',
              style: RtcType.sm.copyWith(
                fontWeight: RtcType.semibold,
                color: Green.c700,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(LucideIcons.externalLink, size: 14, color: Green.c700),
          ],
        ),
      ),
    );
  }

  Widget _campo() {
    final borde = OutlineInputBorder(
      borderRadius: RtcRadius.brXl,
      borderSide: const BorderSide(color: Gray.c200),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Tu ID de cliente en ePayco',
          style: RtcType.xs.copyWith(
            fontWeight: RtcType.semibold,
            color: Gray.c500,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          style: RtcType.sm.copyWith(color: Gray.c900),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Ej: 1234567',
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
        if (_valor.isNotEmpty && !_valido) ...[
          const SizedBox(height: 6),
          Text(
            'El ID de ePayco son solo números, sin espacios ni guiones.',
            style: RtcType.xs.copyWith(color: Red.c500),
          ),
        ],
      ],
    );
  }

  Widget _boton() {
    return Opacity(
      opacity: _puedeGuardar || widget.guardando ? 1 : 0.4,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _puedeGuardar ? () => widget.onGuardar(_valor) : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Green.c600,
            borderRadius: RtcRadius.brXxl,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.guardando)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              else
                const Icon(LucideIcons.save, size: 16, color: Colors.white),
              const SizedBox(width: RtcSpace.s2),
              Text(
                widget.guardando
                    ? 'Guardando…'
                    : _listo
                    ? 'Actualizar'
                    : 'Conectar mi cuenta',
                style: RtcType.base.copyWith(
                  fontWeight: RtcType.semibold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
