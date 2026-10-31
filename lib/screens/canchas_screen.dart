import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/courts_api.dart';
import '../api/rtc_api.dart';
import '../models/court.dart';
import '../models/fechas.dart';
import '../theme/palette.dart';
import '../theme/shadows.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/court_card.dart';
import '../widgets/courts_map.dart';
import '../widgets/mobile_search_sheet.dart';
import '../widgets/mobile_search_trigger.dart';
import '../widgets/mobile_stack_sheet.dart';
import '../widgets/motion/rtc_motion.dart';
import '../widgets/price_slider.dart';

import '../app/nav_state.dart';
import '../app/routes.dart';
import '../widgets/rtc_bottom_nav.dart' show kBottomNavEspacio;
import '../api/bookings_api.dart';

/// Port de `Frontend/src/app/(public)/empresas/page.client.tsx`, rama movil.
///
/// La vista "Dividido" del web es `wideOnly` (solo desde lg), asi que en
/// telefono el conmutador queda con Lista y Mapa, igual que en el sitio.
class CanchasScreen extends StatefulWidget {
  const CanchasScreen({
    super.key,
    this.initialSport,
    this.initialCity,
    this.initialDate,
    this.initialStart,
  });

  /// Los `?sport=&city=&date=&start=` de la URL. `sport` y `city` filtran en
  /// el servidor; `date` y `start` solo se muestran y se le pasan a la ficha
  /// de la cancha para preseleccionar el turno.
  final String? initialSport;
  final String? initialCity;
  final String? initialDate;
  final String? initialStart;

  static const heroImage =
      'https://images.unsplash.com/photo-1459865264687-595d652de67e?w=1600&q=80';

  @override
  State<CanchasScreen> createState() => _CanchasScreenState();
}

/// `PAGE_SIZE`.
const _pageSize = 9;

/// `SORT_LABELS` / `SORT_ORDER`.
const _sortOrder = ['destacados', 'precio-asc', 'precio-desc'];
const _sortLabels = {
  'destacados': 'Destacados',
  'precio-asc': 'Menor precio',
  'precio-desc': 'Mayor precio',
};

/// `PRICE_PICKS`.
const _pricePicks = <(int, int, String)>[
  (PriceSlider.min, PriceSlider.max, 'Cualquier precio'),
  (PriceSlider.min, 60000, 'Hasta \$60.000'),
  (60000, 120000, '\$60K – \$120K'),
  (120000, PriceSlider.max, 'Más de \$120.000'),
];

/// `AMENITIES` de constants.ts.
const _amenities = [
  'Luz nocturna',
  'Parqueadero',
  'Duchas',
  'Vestiarios',
  'Cafetería',
  'Graderías',
  'Wi-Fi',
  'Alquiler de equipos',
];

String _fmtCop(int n) => '\$${formatCop(n)}';

class _CanchasScreenState extends State<CanchasScreen> {
  final _anchorKey = GlobalKey();
  double? _anchorBottom;

  // Refinamientos locales, igual que en la web (no viajan en la URL).
  final _selectedAmenities = <String>{};

  /// Turnos libres hoy (y desde las 6 pm) por cancha, para las etiquetas y
  /// los filtros rapidos.
  Map<String, Disponibilidad> _cupoHoy = const {};
  Map<String, Disponibilidad> _cupoTarde = const {};

  /// Filtros rapidos: chips de un toque arriba de la lista.
  bool _soloHoy = false;
  bool _soloTarde = false;
  bool _baratas = false;

  /// "Menos de $80.000".
  static const _topeBarata = 80000;

  int _minPrice = PriceSlider.min;
  int _maxPrice = PriceSlider.max;
  String _sort = 'destacados';
  int _page = 1;

  /// Lo que trajo `GET /courts`. La web pide limit: 48 y filtra el resto en
  /// el cliente (page.client.tsx:147); aca igual.
  List<Court> _courts = const [];
  int _total = 0;
  bool _loadingCourts = true;
  String? _courtsError;

  @override
  void initState() {
    super.initState();
    _loadCourts();
  }

  Future<void> _cargarCupo() async {
    final ids = _courts.map((c) => c.id).toList();
    final hoy = fechaIso(ahoraEnBogota());
    final r = await Future.wait([
      bookingsApi.disponibilidad(ids, hoy),
      bookingsApi.disponibilidad(ids, hoy, desde: '18:00'),
    ]);
    if (!mounted) return;
    setState(() {
      _cupoHoy = r[0];
      _cupoTarde = r[1];
    });
  }

  Future<void> _loadCourts() async {
    setState(() {
      _loadingCourts = true;
      _courtsError = null;
    });
    try {
      // `useCourts({ sport, city, ..., limit: 48 })`.
      final page = await courtsApi.getAll(
        sport: _deporte.isEmpty ? null : _deporte,
        city: _ciudad.isEmpty ? null : _ciudad,
        limit: 48,
      );
      if (!mounted) return;
      setState(() {
        _courts = page.data;
        _total = page.total;
        _loadingCourts = false;
      });
      _cargarCupo();
    } on RtcApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _courtsError = e.message;
        _loadingCourts = false;
      });
    }
  }

  /// `ResultView`: en movil solo lista y mapa.
  String _view = 'lista';

  bool get _priceActive =>
      _minPrice > PriceSlider.min || _maxPrice < PriceSlider.max;

  int get _activeFilters =>
      _selectedAmenities.length +
      (_priceActive ? 1 : 0) +
      (_sort != 'destacados' ? 1 : 0);

  /// `sorted`: destacados = por rating.
  List<Court> get _sorted {
    final list = [..._courts];
    if (_sort == 'precio-asc') {
      list.sort((a, b) => a.pricePerHour.compareTo(b.pricePerHour));
    } else if (_sort == 'precio-desc') {
      list.sort((a, b) => b.pricePerHour.compareTo(a.pricePerHour));
    } else {
      list.sort((a, b) => b.averageRating.compareTo(a.averageRating));
    }
    return list;
  }

  /// `filtered`: amenidades (todas las elegidas) y rango de precio.
  List<Court> get _filtered {
    var list = _sorted;
    if (_selectedAmenities.isNotEmpty) {
      list = list
          .where((c) => _selectedAmenities.every(c.amenities.contains))
          .toList();
    }
    if (_soloHoy) {
      list = list.where((c) => (_cupoHoy[c.id]?.libres ?? 0) > 0).toList();
    }
    if (_soloTarde) {
      list = list.where((c) => (_cupoTarde[c.id]?.libres ?? 0) > 0).toList();
    }
    if (_baratas) {
      list = list.where((c) => c.pricePerHour < _topeBarata).toList();
    }
    if (_priceActive) {
      // El tope del slider significa "sin tope".
      list = list.where((c) {
        final p = c.pricePerHour;
        return p >= _minPrice &&
            (_maxPrice >= PriceSlider.max || p <= _maxPrice);
      }).toList();
    }
    return list;
  }

  int get _pageCount => (_filtered.length / _pageSize).ceil().clamp(1, 999);
  int get _safePage => _page.clamp(1, _pageCount);

  List<Court> get _visible {
    final all = _filtered;
    final from = (_safePage - 1) * _pageSize;
    return all.sublist(from, (from + _pageSize).clamp(0, all.length));
  }

  // ── BUSQUEDA ─────────────────────────────────────────────────────────
  String get _deporte => widget.initialSport ?? '';
  String get _ciudad => widget.initialCity ?? '';
  String get _fecha => widget.initialDate ?? '';
  String get _hora => widget.initialStart ?? '';

  /// `clearAll` del estado vacio: limpia los refinamientos Y la busqueda,
  /// con el `router.push('/empresas')` que deja la URL pelada.
  void _limpiarTodo() {
    _clearFilters();
    rtcBuscarCanchas();
  }

  void _clearFilters() => setState(() {
    _soloHoy = false;
    _soloTarde = false;
    _baratas = false;
    _selectedAmenities.clear();
    _minPrice = PriceSlider.min;
    _maxPrice = PriceSlider.max;
    _sort = 'destacados';
    _page = 1;
  });

  void _readDock(double pixels) {
    final box = _anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.attached && box.hasSize) {
      final viewport = RenderAbstractViewport.maybeOf(box);
      if (viewport != null) {
        _anchorBottom =
            viewport.getOffsetToReveal(box, 0).offset + box.size.height;
      }
    }
    if (_anchorBottom == null) return;
    // Sin navbar arriba: la lupa aparece junto a la barra inferior cuando el
    // buscador ya se metio debajo de la barra de filtros fija.
    const trigger = _FilterBarDelegate._height;
    RtcNavScope.read(context).docked = _anchorBottom! - pixels <= trigger;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        _readDock(n.metrics.pixels);
        return false;
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _hero()),
          // La barra de filtros es sticky bajo el navbar, igual que en la web.
          SliverPersistentHeader(
            pinned: true,
            delegate: _FilterBarDelegate(child: _filterBar()),
          ),
          SliverToBoxAdapter(child: _content()),
          const SliverToBoxAdapter(child: SizedBox(height: kBottomNavEspacio)),
        ],
      ),
    );
  }

  // ── CABECERA ─────────────────────────────────────────────────────────
  // Titulo, cantidad y el buscador de siempre, sobre el fondo de la app.
  Widget _hero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        RtcSpace.s5,
        RtcSpace.s4,
        RtcSpace.s5,
        RtcSpace.s4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explora canchas',
            style: RtcType.xl2.copyWith(
              fontSize: 28,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: Gray.c900,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _loadingCourts
                ? 'Buscando…'
                : '$_total canchas disponibles en Colombia',
            style: RtcType.sm.copyWith(color: Gray.c500),
          ),
          const SizedBox(height: RtcSpace.s5),
          MobileSearchTrigger(
            key: _anchorKey,
            suave: true,
            onTap: () => showMobileSearchSheet(
              context,
              sport: _deporte,
              city: _ciudad,
              date: _fecha,
              time: _hora,
            ),
          ),
        ],
      ),
    );
  }

  // ── BARRA DE FILTROS ─────────────────────────────────────────────────
  Widget _filterBar() {
    final count = _filtered.length;
    return Container(
      color: Fondo.app,
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s5,
        vertical: RtcSpace.s3,
      ),
      child: Row(
        children: [
          _FilterPill(
            active: _activeFilters > 0,
            icon: LucideIcons.slidersHorizontal,
            label: _activeFilters > 0 ? 'Filtros ($_activeFilters)' : 'Filtros',
            onTap: _openFilters,
          ),
          const SizedBox(width: RtcSpace.s3),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$count ',
                    style: RtcType.sm.copyWith(
                      fontSize: 13,
                      fontWeight: RtcType.semibold,
                      color: Gray.c900,
                    ),
                  ),
                  TextSpan(text: count == 1 ? 'cancha' : 'canchas'),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RtcType.sm.copyWith(fontSize: 13, color: Gray.c500),
            ),
          ),
          _ViewToggle(view: _view, onChanged: (v) => setState(() => _view = v)),
        ],
      ),
    );
  }

  // ── SHEET DE FILTROS ─────────────────────────────────────────────────
  void _openFilters() {
    showMobileStackSheet(
      context: context,
      initialSection: 'amenidades',
      sections: (setSheetState) => [
        StackSection(
          key: 'amenidades',
          title: '¿Qué necesitas?',
          label: 'Amenidades',
          value: _selectedAmenities.isEmpty
              ? 'Todas'
              : '${_selectedAmenities.length} elegida'
                    '${_selectedAmenities.length > 1 ? 's' : ''}',
          filled: _selectedAmenities.isNotEmpty,
          content: _amenityTiles(setSheetState),
        ),
        StackSection(
          key: 'precio',
          title: '¿Cuánto quieres pagar?',
          label: 'Precio por hora',
          value: _priceActive
              ? '${_fmtCop(_minPrice)} – '
                    '${_maxPrice >= PriceSlider.max ? 'sin tope' : _fmtCop(_maxPrice)}'
              : 'Cualquiera',
          filled: _priceActive,
          content: _priceInner(setSheetState),
        ),
        StackSection(
          key: 'sort',
          title: '¿Cómo las ordenamos?',
          label: 'Ordenar por',
          value: _sortLabels[_sort]!,
          filled: _sort != 'destacados',
          content: _sortRows(setSheetState),
        ),
      ],
      footer: (setSheetState) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SheetClearButton(
            onTap: () {
              _clearFilters();
              setSheetState(() {});
            },
          ),
          SheetPrimaryButton(
            label:
                'Ver ${_filtered.length} '
                '${_filtered.length == 1 ? 'cancha' : 'canchas'}',
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ).then((_) => setState(() {}));
  }

  /// `amenTiles('grid-cols-3')` — tiles con entrada escalonada de 25ms.
  Widget _amenityTiles(void Function(VoidCallback) setSheetState) {
    return LayoutBuilder(
      builder: (context, c) {
        const gap = RtcSpace.s2;
        final w = (c.maxWidth - gap * 2) / 3;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < _amenities.length; i++)
              RtcItemIn(
                delay: Duration(milliseconds: i * 25),
                child: _AmenityTile(
                  width: w,
                  label: _amenities[i],
                  active: _selectedAmenities.contains(_amenities[i]),
                  onTap: () {
                    final a = _amenities[i];
                    _selectedAmenities.contains(a)
                        ? _selectedAmenities.remove(a)
                        : _selectedAmenities.add(a);
                    _page = 1;
                    setSheetState(() {});
                    setState(() {});
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  /// `precioInner` — mínimo/máximo, slider y los cuatro atajos.
  Widget _priceInner(void Function(VoidCallback) setSheetState) {
    void apply(int lo, int hi) {
      _minPrice = lo;
      _maxPrice = hi;
      setSheetState(() {});
      setState(() {});
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _PriceReadout(label: 'Mínimo', value: _fmtCop(_minPrice)),
            _PriceReadout(
              label: 'Máximo',
              value: _maxPrice >= PriceSlider.max
                  ? 'Sin tope'
                  : _fmtCop(_maxPrice),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: RtcSpace.s3),
          child: PriceSlider(lo: _minPrice, hi: _maxPrice, onChanged: apply),
        ),
        LayoutBuilder(
          builder: (context, c) {
            const gap = RtcSpace.s2;
            final w = (c.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final (mn, mx, lbl) in _pricePicks)
                  _PricePick(
                    width: w,
                    label: lbl,
                    active: mn == _minPrice && mx == _maxPrice,
                    onTap: () => apply(mn, mx),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  /// `sortRows` — con el check que entra con `.check-in`.
  Widget _sortRows(void Function(VoidCallback) setSheetState) {
    return Column(
      children: [
        for (var i = 0; i < _sortOrder.length; i++)
          RtcItemIn(
            delay: Duration(milliseconds: i * 30),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                _sort = _sortOrder[i];
                _page = 1;
                setSheetState(() {});
                setState(() {});
              },
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 2),
                padding: const EdgeInsets.symmetric(
                  horizontal: RtcSpace.s3,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _sort == _sortOrder[i]
                      ? Green.c50
                      : Colors.transparent,
                  borderRadius: RtcRadius.brXl,
                ),
                child: Row(
                  children: [
                    Text(
                      _sortLabels[_sortOrder[i]]!,
                      style: RtcType.sm.copyWith(
                        fontSize: 13.5,
                        fontWeight: RtcType.semibold,
                        color: _sort == _sortOrder[i] ? Green.c700 : Gray.c700,
                      ),
                    ),
                    const Spacer(),
                    if (_sort == _sortOrder[i])
                      const RtcCheckIn(
                        child: Icon(
                          LucideIcons.check,
                          size: 14,
                          color: Green.c600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ── CONTENIDO ────────────────────────────────────────────────────────
  Widget _content() {
    final aviso = _avisoBusqueda();
    if (aviso == null && _ciudad.isEmpty) return _resultados();

    // El `pt-2` de la seccion ya lo pone `_resultados`; se descuenta de los
    // `mb-*` para que la separacion sume lo mismo que en la web.
    const pt = RtcSpace.s2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            RtcSpace.s4,
            RtcSpace.s2,
            RtcSpace.s4,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (aviso != null) ...[
                aviso,
                SizedBox(
                  height: _ciudad.isEmpty ? RtcSpace.s3 - pt : RtcSpace.s3,
                ),
              ],
              // `md:hidden`: en movil si se ve.
              if (_ciudad.isNotEmpty) ...[
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Canchas en '),
                      TextSpan(
                        text: _ciudad,
                        style: RtcType.sm.copyWith(
                          fontWeight: RtcType.semibold,
                          color: Gray.c900,
                        ),
                      ),
                    ],
                  ),
                  style: RtcType.sm.copyWith(color: Gray.c500),
                ),
                const SizedBox(height: RtcSpace.s5 - pt),
              ],
            ],
          ),
        ),
        _resultados(),
      ],
    );
  }

  /// El banner de fecha/hora elegida: sale con `niceDate || startParam`.
  Widget? _avisoBusqueda() {
    final valida = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(_fecha);
    final dia = valida ? DateTime.tryParse(_fecha) : null;
    // `capitalize` sobre "EEEE d 'de' MMMM".
    final niceDate = dia == null ? '' : fechaLargaCapitalizada(dia);
    if (niceDate.isEmpty && _hora.isEmpty) return null;

    const verde200 = Color(0xFFBBF7D0);
    const verde800 = Color(0xFF166534);
    final fuerte = RtcType.sm.copyWith(
      fontWeight: RtcType.bold,
      color: verde800,
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s4,
        vertical: 10, // py-2.5
      ),
      decoration: BoxDecoration(
        color: Green.c50,
        borderRadius: RtcRadius.brXxl,
        border: Border.all(color: verde200),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.calendarDays, size: 20, color: Green.c600),
          const SizedBox(width: RtcSpace.s3),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  if (niceDate.isNotEmpty || _fecha.isNotEmpty) ...[
                    const TextSpan(text: 'Buscando para '),
                    TextSpan(
                      text: niceDate.isNotEmpty ? niceDate : _fecha,
                      style: fuerte,
                    ),
                  ] else
                    const TextSpan(text: 'Buscando canchas'),
                  if (_hora.isNotEmpty) ...[
                    const TextSpan(text: ' a las '),
                    TextSpan(text: hora12(_hora), style: fuerte),
                  ],
                  const TextSpan(
                    text: '. El horario se preselecciona al abrir la reserva.',
                  ),
                ],
              ),
              style: RtcType.sm.copyWith(color: verde800),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultados() {
    // `isError`: la web esconde lista y mapa y deja solo el mensaje.
    if (_courtsError != null) return _errorState();

    if (_view == 'mapa') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(
          RtcSpace.s4,
          RtcSpace.s2,
          RtcSpace.s4,
          RtcSpace.s10,
        ),
        // `MAP_HEIGHT`: h-[68vh] min-h-[420px]
        child: SizedBox(
          height: (MediaQuery.sizeOf(context).height * 0.68).clamp(420, 900),
          child: CourtsMap(
            courts: _filtered,
            // `carryQuery`: el mapa tambien lleva la fecha y la hora.
            onOpenCourt: (c) => rtcOpenCourt(c.id, date: _fecha, start: _hora),
          ),
        ),
      );
    }

    if (_loadingCourts) return _skeletonGrid();

    final list = _filtered;
    final rapidos = _FiltrosRapidos(
      hoy: _soloHoy,
      tarde: _soloTarde,
      baratas: _baratas,
      onHoy: () => setState(() {
        _soloHoy = !_soloHoy;
        _page = 1;
      }),
      onTarde: () => setState(() {
        _soloTarde = !_soloTarde;
        _page = 1;
      }),
      onBaratas: () => setState(() {
        _baratas = !_baratas;
        _page = 1;
      }),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        RtcSpace.s4,
        RtcSpace.s2,
        RtcSpace.s4,
        RtcSpace.s10,
      ),
      child: list.isEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                rapidos,
                const SizedBox(height: RtcSpace.s4),
                _emptyState(),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                rapidos,
                const SizedBox(height: RtcSpace.s4),
                for (var i = 0; i < _visible.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: RtcSpace.s8),
                    // `.rtc-fade` con delay de 45ms, tope en el noveno.
                    child: RtcFadeUp(
                      delay: Duration(milliseconds: (i < 8 ? i : 8) * 45),
                      child: CourtCard(
                        court: _visible[i],
                        cupo: _cupoHoy[_visible[i].id],
                        conTransicion: true,
                        onTap: () => rtcOpenCourt(
                          _visible[i].id,
                          date: _fecha,
                          start: _hora,
                          foto: _visible[i].photos.isNotEmpty
                              ? _visible[i].photos.first
                              : getSport(_visible[i].sport).image,
                        ),
                      ),
                    ),
                  ),
                if (_pageCount > 1) _pagination(),
              ],
            ),
    );
  }

  /// `skeletonGrid`: 6 tarjetas fantasma con `animate-pulse`.
  Widget _skeletonGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        RtcSpace.s4,
        RtcSpace.s2,
        RtcSpace.s4,
        RtcSpace.s10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < 6; i++)
            Padding(
              // gap-y-8
              padding: const EdgeInsets.only(bottom: RtcSpace.s8),
              child: RtcSkeletonPulse(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // aspect-[4/3] bg-gray-200 rounded-2xl
                    AspectRatio(
                      aspectRatio: 4 / 3,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Gray.c200,
                          borderRadius: RtcRadius.brXxl,
                        ),
                      ),
                    ),
                    const SizedBox(height: RtcSpace.s3), // pt-3
                    FractionallySizedBox(
                      widthFactor: 3 / 4,
                      child: Container(
                        height: 16, // h-4
                        decoration: BoxDecoration(
                          color: Gray.c200,
                          borderRadius: RtcRadius.brMd,
                        ),
                      ),
                    ),
                    const SizedBox(height: RtcSpace.s2), // space-y-2
                    FractionallySizedBox(
                      widthFactor: 1 / 2,
                      child: Container(
                        height: 12, // h-3
                        decoration: BoxDecoration(
                          color: Gray.c100,
                          borderRadius: RtcRadius.brMd,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// `isError`. La web dice "Intenta de nuevo" contando con que recargues la
  /// pagina; en el telefono no hay F5, asi que el bloque reintenta al tocarlo.
  Widget _errorState() {
    return GestureDetector(
      onTap: _loadCourts,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 80), // py-20
        alignment: Alignment.center,
        child: Text(
          "Error cargando canchas. Intenta de nuevo.",
          textAlign: TextAlign.center,
          style: RtcType.base.copyWith(
            color: Gray.c500,
            fontWeight: RtcType.medium,
          ),
        ),
      ),
    );
  }

  /// `emptyState`.
  Widget _emptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: RtcSpace.s12 + 28),
      decoration: BoxDecoration(
        color: Gray.c50,
        borderRadius: RtcRadius.brXxl,
        border: Border.all(color: Gray.c100),
      ),
      child: Column(
        children: [
          const Icon(LucideIcons.search, size: 40, color: Gray.c300),
          const SizedBox(height: RtcSpace.s3),
          Text(
            'Sin canchas para estos filtros',
            style: RtcType.lg.copyWith(
              fontWeight: RtcType.semibold,
              color: Gray.c900,
            ),
          ),
          const SizedBox(height: RtcSpace.s1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s6),
            child: Text(
              'Prueba quitando alguna amenidad o cambiando de deporte o ciudad.',
              textAlign: TextAlign.center,
              style: RtcType.sm.copyWith(color: Gray.c500),
            ),
          ),
          const SizedBox(height: RtcSpace.s4),
          GestureDetector(
            onTap: _limpiarTodo,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.x, size: 16, color: Green.c700),
                const SizedBox(width: RtcSpace.s2),
                Text(
                  'Limpiar filtros',
                  style: RtcType.sm.copyWith(
                    fontWeight: RtcType.medium,
                    color: Green.c700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// `pagination`.
  Widget _pagination() {
    return Padding(
      padding: const EdgeInsets.only(top: RtcSpace.s4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PageArrow(
            label: '← Anterior',
            enabled: _safePage > 1,
            onTap: () => setState(() => _page = _safePage - 1),
          ),
          const SizedBox(width: RtcSpace.s2),
          for (var p = 1; p <= _pageCount; p++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: GestureDetector(
                onTap: () => setState(() => _page = p),
                child: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p == _safePage ? Gray.c900 : null,
                    border: p == _safePage
                        ? null
                        : Border.all(color: Gray.c200),
                    borderRadius: RtcRadius.brXl,
                  ),
                  child: Text(
                    '$p',
                    style: RtcType.sm.copyWith(
                      fontWeight: RtcType.semibold,
                      color: p == _safePage ? Colors.white : Gray.c700,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(width: RtcSpace.s2),
          _PageArrow(
            label: 'Siguiente →',
            enabled: _safePage < _pageCount,
            onTap: () => setState(() => _page = _safePage + 1),
          ),
        ],
      ),
    );
  }
}

/// Mantiene la barra de filtros pegada bajo el navbar (`sticky top-16`).
class _FilterBarDelegate extends SliverPersistentHeaderDelegate {
  _FilterBarDelegate({required this.child});

  final Widget child;
  static const _height = 62.0;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      SizedBox(height: _height, child: child);

  @override
  bool shouldRebuild(_FilterBarDelegate old) => old.child != child;
}

/// `filterBtn` — verde solido cuando tiene algo activo.
class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.active,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool active;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: RtcSpace.s4,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: active ? Green.c600 : Colors.white,
          borderRadius: RtcRadius.brFull,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? Colors.white : Gray.c700),
            const SizedBox(width: 6),
            Text(
              label,
              style: RtcType.sm.copyWith(
                fontSize: 13,
                fontWeight: RtcType.semibold,
                color: active ? Colors.white : Gray.c700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// `viewToggle` — Lista / Mapa. "Dividido" es solo de escritorio.
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.view, required this.onChanged});

  final String view;
  final ValueChanged<String> onChanged;

  static const _views = <(String, String, IconData)>[
    ('lista', 'Lista', LucideIcons.layoutGrid),
    ('mapa', 'Mapa', LucideIcons.map),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: const BoxDecoration(
        color: Fondo.suave,
        borderRadius: RtcRadius.brFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (key, label, icon) in _views)
            GestureDetector(
              onTap: () => onChanged(key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(
                  horizontal: RtcSpace.s3,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: view == key ? Colors.white : Colors.transparent,
                  borderRadius: RtcRadius.brFull,
                  boxShadow: view == key
                      ? [
                          cssShadow(
                            dy: 1,
                            blur: 2,
                            color: Colors.black.withValues(alpha: 0.05),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 14,
                      color: view == key ? Gray.c900 : Gray.c500,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: RtcType.xs.copyWith(
                        fontSize: 12.5,
                        fontWeight: RtcType.bold,
                        color: view == key ? Gray.c900 : Gray.c500,
                      ),
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

class _AmenityTile extends StatelessWidget {
  const _AmenityTile({
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(RtcSpace.s3),
        decoration: BoxDecoration(
          color: active ? Green.c600 : Gray.c50,
          borderRadius: RtcRadius.brXxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.20)
                    : Colors.white,
                borderRadius: RtcRadius.brXl,
              ),
              child: Icon(
                amenityIcon(label),
                size: 20,
                color: active ? Colors.white : Green.c600,
              ),
            ),
            const SizedBox(height: RtcSpace.s2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: RtcType.xs.copyWith(
                fontSize: 11,
                height: 1.25,
                fontWeight: RtcType.semibold,
                color: active ? Colors.white : Gray.c700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceReadout extends StatelessWidget {
  const _PriceReadout({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: RtcType.xs.copyWith(
            fontSize: 11,
            fontWeight: RtcType.medium,
            color: Gray.c500,
          ),
        ),
        const SizedBox(height: RtcSpace.s1),
        Text(
          value,
          style: RtcType.lg.copyWith(
            fontWeight: FontWeight.w800,
            color: Green.c700,
          ),
        ),
      ],
    );
  }
}

class _PricePick extends StatelessWidget {
  const _PricePick({
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.symmetric(
          horizontal: RtcSpace.s3,
          vertical: 10,
        ),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? Green.c600 : Gray.c50,
          borderRadius: RtcRadius.brXl,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: RtcType.sm.copyWith(
            fontSize: 13,
            fontWeight: RtcType.semibold,
            color: active ? Colors.white : Gray.c600,
          ),
        ),
      ),
    );
  }
}

class _PageArrow extends StatelessWidget {
  const _PageArrow({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: RtcSpace.s3,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: Gray.c200),
            borderRadius: RtcRadius.brXl,
          ),
          child: Text(
            label,
            style: RtcType.xs.copyWith(
              fontWeight: RtcType.medium,
              color: Gray.c700,
            ),
          ),
        ),
      ),
    );
  }
}

/// Los chips de un toque arriba de la lista: cupo hoy, cupo de noche y
/// precio. Se combinan entre si y con los filtros de la hoja.
class _FiltrosRapidos extends StatelessWidget {
  const _FiltrosRapidos({
    required this.hoy,
    required this.tarde,
    required this.baratas,
    required this.onHoy,
    required this.onTarde,
    required this.onBaratas,
  });

  final bool hoy;
  final bool tarde;
  final bool baratas;
  final VoidCallback onHoy;
  final VoidCallback onTarde;
  final VoidCallback onBaratas;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterPill(
            active: hoy,
            icon: LucideIcons.calendarCheck,
            label: 'Con cupo hoy',
            onTap: onHoy,
          ),
          const SizedBox(width: RtcSpace.s2),
          _FilterPill(
            active: tarde,
            icon: LucideIcons.moon,
            label: 'Después de las 6 pm',
            onTap: onTarde,
          ),
          const SizedBox(width: RtcSpace.s2),
          _FilterPill(
            active: baratas,
            icon: LucideIcons.tag,
            label: 'Menos de \$80.000',
            onTap: onBaratas,
          ),
        ],
      ),
    );
  }
}
