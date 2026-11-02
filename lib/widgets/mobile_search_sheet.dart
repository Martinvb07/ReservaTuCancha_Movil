import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/routes.dart';
import '../models/court.dart';
import '../models/fechas.dart';
import '../theme/motion.dart';
import '../theme/palette.dart';
import '../theme/shadows.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import 'floating_actions.dart';
import 'icons/city_glyph.dart';
import 'icons/sport_icon.dart';
import 'motion/rtc_motion.dart';
import 'motion/rtc_pressable.dart';

/// Port de `MobileSearchSheet.tsx` + la rama `mobile` de `HeroSearch.tsx`.
///
/// Cuatro tarjetas apiladas estilo Airbnb: la abierta es una tarjeta grande con
/// su titulo, las demas quedan como filas colapsadas con el valor a la derecha.
/// Lo que la hoja devuelve al tocar Buscar. `date` va en `yyyy-MM-dd`.
typedef _Busqueda = ({String sport, String city, String date, String start});

/// Abre el buscador. Los `initial*` son los `SearchDefaults` de la web: desde
/// la pantalla de canchas la hoja arranca con la busqueda que ya esta puesta.
Future<void> showMobileSearchSheet(
  BuildContext context, {
  String? sport,
  String? city,
  String? date,
  String? time,
}) async {
  // Los flotantes se pintan encima de esta hoja y le tapan el boton de
  // Buscar; se esconden mientras dure.
  FloatingActions.hojaAbierta.value = true;
  _Busqueda? busqueda;
  try {
    busqueda = await _abrirHoja(
      context,
      sport: sport,
      city: city,
      date: date,
      time: time,
    );
  } finally {
    FloatingActions.hojaAbierta.value = false;
  }
  // `search()` de HeroSearch: la hoja se cierra y se va a /empresas con lo
  // elegido. Cerrarla con la X o tocando afuera no busca nada.
  if (busqueda != null) {
    rtcBuscarCanchas(
      sport: busqueda.sport,
      city: busqueda.city,
      date: busqueda.date,
      start: busqueda.start,
    );
  }
}

Future<_Busqueda?> _abrirHoja(
  BuildContext context, {
  String? sport,
  String? city,
  String? date,
  String? time,
}) {
  return showGeneralDialog<_Busqueda>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar búsqueda',
    // El velo lo pinta el sheet, porque ademas lleva blur.
    barrierColor: Colors.transparent,
    transitionDuration: RtcDur.sheetIn,
    pageBuilder: (_, _, _) => _MobileSearchSheet(
      initialSport: sport,
      initialCity: city,
      initialDate: date,
      initialTime: time,
    ),
    transitionBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

// ───────────────────────────────────────────────────────────────────────────
// Metadatos — copiados de HeroSearch.tsx y constants.ts
// ───────────────────────────────────────────────────────────────────────────

/// `SPORT_META`: frase y tile de color por deporte.
const _sportMeta = <String, ({String tag, Color bg, Color color})>{
  'futbol': (
    tag: 'El clásico de siempre',
    bg: Color(0xFFE8F5E9),
    color: Color(0xFF2E7D32),
  ),
  'padel': (
    tag: 'El deporte que más crece',
    bg: Color(0xFFE3F2FD),
    color: Color(0xFF1565C0),
  ),
  'voley_playa': (
    tag: 'Arena, sol y equipo',
    bg: Color(0xFFFFF8E1),
    color: Color(0xFFEF6C00),
  ),
};

/// `CITY_META`: departamento y tile de color por ciudad.
const _cityMeta = <String, ({String dept, Color bg, Color color})>{
  'villavicencio': (
    dept: 'Meta',
    bg: Color(0xFFE3F2FD),
    color: Color(0xFF1565C0),
  ),
  'acacias': (dept: 'Meta', bg: Color(0xFFE8F5E9), color: Color(0xFF2E7D32)),
  'restrepo': (dept: 'Meta', bg: Color(0xFFFFF8E1), color: Color(0xFFE65100)),
  'bogota': (
    dept: 'Cundinamarca',
    bg: Color(0xFFEDE7F6),
    color: Color(0xFF4527A0),
  ),
  'medellin': (
    dept: 'Antioquia',
    bg: Color(0xFFFCE4EC),
    color: Color(0xFFC62828),
  ),
  'cali': (
    dept: 'Valle del Cauca',
    bg: Color(0xFFFFF3E0),
    color: Color(0xFFEF6C00),
  ),
  'barranquilla': (
    dept: 'Atlántico',
    bg: Color(0xFFE0F7FA),
    color: Color(0xFF00838F),
  ),
  'bucaramanga': (
    dept: 'Santander',
    bg: Color(0xFFE8F5E9),
    color: Color(0xFF1B5E20),
  ),
};

/// `CITIES` de constants.ts.
const _cities = [
  'Villavicencio',
  'Acacías',
  'Restrepo',
  'Bogotá',
  'Medellín',
  'Cali',
  'Barranquilla',
  'Bucaramanga',
];

/// `HOURS`: 06:00 a 23:00, guardadas en 24h.
final _hours = [
  for (var i = 6; i < 24; i++) '${i.toString().padLeft(2, '0')}:00',
];

/// `DOW` del mini calendario — la semana arranca en lunes.
const _dow = ['Lu', 'Ma', 'Mi', 'Ju', 'Vi', 'Sá', 'Do'];

const _monthsFull = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];
const _monthsAbbr = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// `EEE` con locale es de date-fns.
const _dowAbbr = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

/// Muestra la hora en 12h, igual que `to12h`. Internamente se guarda "HH:mm".
String _to12h(String t) {
  if (t.isEmpty) return '';
  final parts = t.split(':').map(int.parse).toList();
  final h = parts[0], m = parts[1];
  final period = h < 12 ? 'AM' : 'PM';
  final hh = h % 12 == 0 ? 12 : h % 12;
  return '$hh:${m.toString().padLeft(2, '0')} $period';
}

/// `format(date, "EEE d 'de' MMM")` de date-fns.
String _dateLabel(DateTime d) =>
    '${_dowAbbr[d.weekday - 1]} ${d.day} de ${_monthsAbbr[d.month - 1]}';

/// Equivalente de `text-transform: capitalize` de Tailwind: primera letra de
/// CADA palabra. La web lo aplica al valor de la fila colapsada.
String _capitalize(String s) => s
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

// ───────────────────────────────────────────────────────────────────────────

class _MobileSearchSheet extends StatefulWidget {
  const _MobileSearchSheet({
    this.initialSport,
    this.initialCity,
    this.initialDate,
    this.initialTime,
  });

  final String? initialSport;
  final String? initialCity;

  /// `yyyy-MM-dd`, como viaja en la URL.
  final String? initialDate;
  final String? initialTime;

  @override
  State<_MobileSearchSheet> createState() => _MobileSearchSheetState();
}

class _MobileSearchSheetState extends State<_MobileSearchSheet> {
  late String _sport = widget.initialSport ?? '';
  late String _city = widget.initialCity ?? '';

  /// La web solo acepta la fecha si viene en `yyyy-MM-dd`; si no, arranca
  /// vacia.
  late DateTime? _date = (() {
    final d = widget.initialDate ?? '';
    return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(d)
        ? DateTime.tryParse(d)
        : null;
  })();
  late String _time = widget.initialTime ?? '';

  /// Panel abierto; el resto de las tarjetas quedan colapsadas.
  String? _panel = 'deporte';

  /// `ready` de la web: alcanza con UN campo, no con los cuatro.
  bool get _ready =>
      _sport.isNotEmpty ||
      _city.isNotEmpty ||
      _date != null ||
      _time.isNotEmpty;

  void _toggle(String p) => setState(() => _panel = _panel == p ? null : p);

  void _clearAll() => setState(() {
    _sport = '';
    _city = '';
    _date = null;
    _time = '';
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          // bg-black/45 backdrop-blur-lg — tocarlo cierra
          Positioned.fill(
            child: RtcPressable(
              onTap: () => Navigator.of(context).pop(),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s4),
              child: ListView(
                // pt-20 pb-6 del contenedor + pb-24 del stack por la barra fija
                padding: const EdgeInsets.only(top: 72, bottom: 120),
                children: [
                  RtcStagger(
                    children: [
                      _panelOrRow(
                        key: 'deporte',
                        label: 'Deporte',
                        title: '¿Qué juegas?',
                        value: _sport.isEmpty
                            ? 'Elige tu deporte'
                            : getSport(_sport).label,
                        filled: _sport.isNotEmpty,
                        body: _sportList(),
                      ),
                      const SizedBox(height: RtcSpace.s3),
                      _panelOrRow(
                        key: 'ciudad',
                        label: 'Ciudad',
                        title: '¿Dónde?',
                        value: _city.isEmpty ? 'Elige tu ciudad' : _city,
                        filled: _city.isNotEmpty,
                        body: _cityList(),
                      ),
                      const SizedBox(height: RtcSpace.s3),
                      _panelOrRow(
                        key: 'fecha',
                        label: 'Fecha',
                        title: '¿Cuándo?',
                        value: _date == null ? '¿Qué día?' : _dateLabel(_date!),
                        filled: _date != null,
                        body: _MiniCalendar(
                          value: _date,
                          onPick: (d) => setState(() {
                            _date = d;
                            _panel = 'hora';
                          }),
                          onClear: () => setState(() => _date = null),
                        ),
                        // El calendario trae su propio padding.
                        bodyPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: RtcSpace.s3),
                      _panelOrRow(
                        key: 'hora',
                        label: 'Hora',
                        title: '¿A qué hora?',
                        value: _time.isEmpty ? 'Cualquier hora' : _to12h(_time),
                        filled: _time.isNotEmpty,
                        body: _timeList(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Barra fija inferior: Limpiar + Buscar ──────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                14 + MediaQuery.paddingOf(context).bottom,
              ),
              decoration: BoxDecoration(
                color: Superficie.tarjeta,
                border: Border(top: BorderSide(color: Gray.c100)),
                boxShadow: [
                  cssShadow(
                    dy: -4,
                    blur: 20,
                    color: const Color(0xFF140E1E).withValues(alpha: 0.07),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  RtcPressable(
                    onTap: _clearAll,
                    child: Text(
                      'Limpiar',
                      style: RtcType.base.copyWith(
                        fontSize: 15,
                        fontWeight: RtcType.bold,
                        color: Gray.c900,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  GestureDetector(
                    // Antes solo cerraba la hoja: la busqueda se perdia.
                    onTap: _ready
                        ? () => Navigator.of(context).pop<_Busqueda>((
                            sport: _sport,
                            city: _city,
                            date: _date == null ? '' : fechaIso(_date!),
                            start: _time,
                          ))
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: Green.c600,
                        borderRadius: RtcRadius.brXxl,
                        boxShadow: [
                          cssShadow(
                            dy: 8,
                            blur: 22,
                            color: Green.c600.withValues(alpha: 0.42),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.search,
                            size: 17,
                            color: Colors.white,
                          ),
                          const SizedBox(width: RtcSpace.s2),
                          Text(
                            'Buscar',
                            style: RtcType.base.copyWith(
                              fontSize: 15,
                              fontWeight: RtcType.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Cerrar — circulo blanco de 44px arriba a la derecha
          Positioned(
            top: MediaQuery.paddingOf(context).top + 20,
            right: 20,
            child: RtcPressable(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Superficie.tarjeta,
                  shape: BoxShape.circle,
                  boxShadow: [
                    cssShadow(
                      dy: 4,
                      blur: 16,
                      color: Colors.black.withValues(alpha: 0.22),
                    ),
                  ],
                ),
                child: Icon(LucideIcons.x, size: 19, color: Gray.c800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Tarjeta abierta (con su titulo grande) o fila colapsada con el valor.
  Widget _panelOrRow({
    required String key,
    required String label,
    required String title,
    required String value,
    required bool filled,
    required Widget body,
    EdgeInsets bodyPadding = const EdgeInsets.all(RtcSpace.s4),
  }) {
    if (_panel != key) {
      // px-5 py-4, rounded-2xl, shadow '0 2px 16px rgba(20,14,30,.10)'
      return RtcPressable(
        onTap: () => _toggle(key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Superficie.tarjeta,
            borderRadius: RtcRadius.brXxl,
            boxShadow: [
              cssShadow(
                dy: 2,
                blur: 16,
                color: const Color(0xFF140E1E).withValues(alpha: 0.10),
              ),
            ],
          ),
          child: Row(
            children: [
              Text(
                label,
                style: RtcType.base.copyWith(fontSize: 15, color: Gray.c500),
              ),
              const SizedBox(width: RtcSpace.s4),
              Expanded(
                child: Text(
                  _capitalize(value),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: RtcType.base.copyWith(
                    fontSize: 15,
                    fontWeight: RtcType.bold,
                    color: filled ? Gray.c900 : Gray.c400,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // rounded-3xl p-4, shadow '0 10px 36px rgba(20,14,30,.16)'
    return Container(
      decoration: BoxDecoration(
        color: Superficie.tarjeta,
        borderRadius: BorderRadius.circular(24), // rounded-3xl
        boxShadow: [
          cssShadow(
            dy: 10,
            blur: 36,
            color: const Color(0xFF140E1E).withValues(alpha: 0.16),
          ),
        ],
      ),
      padding: bodyPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: bodyPadding == EdgeInsets.zero
                ? const EdgeInsets.fromLTRB(RtcSpace.s4, RtcSpace.s3, 0, 0)
                : const EdgeInsets.only(left: RtcSpace.s1),
            child: Text(
              title,
              style: RtcType.xl2.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w800, // font-extrabold
                color: Gray.c900,
              ),
            ),
          ),
          if (bodyPadding != EdgeInsets.zero)
            const SizedBox(height: RtcSpace.s3),
          // En la web la lista crece y la pagina entera se desplaza; en un
          // telefono eso deja la tarjeta mas alta que la pantalla y las
          // ultimas ciudades quedan detras de la barra de Buscar. El panel se
          // limita a la mitad de la pantalla y desplaza por dentro, que es lo
          // que hace cualquier selector de movil. El calendario se queda
          // fuera: ya viene con su alto fijo.
          if (bodyPadding == EdgeInsets.zero)
            body
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.5,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                child: body,
              ),
            ),
        ],
      ),
    );
  }

  /// `deporteList`: "Todos los deportes" + los tres, con delay de 35ms.
  Widget _sportList() {
    final options = <(String, String)>[
      ('', 'Todos los deportes'),
      for (final s in sports) (s.key, s.label),
    ];
    return Column(
      children: [
        for (var i = 0; i < options.length; i++)
          RtcItemIn(
            delay: Duration(milliseconds: i * 35),
            child: _OptionRow(
              active: _sport == options[i].$1,
              background: _sportMeta[options[i].$1]?.bg ?? Green.c50,
              tile: SportIcon(
                sport: options[i].$1.isEmpty ? null : options[i].$1,
                size: 21,
                color: _sportMeta[options[i].$1]?.color ?? Green.c600,
              ),
              title: options[i].$2,
              subtitle:
                  _sportMeta[options[i].$1]?.tag ?? 'Explora todas las canchas',
              onTap: () => setState(() {
                _sport = options[i].$1;
                _panel = _city.isNotEmpty ? null : 'ciudad';
              }),
            ),
          ),
      ],
    );
  }

  /// `ciudadList`: "Todas las ciudades" + las ocho, con delay de 30ms.
  Widget _cityList() {
    final options = ['', ..._cities];
    return Column(
      children: [
        for (var i = 0; i < options.length; i++)
          RtcItemIn(
            delay: Duration(milliseconds: i * 30),
            child: Builder(
              builder: (context) {
                final c = options[i];
                final meta = c.isEmpty ? null : _cityMeta[cityKey(c)];
                final color = meta?.color ?? Green.c600;
                return _OptionRow(
                  active: _city == c,
                  background: meta?.bg ?? const Color(0xFFFFF8E1),
                  tile: CityGlyph(
                    city: c.isEmpty ? 'colombia' : c,
                    color: color,
                    size: 26,
                  ),
                  title: c.isEmpty ? 'Todas las ciudades' : c,
                  subtitle: meta?.dept ?? 'En toda Colombia',
                  onTap: () => setState(() {
                    _city = c;
                    _panel = 'fecha';
                  }),
                );
              },
            ),
          ),
      ],
    );
  }

  /// `horaInner`: "Cualquier hora" + las tres franjas del dia en 12h.
  Widget _timeList() {
    final groups = <(String, IconData, List<String>)>[
      ('Mañana', LucideIcons.sunrise, _hours.sublist(0, 6)),
      ('Tarde', LucideIcons.sun, _hours.sublist(6, 12)),
      ('Noche', LucideIcons.moon, _hours.sublist(12)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RtcItemIn(
          child: RtcPressable(
            onTap: () => setState(() {
              _time = '';
              _panel = null;
            }),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: RtcSpace.s3,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: _time.isEmpty ? Green.c50 : Colors.transparent,
                borderRadius: RtcRadius.brXl,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Green.c50,
                      borderRadius: RtcRadius.brMd,
                    ),
                    child: const Icon(
                      LucideIcons.clock,
                      size: 16,
                      color: Green.c600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Cualquier hora',
                    style: RtcType.sm.copyWith(
                      fontWeight: RtcType.semibold,
                      color: Gray.c800,
                    ),
                  ),
                  const Spacer(),
                  if (_time.isEmpty)
                    const RtcCheckIn(
                      child: Icon(
                        LucideIcons.check,
                        size: 16,
                        color: Green.c600,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // h-px bg-gray-100 my-2
        Padding(
          padding: EdgeInsets.symmetric(vertical: RtcSpace.s2),
          child: Divider(height: 1, thickness: 1, color: Gray.c100),
        ),

        for (var gi = 0; gi < groups.length; gi++) ...[
          if (gi > 0) const SizedBox(height: RtcSpace.s3),
          RtcItemIn(
            delay: Duration(milliseconds: gi * 45),
            child: Padding(
              padding: const EdgeInsets.only(left: RtcSpace.s1, bottom: 6),
              child: Row(
                children: [
                  Icon(groups[gi].$2, size: 14, color: Gray.c500),
                  const SizedBox(width: 6),
                  Text(
                    groups[gi].$1.toUpperCase(),
                    style: RtcType.xs.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w800, // font-extrabold
                      letterSpacing: 0.88, // tracking-[.08em] sobre 11px
                      color: Gray.c500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // grid-cols-3 gap-1.5
          LayoutBuilder(
            builder: (context, c) {
              const gap = 6.0;
              final w = (c.maxWidth - gap * 2) / 3;
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (var i = 0; i < groups[gi].$3.length; i++)
                    RtcItemIn(
                      delay: Duration(milliseconds: gi * 45 + i * 18),
                      child: _HourChip(
                        width: w,
                        label: _to12h(groups[gi].$3[i]),
                        active: _time == groups[gi].$3[i],
                        onTap: () => setState(() {
                          _time = groups[gi].$3[i];
                          _panel = null;
                        }),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

/// Fila de opcion con tile de color, titulo, subtitulo y check.
class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.active,
    required this.background,
    required this.tile,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool active;
  final Color background;
  final Widget tile;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RtcPressable(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: RtcSpace.s3,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          color: active ? Green.c50 : Colors.transparent,
          borderRadius: RtcRadius.brXl,
        ),
        child: Row(
          children: [
            // w-10 h-10 rounded-xl
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: background,
                borderRadius: RtcRadius.brXl,
              ),
              child: tile,
            ),
            const SizedBox(width: RtcSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RtcType.sm.copyWith(
                      fontWeight: RtcType.semibold,
                      color: Gray.c800,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: RtcType.xs.copyWith(color: Gray.c500),
                  ),
                ],
              ),
            ),
            if (active)
              const RtcCheckIn(
                child: Icon(LucideIcons.check, size: 16, color: Green.c600),
              ),
          ],
        ),
      ),
    );
  }
}

class _HourChip extends StatelessWidget {
  const _HourChip({
    required this.width,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final double width;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // .rtc-pick — el chip late al elegirse
    return RtcPick(
      trigger: active,
      child: RtcPressable(
        onTap: onTap,
        child: Container(
          width: width,
          padding: const EdgeInsets.symmetric(vertical: RtcSpace.s2),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Green.c600 : Colors.transparent,
            border: Border.all(color: active ? Green.c600 : Gray.c200),
            borderRadius: RtcRadius.brLg,
          ),
          child: Text(
            label,
            style: RtcType.sm.copyWith(
              fontSize: 13,
              fontWeight: RtcType.semibold,
              color: active ? Colors.white : Gray.c700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Port de `MiniCalendar`. Semana de lunes a domingo, dias pasados apagados,
/// hoy con borde verde y el elegido en circulo verde con `.rtc-pick`.
class _MiniCalendar extends StatefulWidget {
  const _MiniCalendar({
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  final DateTime? value;
  final ValueChanged<DateTime> onPick;
  final VoidCallback onClear;

  @override
  State<_MiniCalendar> createState() => _MiniCalendarState();
}

class _MiniCalendarState extends State<_MiniCalendar> {
  late int _y;
  late int _m; // 0-11, como el Date de JS

  @override
  void initState() {
    super.initState();
    final base = widget.value ?? DateTime.now();
    _y = base.year;
    _m = base.month - 1;
  }

  void _prev() => setState(() {
    if (_m == 0) {
      _y--;
      _m = 11;
    } else {
      _m--;
    }
  });

  void _next() => setState(() {
    if (_m == 11) {
      _y++;
      _m = 0;
    } else {
      _m++;
    }
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final first = DateTime(_y, _m + 1, 1);
    // La semana arranca en lunes: (getDay() + 6) % 7 en la web.
    final startDow = first.weekday - 1;
    final daysInMonth = DateTime(_y, _m + 2, 0).day;

    return Padding(
      padding: const EdgeInsets.all(RtcSpace.s4),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _NavButton(icon: LucideIcons.chevronLeft, onTap: _prev),
              Text(
                _capitalize('${_monthsFull[_m]} $_y'),
                style: RtcType.sm.copyWith(
                  fontWeight: RtcType.bold,
                  color: Gray.c800,
                ),
              ),
              _NavButton(icon: LucideIcons.chevronRight, onTap: _next),
            ],
          ),
          const SizedBox(height: RtcSpace.s3),
          Row(
            children: [
              for (final d in _dow)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: RtcSpace.s1),
                    child: Text(
                      d,
                      textAlign: TextAlign.center,
                      style: RtcType.xs.copyWith(
                        fontSize: 11,
                        fontWeight: RtcType.bold,
                        color: Gray.c500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: RtcSpace.s1),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
            children: [
              for (var i = 0; i < startDow; i++) const SizedBox.shrink(),
              for (var d = 1; d <= daysInMonth; d++)
                _DayCell(
                  day: d,
                  date: DateTime(_y, _m + 1, d),
                  today: today,
                  selected: widget.value,
                  onPick: widget.onPick,
                ),
            ],
          ),
          if (widget.value != null)
            Padding(
              padding: const EdgeInsets.only(top: RtcSpace.s2),
              child: RtcPressable(
                onTap: widget.onClear,
                child: Text(
                  'Limpiar fecha',
                  style: RtcType.xs.copyWith(
                    fontWeight: RtcType.semibold,
                    color: Gray.c500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.date,
    required this.today,
    required this.selected,
    required this.onPick,
  });

  final int day;
  final DateTime date;
  final DateTime today;
  final DateTime? selected;
  final ValueChanged<DateTime> onPick;

  @override
  Widget build(BuildContext context) {
    final past = date.isBefore(today);
    final isSelected = selected != null && _sameDay(date, selected!);
    final isToday = _sameDay(date, today);

    Color background = Colors.transparent;
    Color foreground = Gray.c700;
    BoxBorder? border;

    if (past) {
      foreground = Gray.c300;
    } else if (isSelected) {
      background = Green.c600;
      foreground = Colors.white;
    } else if (isToday) {
      border = Border.all(color: Green.c500, width: 2);
      foreground = Green.c700;
    }

    return RtcPick(
      trigger: isSelected,
      child: RtcPressable(
        onTap: past ? null : () => onPick(date),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            border: border,
            shape: BoxShape.circle,
          ),
          child: Text(
            '$day',
            style: RtcType.sm.copyWith(
              fontSize: 13,
              fontWeight: RtcType.semibold,
              color: foreground,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RtcPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(borderRadius: RtcRadius.brLg),
        child: Icon(icon, size: 16, color: Gray.c500),
      ),
    );
  }
}
