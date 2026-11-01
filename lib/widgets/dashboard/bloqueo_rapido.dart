import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/owner_api.dart';
import '../../api/rtc_api.dart';
import '../../models/court.dart';
import '../../models/fechas.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../rtc_toast.dart';

/// Bloquear un horario sin salir del calendario: se abre manteniendo
/// presionado un dia. Es el mismo bloqueo de la pantalla de Bloqueos.
Future<void> abrirBloqueoRapido(BuildContext context, DateTime dia) {
  HapticFeedback.mediumImpact();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BloqueoRapido(dia: dia),
  );
}

/// De 6:00 a 23:00, cada hora.
final _horas = [
  for (var h = 6; h <= 23; h++) '${h.toString().padLeft(2, '0')}:00',
];

class _BloqueoRapido extends StatefulWidget {
  const _BloqueoRapido({required this.dia});

  final DateTime dia;

  @override
  State<_BloqueoRapido> createState() => _BloqueoRapidoState();
}

class _BloqueoRapidoState extends State<_BloqueoRapido> {
  List<Court> _canchas = const [];
  String? _cancha;
  String? _desde;
  String? _hasta;
  final _motivo = TextEditingController(text: 'Mantenimiento');
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    ownerApi.misCanchas().then((c) {
      if (!mounted) return;
      setState(() {
        _canchas = c;
        if (c.length == 1) _cancha = c.first.id;
      });
    });
  }

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  bool get _valido =>
      _cancha != null &&
      _desde != null &&
      _hasta != null &&
      _hasta!.compareTo(_desde!) > 0;

  Future<void> _guardar() async {
    if (!_valido || _guardando) return;
    setState(() => _guardando = true);
    try {
      await ownerApi.crearBloqueo(
        courtId: _cancha!,
        fecha: fechaIso(widget.dia),
        horaInicio: _desde!,
        horaFin: _hasta!,
        motivo: _motivo.text.trim().isEmpty ? 'Bloqueado' : _motivo.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      rtcToast(context, 'Horario bloqueado');
    } on RtcApiException catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      rtcToast(context, e.message, tipo: RtcToastTipo.error);
    }
  }

  Widget _chips(
    String? elegido,
    ValueChanged<String> onTap, {
    String? despuesDe,
  }) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _horas.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final h = _horas[i];
          final off = despuesDe != null && h.compareTo(despuesDe) <= 0;
          final activo = h == elegido;
          return GestureDetector(
            onTap: off ? null : () => onTap(h),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: activo ? Gray.c900 : Fondo.app,
                borderRadius: RtcRadius.brFull,
              ),
              child: Text(
                hora12(h),
                style: RtcType.xs.copyWith(
                  fontWeight: RtcType.semibold,
                  color: activo
                      ? Colors.white
                      : off
                      ? Gray.c300
                      : Gray.c700,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final abajo = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: abajo),
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
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
              const SizedBox(height: 14),
              Row(
                children: [
                  const Icon(LucideIcons.lock, size: 18, color: Gray.c900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Bloquear el ${fechaLargaCapitalizada(widget.dia)}',
                      style: RtcType.base.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Gray.c900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Cancha', style: RtcType.xs.copyWith(color: Gray.c500)),
              const SizedBox(height: 6),
              if (_canchas.isEmpty)
                const LinearProgressIndicator(color: Green.c600)
              else
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in _canchas)
                      ChoiceChip(
                        label: Text(c.name),
                        selected: _cancha == c.id,
                        onSelected: (_) => setState(() => _cancha = c.id),
                        selectedColor: Green.c600,
                        labelStyle: RtcType.xs.copyWith(
                          color: _cancha == c.id ? Colors.white : Gray.c800,
                          fontWeight: RtcType.semibold,
                        ),
                        showCheckmark: false,
                      ),
                  ],
                ),
              const SizedBox(height: 14),
              Text('Desde', style: RtcType.xs.copyWith(color: Gray.c500)),
              const SizedBox(height: 6),
              _chips(
                _desde,
                (h) => setState(() {
                  _desde = h;
                  if (_hasta != null && _hasta!.compareTo(h) <= 0) {
                    _hasta = null;
                  }
                }),
              ),
              const SizedBox(height: 12),
              Text('Hasta', style: RtcType.xs.copyWith(color: Gray.c500)),
              const SizedBox(height: 6),
              _chips(
                _hasta,
                (h) => setState(() => _hasta = h),
                despuesDe: _desde,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _motivo,
                style: RtcType.sm.copyWith(color: Gray.c900),
                decoration: InputDecoration(
                  labelText: 'Motivo',
                  filled: true,
                  fillColor: Fondo.app,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Opacity(
                opacity: _valido ? 1 : 0.4,
                child: GestureDetector(
                  onTap: _valido ? _guardar : null,
                  child: Container(
                    height: 52,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Gray.c900,
                      borderRadius: RtcRadius.brFull,
                    ),
                    child: _guardando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Bloquear horario',
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
        ),
      ),
    );
  }
}
