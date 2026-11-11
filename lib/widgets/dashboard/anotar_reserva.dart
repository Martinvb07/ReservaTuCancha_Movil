import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/owner_api.dart';
import '../../api/rtc_api.dart';
import '../../models/court.dart';
import '../../models/fechas.dart';
import '../../models/precios.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../rtc_toast.dart';
import '../motion/rtc_pressable.dart';

/// Abre la hoja para anotar una reserva que llegó por teléfono o al mostrador.
/// Devuelve true si se anotó algo (para recargar la lista).
Future<bool> abrirAnotarReserva(BuildContext context) async {
  final ok = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Superficie.tarjeta,
    builder: (ctx) => const _AnotarReserva(),
  );
  return ok == true;
}

/// Port de `Frontend/src/components/dashboard/ReservaManualDialog.tsx`.
///
/// Ocupa el horario para que nadie más lo pague en línea; el cobro queda en
/// el club, sin ePayco ni comisión.
class _AnotarReserva extends StatefulWidget {
  const _AnotarReserva();

  @override
  State<_AnotarReserva> createState() => _AnotarReservaState();
}

class _AnotarReservaState extends State<_AnotarReserva> {
  final _nombre = TextEditingController();
  final _telefono = TextEditingController();
  final _email = TextEditingController();
  final _notas = TextEditingController();
  final _precio = TextEditingController();

  List<Court> _canchas = const [];
  String? _courtId;
  DateTime _fecha = DateTime.now();
  TimeOfDay _desde = const TimeOfDay(hour: 19, minute: 0);
  TimeOfDay _hasta = const TimeOfDay(hour: 20, minute: 0);
  int _semanas = 1;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    ownerApi
        .misCanchas()
        .then((c) {
          if (!mounted) return;
          setState(() {
            _canchas = c;
            _courtId ??= c.isNotEmpty ? c.first.id : null;
          });
        })
        .catchError((_) {});
  }

  @override
  void dispose() {
    for (final c in [_nombre, _telefono, _email, _notas, _precio]) {
      c.dispose();
    }
    super.dispose();
  }

  String _hhmm(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  int get _minutos =>
      (_hasta.hour * 60 + _hasta.minute) - (_desde.hour * 60 + _desde.minute);

  int get _precioLista {
    final cancha = _canchas.where((c) => c.id == _courtId).firstOrNull;
    if (cancha == null || _minutos <= 0) return 0;
    return precioTurno(
      cancha.pricePerHour,
      cancha.priceRules,
      diaSemanaJs(_fecha),
      _hhmm(_desde),
      _hhmm(_hasta),
    );
  }

  bool get _listo =>
      _courtId != null && _nombre.text.trim().length >= 2 && _minutos > 0;

  Future<void> _guardar() async {
    if (!_listo || _guardando) return;
    HapticFeedback.mediumImpact();
    setState(() => _guardando = true);
    try {
      final n = await ownerApi.anotarReserva(
        courtId: _courtId!,
        date: fechaIso(_fecha),
        startTime: _hhmm(_desde),
        endTime: _hhmm(_hasta),
        guestName: _nombre.text,
        guestPhone: _telefono.text,
        guestEmail: _email.text,
        notes: _notas.text,
        semanas: _semanas,
        precio: int.tryParse(_precio.text.replaceAll(RegExp(r'\D'), '')),
      );
      if (!mounted) return;
      rtcToast(
        context,
        n > 1 ? 'Turno fijo anotado: $n semanas' : 'Reserva anotada',
      );
      Navigator.of(context).pop(true);
    } on RtcApiException catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      rtcToast(context, e.message, tipo: RtcToastTipo.error);
    }
  }

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: RtcRadius.brXl,
      borderSide: BorderSide(color: Gray.c200),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: RtcRadius.brXl,
      borderSide: BorderSide(color: Gray.c200),
    ),
  );

  Widget _etiqueta(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      t,
      style: RtcType.xs.copyWith(
        fontWeight: RtcType.semibold,
        color: Gray.c500,
      ),
    ),
  );

  Widget _boton(String texto, VoidCallback onTap) => RtcPressable(
    behavior: HitTestBehavior.opaque,
    onTap: onTap,
    child: Container(
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: RtcRadius.brXl,
        border: Border.all(color: Gray.c200),
      ),
      child: Text(
        texto,
        style: RtcType.sm.copyWith(
          fontWeight: RtcType.semibold,
          color: Gray.c900,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        RtcSpace.s5,
        0,
        RtcSpace.s5,
        MediaQuery.of(context).viewInsets.bottom + RtcSpace.s5,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.phoneCall, size: 20, color: Green.c600),
                const SizedBox(width: RtcSpace.s2),
                Text(
                  'ANOTAR RESERVA',
                  style: RtcType.lg.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Gray.c900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Para las que te piden por teléfono o en el mostrador. Bloquea el horario '
              'en la web y la app, y la cobras tú en el club.',
              style: RtcType.xs.copyWith(color: Gray.c500),
            ),
            const SizedBox(height: RtcSpace.s4),
            _etiqueta('Cancha'),
            DropdownButtonFormField<String>(
              initialValue: _courtId,
              isExpanded: true,
              decoration: _deco('Cancha'),
              items: [
                for (final c in _canchas)
                  DropdownMenuItem(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) => setState(() => _courtId = v),
            ),
            const SizedBox(height: RtcSpace.s3),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _etiqueta('Fecha'),
                      _boton(diaFechaCorta(_fecha), () async {
                        final hoy = DateTime.now();
                        final f = await showDatePicker(
                          context: context,
                          initialDate: _fecha,
                          firstDate: DateTime(hoy.year, hoy.month, hoy.day),
                          lastDate: hoy.add(const Duration(days: 365)),
                        );
                        if (f != null) setState(() => _fecha = f);
                      }),
                    ],
                  ),
                ),
                const SizedBox(width: RtcSpace.s2),
                for (final (i, etiqueta) in [(0, 'Desde'), (1, 'Hasta')]) ...[
                  if (i == 1) const SizedBox(width: RtcSpace.s2),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _etiqueta(etiqueta),
                        _boton(
                          hora12(_hhmm(i == 0 ? _desde : _hasta)),
                          () async {
                            final t = await showTimePicker(
                              context: context,
                              initialTime: i == 0 ? _desde : _hasta,
                            );
                            if (t != null) {
                              setState(() => i == 0 ? _desde = t : _hasta = t);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: RtcSpace.s3),
            _etiqueta('A nombre de'),
            TextField(
              controller: _nombre,
              decoration: _deco("Ej: Carlos o 'Equipo de los martes'"),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: RtcSpace.s3),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _etiqueta('Celular (opcional)'),
                      TextField(
                        controller: _telefono,
                        keyboardType: TextInputType.phone,
                        decoration: _deco('300 123 4567'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: RtcSpace.s2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _etiqueta('Correo (opcional)'),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        decoration: _deco('para el recordatorio'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: RtcSpace.s3),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _etiqueta('Repetir'),
                      DropdownButtonFormField<int>(
                        initialValue: _semanas,
                        isExpanded: true,
                        decoration: _deco(''),
                        items: [
                          const DropdownMenuItem(
                            value: 1,
                            child: Text('Solo esta fecha'),
                          ),
                          for (final n in [4, 8, 12, 26])
                            DropdownMenuItem(
                              value: n,
                              child: Text('$n semanas'),
                            ),
                        ],
                        onChanged: (v) => setState(() => _semanas = v ?? 1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: RtcSpace.s2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _etiqueta('Cobras (por fecha)'),
                      TextField(
                        controller: _precio,
                        keyboardType: TextInputType.number,
                        decoration: _deco(
                          _precioLista > 0
                              ? '\$${formatCop(_precioLista)}'
                              : 'Precio de lista',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: RtcSpace.s3),
            _etiqueta('Notas (opcional)'),
            TextField(controller: _notas, maxLines: 2, decoration: _deco('')),
            const SizedBox(height: RtcSpace.s4),
            FilledButton(
              style: FilledButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Green.c600,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: RtcRadius.brXl),
              ),
              onPressed: _listo && !_guardando ? _guardar : null,
              child: Text(
                _guardando
                    ? 'Anotando…'
                    : _semanas > 1
                    ? 'Anotar $_semanas semanas'
                    : 'Anotar reserva',
              ),
            ),
            const SizedBox(height: RtcSpace.s2),
            Text(
              'No pasa por ePayco ni tiene comisión. Si alguna fecha ya está ocupada, no se anota ninguna y te decimos cuál.',
              textAlign: TextAlign.center,
              style: RtcType.xs.copyWith(fontSize: 11, color: Gray.c500),
            ),
          ],
        ),
      ),
    );
  }
}
