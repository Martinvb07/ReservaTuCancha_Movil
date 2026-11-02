import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/cloudinary.dart';
import '../../api/owner_api.dart';
import '../../api/rtc_api.dart';
import '../../models/court.dart';
import '../../theme/motion.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/icons/sport_icon.dart';
import '../../widgets/remote_image.dart';
import '../../widgets/rtc_borde_punteado.dart';
import '../../widgets/rtc_toast.dart';
import '../../widgets/motion/rtc_pressable.dart';

/// Port de `Frontend/src/app/dashboard/propetario/fotos/page.tsx`.
///
/// Selector de cancha, zona de subida y la galeria. La primera foto es la
/// principal: se marca con la insignia lima y se cambia reordenando.
class FotosScreen extends StatefulWidget {
  const FotosScreen({super.key});

  @override
  State<FotosScreen> createState() => _FotosScreenState();
}

class _FotosScreenState extends State<FotosScreen> {
  List<Court> _canchas = const [];
  String? _canchaId;
  bool _cargando = true;
  bool _subiendo = false;

  /// La URL que se esta borrando o promoviendo, para apagar sus botones.
  String? _ocupada;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _cargando = true);
    try {
      final canchas = await ownerApi.misCanchas();
      if (!mounted) return;
      setState(() {
        _canchas = canchas;
        // `useEffect`: la primera queda elegida sola.
        if (_canchaId == null || !canchas.any((c) => c.id == _canchaId)) {
          _canchaId = canchas.isEmpty ? null : canchas.first.id;
        }
        _cargando = false;
      });
    } on RtcApiException catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      rtcToast(context, e.message, tipo: RtcToastTipo.error);
    }
  }

  Court? get _cancha {
    for (final c in _canchas) {
      if (c.id == _canchaId) return c;
    }
    return null;
  }

  List<String> get _fotos => _cancha?.photos ?? const [];

  // ── ACCIONES ─────────────────────────────────────────────────────────

  Future<void> _subir() async {
    final id = _canchaId;
    if (id == null || _subiendo) return;
    // `accept="image/*" multiple`, recortado a 10 como `slice(0, 10)`.
    final elegidas = (await ImagePicker().pickMultiImage()).take(10).toList();
    if (elegidas.isEmpty || !mounted) return;

    setState(() => _subiendo = true);
    var subidas = 0;
    for (final foto in elegidas) {
      try {
        final bytes = await foto.readAsBytes();
        final url = await subirACloudinary(bytes, foto.name);
        await ownerApi.agregarFoto(id, url);
        subidas++;
      } catch (_) {
        if (!mounted) return;
        rtcToast(
          context,
          'Error subiendo ${foto.name}',
          tipo: RtcToastTipo.error,
        );
      }
    }
    if (!mounted) return;
    setState(() => _subiendo = false);
    if (subidas > 0) {
      rtcToast(
        context,
        '$subidas foto${subidas > 1 ? 's' : ''} '
        'subida${subidas > 1 ? 's' : ''}',
      );
    }
    await _cargar(silencioso: true);
  }

  Future<void> _eliminar(String url) async {
    final id = _canchaId;
    if (id == null || _ocupada != null) return;
    setState(() => _ocupada = url);
    try {
      await ownerApi.eliminarFoto(id, url);
      if (!mounted) return;
      setState(() => _ocupada = null);
      await _cargar(silencioso: true);
    } on RtcApiException {
      if (!mounted) return;
      setState(() => _ocupada = null);
      rtcToast(context, 'Error eliminando foto', tipo: RtcToastTipo.error);
    }
  }

  Future<void> _hacerPrincipal(String url) async {
    final id = _canchaId;
    if (id == null || _ocupada != null) return;
    setState(() => _ocupada = url);
    try {
      await ownerApi.ponerFotoPrincipal(id, url, _fotos);
      if (!mounted) return;
      setState(() => _ocupada = null);
      rtcToast(context, 'Foto principal actualizada');
      await _cargar(silencioso: true);
    } on RtcApiException {
      if (!mounted) return;
      setState(() => _ocupada = null);
      rtcToast(
        context,
        'Error actualizando foto principal',
        tipo: RtcToastTipo.error,
      );
    }
  }

  // ── VISTA ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const SizedBox(
        height: 256, // h-64
        child: Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3, color: Green.c500),
          ),
        ),
      );
    }

    if (_canchas.isEmpty) return _sinCanchas();

    return RefreshIndicator(
      onRefresh: _cargar,
      color: Green.c600,
      child: ListView(
        padding: const EdgeInsets.only(bottom: RtcSpace.s12),
        children: [
          _encabezado(),
          const SizedBox(height: RtcSpace.s6),
          _selectorCancha(),
          const SizedBox(height: RtcSpace.s6),
          _zonaSubida(),
          const SizedBox(height: RtcSpace.s6),
          _galeria(),
          const SizedBox(height: RtcSpace.s6),
          _tips(),
        ],
      ),
    );
  }

  Widget _sinCanchas() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 80), // py-20
      children: [
        Text(
          'SIN CANCHAS REGISTRADAS',
          textAlign: TextAlign.center,
          style: RtcType.xl2.copyWith(
            fontWeight: FontWeight.w900,
            color: Gray.c300,
          ),
        ),
        const SizedBox(height: RtcSpace.s2),
        Text(
          'Primero crea una cancha desde el panel',
          textAlign: TextAlign.center,
          style: RtcType.sm.copyWith(color: Gray.c500),
        ),
      ],
    );
  }

  Widget _encabezado() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Panel propietario',
          style: RtcType.sm.copyWith(
            color: Green.c700,
            fontWeight: RtcType.semibold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Galería de fotos',
          style: RtcType.xl3.copyWith(
            letterSpacing: -0.4,
            fontWeight: FontWeight.w900,
            color: Gray.c900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Gestiona las fotos de tus canchas — la primera foto es la que ven '
          'los clientes primero',
          style: RtcType.sm.copyWith(color: Gray.c500),
        ),
      ],
    );
  }

  Widget _selectorCancha() {
    return Container(
      padding: const EdgeInsets.all(RtcSpace.s5),
      decoration: BoxDecoration(
        color: Superficie.tarjeta,
        borderRadius: RtcRadius.brXxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SELECCIONA UNA CANCHA',
            style: RtcType.xs.copyWith(
              fontWeight: FontWeight.w900,
              color: Gray.c500,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: RtcSpace.s3),
          Wrap(
            spacing: RtcSpace.s3,
            runSpacing: RtcSpace.s3,
            children: [for (final c in _canchas) _pastillaCancha(c)],
          ),
        ],
      ),
    );
  }

  Widget _pastillaCancha(Court c) {
    final activa = c.id == _canchaId;
    return RtcPressable(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _canchaId = c.id),
      child: AnimatedContainer(
        duration: RtcDur.pick,
        curve: RtcCurves.smooth,
        padding: const EdgeInsets.symmetric(
          horizontal: RtcSpace.s4,
          vertical: 10, // py-2.5
        ),
        decoration: BoxDecoration(
          color: activa ? Green.c50 : Superficie.tarjeta,
          borderRadius: RtcRadius.brXl,
          border: Border.all(color: activa ? Green.c500 : Gray.c200, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SportIcon(
              sport: c.sport,
              size: 16,
              color: activa ? Green.c700 : Gray.c600,
            ),
            const SizedBox(width: RtcSpace.s2),
            Text(
              c.name,
              style: RtcType.sm.copyWith(
                fontWeight: RtcType.bold,
                color: activa ? Green.c700 : Gray.c600,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '(${c.photos.length})',
              style: RtcType.xs.copyWith(color: Gray.c500),
            ),
            if (activa) ...[
              const SizedBox(width: RtcSpace.s2),
              Icon(LucideIcons.circleCheck, size: 16, color: Green.c700),
            ],
          ],
        ),
      ),
    );
  }

  Widget _zonaSubida() {
    return RtcPressable(
      behavior: HitTestBehavior.opaque,
      onTap: _subiendo ? null : _subir,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 48), // py-12
        decoration: ShapeDecoration(
          color: _subiendo ? Gray.c50 : Colors.transparent,
          shape: RtcBordePunteado(color: Gray.c200, radio: RtcRadius.xxl),
        ),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Gray.c100,
                borderRadius: RtcRadius.brXxl,
              ),
              child: _subiendo
                  ? const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Green.c500,
                      ),
                    )
                  : Icon(LucideIcons.upload, size: 28, color: Gray.c500),
            ),
            const SizedBox(height: RtcSpace.s3),
            Text(
              _subiendo
                  ? 'Subiendo fotos...'
                  // En movil no se arrastra: el toque abre la galeria.
                  : 'Toca aquí para subir fotos',
              textAlign: TextAlign.center,
              style: RtcType.base.copyWith(
                fontWeight: FontWeight.w900,
                color: Gray.c700,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s4),
              child: Text(
                'JPG, PNG · Máx 5MB por foto · Recomendado: 1280×720px',
                textAlign: TextAlign.center,
                style: RtcType.xs.copyWith(color: Gray.c500),
              ),
            ),
            if (!_subiendo) ...[
              const SizedBox(height: RtcSpace.s3),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: RtcSpace.s5,
                  vertical: 10, // py-2.5
                ),
                decoration: BoxDecoration(
                  color: Green.c600,
                  borderRadius: RtcRadius.brXl,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.plus, size: 16, color: Colors.white),
                    const SizedBox(width: RtcSpace.s2),
                    Text(
                      'Seleccionar fotos',
                      style: RtcType.sm.copyWith(
                        fontWeight: RtcType.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (!cloudinaryConfigurado) ...[
              const SizedBox(height: RtcSpace.s3),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s4),
                child: Text(
                  'Esta compilación no trae el preset de Cloudinary: las '
                  'fotos no se van a poder subir.',
                  textAlign: TextAlign.center,
                  style: RtcType.xs.copyWith(color: Red.c500),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _galeria() {
    final fotos = _fotos;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '${fotos.length} FOTO${fotos.length != 1 ? 'S' : ''} — '
                        '${_cancha?.name ?? ''}'
                    .toUpperCase(),
                style: RtcType.xs.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Gray.c500,
                  letterSpacing: 1.6,
                ),
              ),
            ),
            if (fotos.isNotEmpty) ...[
              const SizedBox(width: RtcSpace.s3),
              Text(
                '⭐ = principal',
                style: RtcType.xs.copyWith(color: Gray.c500),
              ),
            ],
          ],
        ),
        const SizedBox(height: RtcSpace.s4),
        if (fotos.isEmpty) _sinFotos() else _cuadricula(fotos),
      ],
    );
  }

  Widget _sinFotos() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 64), // py-16
      decoration: BoxDecoration(
        color: Superficie.tarjeta,
        borderRadius: RtcRadius.brXxl,
      ),
      child: Column(
        children: [
          Icon(LucideIcons.image, size: 48, color: Gray.c300),
          const SizedBox(height: RtcSpace.s3),
          Text(
            'SIN FOTOS AÚN',
            style: RtcType.sm.copyWith(
              fontWeight: FontWeight.w900,
              color: Gray.c500,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: RtcSpace.s6),
            child: Text(
              'Sube fotos de tu cancha para atraer más clientes',
              textAlign: TextAlign.center,
              style: RtcType.xs.copyWith(color: Gray.c500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cuadricula(List<String> fotos) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: fotos.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: RtcSpace.s4,
        mainAxisSpacing: RtcSpace.s4,
        // `h-44` de la web mas el alto de la barra de acciones.
        mainAxisExtent: 176 + 44,
      ),
      itemBuilder: (context, i) => _tarjetaFoto(fotos[i], i),
    );
  }

  Widget _tarjetaFoto(String url, int i) {
    final principal = i == 0;
    final ocupada = _ocupada == url;
    return Container(
      decoration: BoxDecoration(
        color: Superficie.tarjeta,
        borderRadius: RtcRadius.brXxl,
        border: Border.all(color: principal ? Lime.c400 : Gray.c100, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 176 - 4, // h-44 menos el borde
            child: Stack(
              fit: StackFit.expand,
              children: [
                RemoteImage(url: url, fit: BoxFit.cover),
                if (principal)
                  Positioned(
                    top: RtcSpace.s3,
                    left: RtcSpace.s3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: const BoxDecoration(
                        color: Lime.c400,
                        borderRadius: RtcRadius.brFull,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            LucideIcons.star,
                            size: 12,
                            color: GrisFijo.c900,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Principal',
                            style: RtcType.xs.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: GrisFijo.c900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // En la web los botones viven en un velo que aparece con
          // `group-hover`. En movil no hay hover: van en una barra fija.
          Expanded(
            child: Row(
              children: [
                if (!principal)
                  Expanded(
                    child: _accion(
                      LucideIcons.star,
                      Lime.c400,
                      Gray.c900,
                      ocupada ? null : () => _hacerPrincipal(url),
                      ocupada,
                    ),
                  ),
                Expanded(
                  child: _accion(
                    LucideIcons.trash2,
                    Red.c500,
                    Colors.white,
                    ocupada ? null : () => _eliminar(url),
                    ocupada,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accion(
    IconData icono,
    Color fondo,
    Color color,
    VoidCallback? onTap,
    bool ocupada,
  ) {
    return RtcPressable(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Opacity(
        // `disabled:opacity-50`
        opacity: ocupada ? 0.5 : 1,
        child: Container(
          color: fondo,
          alignment: Alignment.center,
          child: Icon(icono, size: 20, color: color),
        ),
      ),
    );
  }

  Widget _tips() {
    final azulFondo = Blue.c50; // blue-50
    final azulBorde = Blue.c100; // blue-100
    final azul800 = Blue.c800;
    final azul700 = Blue.c700;

    return Container(
      padding: const EdgeInsets.all(RtcSpace.s5),
      decoration: BoxDecoration(
        color: azulFondo,
        borderRadius: RtcRadius.brXxl,
        border: Border.all(color: azulBorde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💡 Tips para mejores fotos',
            style: RtcType.sm.copyWith(
              fontWeight: FontWeight.w900,
              color: azul800,
            ),
          ),
          const SizedBox(height: RtcSpace.s2),
          for (final t in const [
            'Toma fotos con buena iluminación natural o con la iluminación '
                'nocturna encendida',
            'Muestra toda la cancha en la foto principal — que se vea el '
                'campo completo',
            'Incluye fotos de los vestidores, parqueadero y áreas comunes si '
                'los tienes',
            'Las canchas con más de 3 fotos reciben un 40% más de reservas',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $t', style: RtcType.xs.copyWith(color: azul700)),
            ),
        ],
      ),
    );
  }
}
