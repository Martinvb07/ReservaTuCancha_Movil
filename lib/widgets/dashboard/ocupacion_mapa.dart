import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/owner_api.dart';
import '../../api/rtc_api.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';

/// Port de `Frontend/src/components/dashboard/OcupacionHeatmap.tsx`: qué tan
/// llenas están las canchas por día de la semana y hora.
class OcupacionMapa extends StatefulWidget {
  const OcupacionMapa({super.key});

  @override
  State<OcupacionMapa> createState() => _OcupacionMapaState();
}

/// Lunes primero: así lee la semana un club.
const _ordenDias = [1, 2, 3, 4, 5, 6, 0];
const _dias = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];

String _hora12(int h) => '${h % 12 == 0 ? 12 : h % 12}${h < 12 ? 'am' : 'pm'}';

/// Escala de un solo tono: más oscuro = más lleno.
(Color, Color) _color(double pct) {
  if (pct >= 80) return (Green.c700, Colors.white);
  if (pct >= 60) return (Green.c600, Colors.white);
  if (pct >= 40) return (Green.c400, Green.c950);
  if (pct >= 20) return (Green.c200, Green.c900);
  if (pct > 0) return (Green.c100, Green.c800);
  return (Gray.c50, Gray.c400);
}

class _OcupacionMapaState extends State<OcupacionMapa> {
  int _semanas = 8;
  Ocupacion? _datos;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final d = await ownerApi.ocupacion(semanas: _semanas);
      if (!mounted) return;
      setState(() {
        _datos = d;
        _cargando = false;
      });
    } on RtcApiException {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _datos;
    return Container(
      padding: const EdgeInsets.all(RtcSpace.s5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RtcRadius.brXxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.grid3x3, size: 18, color: Green.c600),
              const SizedBox(width: RtcSpace.s2),
              Expanded(
                child: Text(
                  'OCUPACIÓN POR HORA',
                  style: RtcType.sm.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Gray.c900,
                  ),
                ),
              ),
              DropdownButton<int>(
                value: _semanas,
                underline: const SizedBox.shrink(),
                style: RtcType.xs.copyWith(
                  fontWeight: RtcType.semibold,
                  color: Gray.c700,
                ),
                items: [
                  for (final n in [4, 8, 12, 26])
                    DropdownMenuItem(value: n, child: Text('$n semanas')),
                ],
                onChanged: (v) {
                  if (v == null) return;
                  _semanas = v;
                  _cargar();
                },
              ),
            ],
          ),
          Text(
            'Horas reservadas sobre las que podías vender',
            style: RtcType.xs.copyWith(color: Gray.c500),
          ),
          const SizedBox(height: RtcSpace.s4),
          if (_cargando)
            Container(
              height: 180,
              decoration: BoxDecoration(
                color: Gray.c100,
                borderRadius: RtcRadius.brXl,
              ),
            )
          else if (d == null || d.horasCapacidad == 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: RtcSpace.s6),
              child: Text(
                'Configura el horario de tus canchas para ver la ocupación.',
                textAlign: TextAlign.center,
                style: RtcType.sm.copyWith(color: Gray.c500),
              ),
            )
          else ...[
            Row(
              children: [
                _cifra('Ocupación', '${d.pctTotal.round()}%'),
                const SizedBox(width: RtcSpace.s2),
                _cifra('Vendidas', '${d.horasOcupadas.round()} h'),
                const SizedBox(width: RtcSpace.s2),
                _cifra(
                  'Vacías',
                  '${(d.horasCapacidad - d.horasOcupadas).clamp(0, double.infinity).round()} h',
                ),
              ],
            ),
            const SizedBox(height: RtcSpace.s4),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 34),
                      for (final h in d.horas)
                        SizedBox(
                          width: 37,
                          child: Text(
                            _hora12(h),
                            textAlign: TextAlign.center,
                            style: RtcType.xs.copyWith(
                              fontSize: 11,
                              color: Gray.c500,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  for (final dia in _ordenDias)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 34,
                            child: Text(
                              _dias[dia],
                              style: RtcType.xs.copyWith(
                                fontSize: 11,
                                fontWeight: RtcType.bold,
                                color: Gray.c500,
                              ),
                            ),
                          ),
                          for (final h in d.horas) _celda(d.celda(dia, h)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: RtcSpace.s4),
            _lista(
              'Franjas que más se quedan vacías',
              LucideIcons.moon,
              d.horasVacias,
            ),
            if (d.horasPico.isNotEmpty) ...[
              const SizedBox(height: RtcSpace.s3),
              _lista('Horas pico', LucideIcons.flame, d.horasPico),
            ],
          ],
        ],
      ),
    );
  }

  Widget _cifra(String etiqueta, String valor) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(RtcSpace.s3),
      decoration: BoxDecoration(color: Gray.c50, borderRadius: RtcRadius.brXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta.toUpperCase(),
            style: RtcType.xs.copyWith(
              fontSize: 11,
              fontWeight: RtcType.bold,
              color: Gray.c500,
            ),
          ),
          Text(
            valor,
            style: RtcType.xl.copyWith(
              fontWeight: FontWeight.w900,
              color: Gray.c900,
            ),
          ),
        ],
      ),
    ),
  );

  Widget _celda(CeldaOcupacion? c) {
    if (c == null || c.capacidad == 0) {
      return Container(
        width: 34,
        height: 30,
        margin: const EdgeInsets.only(right: 3),
        decoration: BoxDecoration(
          borderRadius: RtcRadius.brSm,
          border: Border.all(color: Gray.c100),
        ),
      );
    }
    final (fondo, texto) = _color(c.pct);
    return Tooltip(
      message: '${c.ocupado} de ${c.capacidad} h (${c.pct}%)',
      child: Container(
        width: 34,
        height: 30,
        margin: const EdgeInsets.only(right: 3),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: fondo, borderRadius: RtcRadius.brSm),
        child: Text(
          '${c.pct.round()}',
          style: RtcType.xs.copyWith(
            fontSize: 11,
            fontWeight: RtcType.bold,
            color: texto,
          ),
        ),
      ),
    );
  }

  Widget _lista(String titulo, IconData icono, List<CeldaOcupacion> celdas) {
    return Container(
      padding: const EdgeInsets.all(RtcSpace.s3),
      decoration: BoxDecoration(
        borderRadius: RtcRadius.brXl,
        border: Border.all(color: Gray.c100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icono, size: 14, color: Gray.c600),
              const SizedBox(width: 6),
              Text(
                titulo.toUpperCase(),
                style: RtcType.xs.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Gray.c900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final c in celdas)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_dias[c.dia]} ${_hora12(c.hora)}',
                      style: RtcType.xs.copyWith(color: Gray.c600),
                    ),
                  ),
                  Text(
                    '${c.pct.round()}%',
                    style: RtcType.xs.copyWith(
                      fontWeight: RtcType.bold,
                      color: Gray.c700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
