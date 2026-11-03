import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../models/geo.dart';
import '../../models/geocode.dart';
import '../../theme/palette.dart';
import '../../theme/shadows.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../tile_attribution.dart';
import '../motion/rtc_pressable.dart';

/// Direccion que el selector le devuelve al formulario.
typedef DireccionResuelta = ({String address, String city, String department});

/// Port de `Frontend/src/components/map/LocationPicker.tsx`.
///
/// Buscador de direcciones con Nominatim, mapa con el pin arrastrable, y el
/// candado tactil: en pantalla tactil el mapa arranca bloqueado, porque si no
/// arrastrar el dedo para bajar por el formulario movería el mapa en vez de
/// desplazar la pagina.
class LocationPicker extends StatefulWidget {
  const LocationPicker({
    super.key,
    required this.value,
    required this.onChange,
    this.onResolve,
    this.city,
  });

  final LatLng? value;
  final ValueChanged<LatLng> onChange;

  /// Direccion resuelta al elegir una sugerencia o soltar el pin.
  final ValueChanged<DireccionResuelta>? onResolve;

  /// Ciudad ya escrita en el formulario: centra el mapa antes del primer pin.
  final String? city;

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

/// `DEBOUNCE_MS`. Nominatim pide como maximo una peticion por segundo.
const _debounce = Duration(milliseconds: 450);

class _LocationPickerState extends State<LocationPicker> {
  final _mapa = MapController();
  final _buscador = TextEditingController();
  final _claveMapa = GlobalKey();

  List<GeoResult> _resultados = const [];
  bool _buscando = false;
  bool _abierta = false;
  bool _ubicando = false;
  bool _resolviendo = false;

  /// El mapa arranca bloqueado en tactil.
  bool _bloqueado = true;

  Timer? _debounceTimer;

  /// El pin movido por el usuario ya esta donde toca: recentrar lo haria
  /// saltar (`skipCenterRef` de la web).
  bool _saltarCentrado = false;

  /// Mientras se arrastra, el pin sigue al dedo sin avisar al formulario.
  LatLng? _arrastre;

  /// El `useEffect` de la web que sincroniza el pin con el valor del
  /// formulario: si el punto cambio desde AFUERA (una sugerencia elegida, o el
  /// formulario rellenandose al cargar la cancha) el mapa se centra ahi. Si lo
  /// movio el usuario arrastrando, no: recentrar lo haria saltar.
  @override
  void didUpdateWidget(LocationPicker old) {
    super.didUpdateWidget(old);
    final v = widget.value;
    if (v == null || v == old.value) return;
    if (_saltarCentrado) {
      _saltarCentrado = false;
      return;
    }
    // `map.setView(..., Math.max(map.getZoom(), 16))`
    final actual = _mapa.camera.zoom;
    _mapa.move(v, actual < 16 ? 16 : actual);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _buscador.dispose();
    _mapa.dispose();
    super.dispose();
  }

  /// El `commit` de la web: punto elegido por toque, arrastre, sugerencia o GPS.
  Future<void> _fijar(
    double lat,
    double lng, {
    DireccionResuelta? resuelta,
  }) async {
    _saltarCentrado = true;
    widget.onChange(LatLng(lat, lng));

    if (resuelta != null) {
      widget.onResolve?.call(resuelta);
      return;
    }

    setState(() => _resolviendo = true);
    final r = await geocodificarInverso(lat, lng);
    if (!mounted) return;
    if (r != null) {
      widget.onResolve?.call((
        address: r.address,
        city: r.city,
        department: r.department,
      ));
    }
    setState(() => _resolviendo = false);
  }

  void _buscar(String texto) {
    _debounceTimer?.cancel();
    final q = texto.trim();
    if (q.length < 3) {
      setState(() {
        _resultados = const [];
        _buscando = false;
        _abierta = false;
      });
      return;
    }
    setState(() => _buscando = true);
    _debounceTimer = Timer(_debounce, () async {
      final r = await buscarLugares(q);
      if (!mounted) return;
      setState(() {
        _resultados = r;
        _abierta = true;
        _buscando = false;
      });
    });
  }

  void _elegirResultado(GeoResult r) {
    _buscador.clear();
    setState(() {
      _resultados = const [];
      _abierta = false;
    });
    _fijar(
      r.lat,
      r.lng,
      resuelta: (address: r.address, city: r.city, department: r.department),
    );
  }

  /// `useMyLocation`. En la web es `navigator.geolocation`; aca hay que pedir
  /// el permiso primero, que en el navegador lo hace el propio navegador.
  Future<void> _miUbicacion() async {
    setState(() => _ubicando = true);
    try {
      var permiso = await Geolocator.checkPermission();
      if (permiso == LocationPermission.denied) {
        permiso = await Geolocator.requestPermission();
      }
      if (permiso == LocationPermission.denied ||
          permiso == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return;
      _mapa.move(LatLng(pos.latitude, pos.longitude), 16);
      await _fijar(pos.latitude, pos.longitude);
    } catch (_) {
      // La web tambien se lo come en silencio.
    } finally {
      if (mounted) setState(() => _ubicando = false);
    }
  }

  /// Convierte la posicion del dedo a coordenadas del mapa.
  LatLng? _puntoDesdeDedo(Offset global) {
    final caja = _claveMapa.currentContext?.findRenderObject() as RenderBox?;
    if (caja == null) return null;
    final local = caja.globalToLocal(global);
    return _mapa.camera.offsetToCrs(local);
  }

  @override
  Widget build(BuildContext context) {
    final valor = _arrastre ?? widget.value;

    // El encuadre inicial: el punto, el centro de la ciudad, o Colombia.
    final centro = widget.value ?? cityCenter(widget.city) ?? colombiaCenter;
    final zoom = widget.value != null
        ? 16.0
        : cityCenter(widget.city) != null
        ? 12.0
        : 5.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buscadorUi(),
        const SizedBox(height: RtcSpace.s2),
        _mapaUi(centro, zoom, valor),
        const SizedBox(height: RtcSpace.s2),
        _pie(valor),
      ],
    );
  }

  // ── BUSCADOR ─────────────────────────────────────────────────────────
  Widget _buscadorUi() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _buscador,
          onChanged: _buscar,
          style: RtcType.sm.copyWith(color: Gray.c900),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Busca la dirección en el mapa…',
            hintStyle: RtcType.sm.copyWith(color: Gray.c500),
            filled: true,
            fillColor: Superficie.tarjeta,
            contentPadding: const EdgeInsets.symmetric(vertical: RtcSpace.s3),
            prefixIcon: Icon(LucideIcons.search, size: 16, color: Gray.c500),
            prefixIconConstraints: const BoxConstraints(minWidth: 40),
            suffixIconConstraints: const BoxConstraints(minWidth: 0),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: RtcSpace.s2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_buscando)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Gray.c500,
                      ),
                    ),
                  if (_buscador.text.isNotEmpty && !_buscando)
                    RtcPressable(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        _buscador.clear();
                        setState(() {
                          _resultados = const [];
                          _abierta = false;
                        });
                      },
                      child: Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(LucideIcons.x, size: 14, color: Gray.c500),
                      ),
                    ),
                  RtcPressable(
                    behavior: HitTestBehavior.opaque,
                    onTap: _ubicando ? null : _miUbicacion,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: _ubicando
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Gray.c500,
                              ),
                            )
                          : Icon(
                              LucideIcons.crosshair,
                              size: 16,
                              color: Gray.c500,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            border: OutlineInputBorder(
              borderRadius: RtcRadius.brXl,
              borderSide: BorderSide(color: Gray.c200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: RtcRadius.brXl,
              borderSide: BorderSide(color: Gray.c200),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: RtcRadius.brXl,
              borderSide: BorderSide(color: Green.c400, width: 2),
            ),
          ),
        ),
        // La web la muestra flotando sobre el mapa; en el telefono, dentro de
        // un formulario que ya scrollea, va en el flujo: flotar la dejaria
        // tapando el mapa y sin lugar para verla entera.
        if (_abierta && _resultados.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 256), // max-h-64
              decoration: BoxDecoration(
                color: Superficie.tarjeta,
                borderRadius: RtcRadius.brXxl,
                border: Border.all(color: Gray.c200),
                boxShadow: RtcShadows.sheetCard,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _resultados.length,
                itemBuilder: (context, i) {
                  final r = _resultados[i];
                  return RtcPressable(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _elegirResultado(r),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14, // px-3.5
                        vertical: 10, // py-2.5
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              LucideIcons.mapPin,
                              size: 16,
                              color: Green.c600,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              r.label,
                              style: RtcType.sm.copyWith(
                                fontSize: 13,
                                color: Gray.c700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  // ── MAPA ─────────────────────────────────────────────────────────────
  Widget _mapaUi(LatLng centro, double zoom, LatLng? valor) {
    return ClipRRect(
      borderRadius: RtcRadius.brXxl,
      child: Container(
        height: 256, // h-64
        decoration: BoxDecoration(
          color: Gray.c100,
          border: Border.all(color: Gray.c200),
          borderRadius: RtcRadius.brXxl,
        ),
        child: Stack(
          key: _claveMapa,
          children: [
            FlutterMap(
              mapController: _mapa,
              options: MapOptions(
                initialCenter: centro,
                initialZoom: zoom,
                maxZoom: tileMaxZoom,
                // Con el candado puesto el dedo desplaza la pagina.
                interactionOptions: InteractionOptions(
                  flags: _bloqueado
                      ? InteractiveFlag.none
                      : InteractiveFlag.all & ~InteractiveFlag.rotate,
                ),
                onTap: (_, punto) {
                  if (_bloqueado) return;
                  _fijar(punto.latitude, punto.longitude);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate: tileUrl,
                  userAgentPackageName: 'site.reservatucancha',
                  maxZoom: tileMaxZoom,
                ),
                if (valor != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: valor,
                        width: 34,
                        height: 46,
                        alignment: Alignment.topCenter,
                        child: GestureDetector(
                          // `draggable: true` del marcador de Leaflet.
                          onPanUpdate: (d) {
                            if (_bloqueado) return;
                            final p = _puntoDesdeDedo(d.globalPosition);
                            if (p != null) setState(() => _arrastre = p);
                          },
                          onPanEnd: (_) {
                            final p = _arrastre;
                            if (p == null) return;
                            setState(() => _arrastre = null);
                            _fijar(p.latitude, p.longitude);
                          },
                          child: SvgPicture.string(
                            _pinSvg,
                            width: 34,
                            height: 46,
                          ),
                        ),
                      ),
                    ],
                  ),
                const TileAttribution(),
              ],
            ),

            // "Toca el mapa para marcar la cancha"
            if (!_bloqueado && widget.value == null)
              Positioned(
                top: RtcSpace.s3,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: RtcSpace.s3,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: GrisFijo.c900.withValues(alpha: 0.85),
                      borderRadius: RtcRadius.brFull,
                    ),
                    child: Text(
                      'Toca el mapa para marcar la cancha',
                      style: RtcType.xs.copyWith(
                        color: Colors.white,
                        fontWeight: RtcType.semibold,
                      ),
                    ),
                  ),
                ),
              ),

            // El candado tactil.
            if (_bloqueado)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => setState(() => _bloqueado = false),
                  child: ColoredBox(
                    color: GrisFijo.c900.withValues(alpha: 0.25),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: RtcSpace.s4,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: RtcRadius.brFull,
                          boxShadow: RtcShadows.sheetCard,
                        ),
                        child: Text(
                          'Toca para activar el mapa',
                          style: RtcType.sm.copyWith(
                            fontSize: 13,
                            fontWeight: RtcType.bold,
                            color: GrisFijo.c900,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── PIE ──────────────────────────────────────────────────────────────
  Widget _pie(LatLng? valor) {
    if (_resolviendo) {
      return Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: GrisFijo.c500,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            'Leyendo la dirección del punto…',
            style: RtcType.xs.copyWith(color: Gray.c500),
          ),
        ],
      );
    }
    if (valor != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.mapPin, size: 12, color: Green.c600),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Punto marcado: ${valor.latitude.toStringAsFixed(5)}, '
              '${valor.longitude.toStringAsFixed(5)} · arrastra el pin para '
              'ajustarlo',
              style: RtcType.xs.copyWith(color: Gray.c500),
            ),
          ),
        ],
      );
    }
    return Text(
      'Opcional, pero sin punto la cancha se ubica solo por ciudad en el mapa '
      'público.',
      style: RtcType.xs.copyWith(color: Gray.c500),
    );
  }
}

/// `PIN_SVG`: la gota verde con el borde blanco.
const _pinSvg =
    '<svg width="34" height="46" viewBox="0 0 34 46" fill="none" '
    'xmlns="http://www.w3.org/2000/svg">'
    '<path d="M17 45s15-16.2 15-27.2C32 8.9 25.3 2 17 2S2 8.9 2 17.8C2 28.8 '
    '17 45 17 45z" fill="#16a34a" stroke="#fff" stroke-width="3"/>'
    '<circle cx="17" cy="17.5" r="5.5" fill="#fff"/></svg>';
