import 'package:flutter/material.dart';

import '../../models/court.dart';
import '../../theme/motion.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../rtc_select_field.dart';

/// Port de `Frontend/src/components/dashboard/AvailabilityEditor.tsx`.
///
/// Los siete dias en una fila y, por cada dia encendido, una tarjeta con hora
/// de inicio, de cierre y duracion del turno. En movil la web muestra una
/// tarjeta por dia (la fila de escritorio es `sm:`), asi que eso es lo que va.
class AvailabilityEditor extends StatelessWidget {
  const AvailabilityEditor({
    super.key,
    required this.value,
    required this.onChange,
  });

  final List<AvailabilitySlot> value;
  final ValueChanged<List<AvailabilitySlot>> onChange;

  /// `DAYS`.
  static const dias = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];

  /// `TIME_OPTIONS`: las 24 horas en punto, en formato AM/PM.
  static List<(String, String)> get horas => List.generate(24, (i) {
    final ampm = i < 12 ? 'AM' : 'PM';
    final etiqueta = i == 0
        ? '12:00 AM'
        : i == 12
        ? '12:00 PM'
        : '${(i % 12).toString().padLeft(2, '0')}:00 $ampm';
    return ('${i.toString().padLeft(2, '0')}:00', etiqueta);
  });

  /// `DURATIONS`.
  static const duraciones = <(String, String)>[
    ('60', '1h'),
    ('90', '1.5h'),
    ('120', '2h'),
  ];

  void _alternarDia(int dia) {
    final existe = value.any((s) => s.dayOfWeek == dia);
    final nueva = existe
        ? value.where((s) => s.dayOfWeek != dia).toList()
        : ([
            ...value,
            AvailabilitySlot(
              dayOfWeek: dia,
              openTime: '07:00',
              closeTime: '22:00',
              slotDurationMinutes: 60,
            ),
          ]..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek)));
    onChange(nueva);
  }

  void _actualizar(int dia, {String? abre, String? cierra, int? duracion}) {
    onChange([
      for (final s in value)
        if (s.dayOfWeek == dia)
          AvailabilitySlot(
            dayOfWeek: s.dayOfWeek,
            openTime: abre ?? s.openTime,
            closeTime: cierra ?? s.closeTime,
            slotDurationMinutes: duracion ?? s.slotDurationMinutes,
          )
        else
          s,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // `grid-cols-7 gap-1.5`: los siete dias entran en una sola fila.
        Row(
          children: [
            for (var i = 0; i < dias.length; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(child: _botonDia(i)),
            ],
          ],
        ),
        const SizedBox(height: RtcSpace.s4),
        if (value.isEmpty)
          Text(
            'Selecciona al menos un día de atención.',
            style: RtcType.sm.copyWith(color: Gray.c500),
          )
        else ...[
          Container(height: 1, color: Gray.c200),
          const SizedBox(height: RtcSpace.s3),
          for (final slot in value)
            Padding(
              padding: const EdgeInsets.only(bottom: RtcSpace.s3),
              child: _tarjetaDia(slot),
            ),
        ],
      ],
    );
  }

  Widget _botonDia(int i) {
    final activo = value.any((s) => s.dayOfWeek == i);
    return _Presionable(
      onTap: () => _alternarDia(i),
      child: Container(
        height: 44, // h-11
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: activo ? Green.c50 : Colors.white,
          borderRadius: RtcRadius.brXl,
          border: Border.all(color: activo ? Green.c500 : Gray.c200, width: 2),
        ),
        child: Text(
          dias[i],
          style: RtcType.xs.copyWith(
            fontSize: 11,
            fontWeight: RtcType.bold,
            color: activo ? Green.c700 : Gray.c400,
          ),
        ),
      ),
    );
  }

  Widget _tarjetaDia(AvailabilitySlot slot) {
    return Container(
      padding: const EdgeInsets.all(RtcSpace.s3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RtcRadius.brXl,
        border: Border.all(color: Gray.c200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dias[slot.dayOfWeek].toUpperCase(),
            style: RtcType.xs.copyWith(
              fontWeight: FontWeight.w900,
              color: Gray.c700,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: RtcSpace.s2),
          Row(
            children: [
              Expanded(
                child: _campo(
                  'Inicio',
                  RtcSelectField(
                    value: slot.openTime,
                    opciones: horas,
                    compacto: true,
                    titulo: 'Hora de inicio · ${dias[slot.dayOfWeek]}',
                    onChange: (v) => _actualizar(slot.dayOfWeek, abre: v),
                  ),
                ),
              ),
              const SizedBox(width: RtcSpace.s2),
              Expanded(
                child: _campo(
                  'Fin',
                  RtcSelectField(
                    value: slot.closeTime,
                    opciones: horas,
                    compacto: true,
                    titulo: 'Hora de cierre · ${dias[slot.dayOfWeek]}',
                    onChange: (v) => _actualizar(slot.dayOfWeek, cierra: v),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: RtcSpace.s2),
          _campo(
            'Duración',
            RtcSelectField(
              value: '${slot.slotDurationMinutes}',
              opciones: duraciones,
              compacto: true,
              titulo: 'Duración del turno · ${dias[slot.dayOfWeek]}',
              onChange: (v) =>
                  _actualizar(slot.dayOfWeek, duracion: int.tryParse(v) ?? 60),
            ),
          ),
        ],
      ),
    );
  }

  Widget _campo(String etiqueta, Widget hijo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta, style: RtcType.xs.copyWith(color: Gray.c500)),
        const SizedBox(height: 4),
        hijo,
      ],
    );
  }
}

/// `whileTap={{ scale: 0.92 }}` de los botones de dia.
class _Presionable extends StatefulWidget {
  const _Presionable({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_Presionable> createState() => _PresionableState();
}

class _PresionableState extends State<_Presionable> {
  bool _abajo = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _abajo = true),
      onTapUp: (_) => setState(() => _abajo = false),
      onTapCancel: () => setState(() => _abajo = false),
      child: AnimatedScale(
        scale: _abajo ? 0.92 : 1,
        duration: RtcDur.pick,
        curve: RtcCurves.smooth,
        child: widget.child,
      ),
    );
  }
}
