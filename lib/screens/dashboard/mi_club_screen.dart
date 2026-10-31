import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/cloudinary.dart';
import '../../api/owner_api.dart';
import '../../api/rtc_api.dart';
import '../../theme/palette.dart';
import '../../theme/shadows.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/icons/brand_icon.dart';
import '../../widgets/motion/rtc_motion.dart';
import '../../widgets/remote_image.dart';
import '../../widgets/rtc_borde_punteado.dart';
import '../../widgets/rtc_select_field.dart';
import '../../widgets/rtc_toast.dart';

/// Port de `Frontend/src/app/dashboard/propetario/mi-club/page.tsx`.
///
/// Seis secciones con el conmutador de `SettingsTabs`: informacion, ubicacion,
/// contacto, logo, redes y fotos. Las fotos se guardan al instante; el resto
/// espera al boton de guardar.
class MiClubScreen extends StatefulWidget {
  const MiClubScreen({super.key});

  @override
  State<MiClubScreen> createState() => _MiClubScreenState();
}

/// `SECTION_FIELDS`.
const _camposPorSeccion = <String, List<String>>{
  'info': ['name', 'slogan', 'description'],
  'ubicacion': ['address', 'city'],
  'contacto': ['contactPhone', 'contactEmail', 'schedule'],
  'logo': [],
  'redes': ['instagram', 'facebook', 'tiktok', 'whatsapp'],
  'fotos': [],
};

/// `optionalUrl`: o esta vacio, o es una URL con esquema y punto.
final _reUrl = RegExp(r'^https?://[^\s.]+\.[^\s]+$');

/// `z.string().email()` de zod, en su version simple.
final _reEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// `normalizeWhatsapp`: un numero suelto se vuelve link de wa.me.
String _normalizarWhatsapp(String valor) {
  final v = valor.trim();
  if (v.isEmpty) return '';
  if (RegExp(r'^https?://', caseSensitive: false).hasMatch(v)) return v;
  final digitos = v.replaceAll(RegExp(r'\D'), '');
  return digitos.isEmpty ? '' : 'https://wa.me/$digitos';
}

class _MiClubScreenState extends State<MiClubScreen> {
  final _nombre = TextEditingController();
  final _slogan = TextEditingController();
  final _descripcion = TextEditingController();
  final _direccion = TextEditingController();
  final _ciudad = TextEditingController();
  final _telefono = TextEditingController();
  final _email = TextEditingController();
  final _horario = TextEditingController();
  final _instagram = TextEditingController();
  final _facebook = TextEditingController();
  final _tiktok = TextEditingController();
  final _whatsapp = TextEditingController();

  late final List<TextEditingController> _todos = [
    _nombre,
    _slogan,
    _descripcion,
    _direccion,
    _ciudad,
    _telefono,
    _email,
    _horario,
    _instagram,
    _facebook,
    _tiktok,
    _whatsapp,
  ];

  ClubPerfil? _club;
  bool _cargando = true;
  bool _guardando = false;
  bool _subiendoLogo = false;
  bool _subiendoFotos = false;
  String _seccion = 'info';

  String _logo = '';
  String _logoGuardado = '';

  bool _sucio = false;
  final _errores = <String, String>{};

  @override
  void initState() {
    super.initState();
    _cargar();
    for (final c in _todos) {
      c.addListener(_marcarSucio);
    }
  }

  @override
  void dispose() {
    for (final c in _todos) {
      c.dispose();
    }
    super.dispose();
  }

  void _marcarSucio() {
    if (!_sucio && !_cargando) setState(() => _sucio = true);
  }

  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _cargando = true);
    final club = await ownerApi.perfilClub();
    if (!mounted) return;
    setState(() {
      _club = club;
      if (club != null) _volcar(club);
      _cargando = false;
    });
  }

  /// `reset(...)` con lo que llega del servidor.
  void _volcar(ClubPerfil c) {
    _nombre.text = c.nombre;
    _slogan.text = c.slogan;
    _descripcion.text = c.descripcion;
    _direccion.text = c.direccion;
    _ciudad.text = c.ciudad;
    _telefono.text = c.telefono;
    _email.text = c.email;
    _horario.text = c.horario;
    _instagram.text = c.instagram;
    _facebook.text = c.facebook;
    _tiktok.text = c.tiktok;
    _whatsapp.text = c.whatsapp;
    _logo = c.logo;
    _logoGuardado = c.logo;
    _sucio = false;
  }

  // ── VALIDACION ───────────────────────────────────────────────────────

  String? _error(String campo) {
    String t(TextEditingController c) => c.text.trim();
    switch (campo) {
      case 'name':
        return t(_nombre).length < 3 ? 'Mínimo 3 caracteres' : null;
      case 'slogan':
        return t(_slogan).length > 120 ? 'Máximo 120 caracteres' : null;
      case 'description':
        return t(_descripcion).length > 600 ? 'Máximo 600 caracteres' : null;
      case 'contactEmail':
        final v = t(_email);
        return v.isEmpty || _reEmail.hasMatch(v) ? null : 'Email inválido';
      case 'instagram':
      case 'facebook':
      case 'tiktok':
        final v = t(
          campo == 'instagram'
              ? _instagram
              : campo == 'facebook'
              ? _facebook
              : _tiktok,
        );
        return v.isEmpty || _reUrl.hasMatch(v)
            ? null
            : 'Debe ser un link completo (https://...)';
    }
    return null;
  }

  // ── ACCIONES ─────────────────────────────────────────────────────────

  Future<void> _guardar() async {
    if (_guardando) return;
    FocusScope.of(context).unfocus();

    _errores.clear();
    for (final campos in _camposPorSeccion.values) {
      for (final c in campos) {
        final e = _error(c);
        if (e != null) _errores[c] = e;
      }
    }
    if (_errores.isNotEmpty) {
      // `onInvalid`: se abre la seccion que tiene el error.
      final mala = _camposPorSeccion.entries
          .where((e) => e.value.any(_errores.containsKey))
          .map((e) => e.key)
          .firstOrNull;
      setState(() {
        if (mala != null) _seccion = mala;
      });
      rtcToast(
        context,
        'Revisa los campos marcados en rojo.',
        tipo: RtcToastTipo.error,
      );
      return;
    }

    setState(() => _guardando = true);
    final whatsapp = _normalizarWhatsapp(_whatsapp.text);
    try {
      await ownerApi.guardarPerfilClub({
        'name': _nombre.text.trim(),
        'slogan': _slogan.text.trim(),
        'description': _descripcion.text.trim(),
        'address': _direccion.text.trim(),
        'city': _ciudad.text.trim(),
        'contactPhone': _telefono.text.trim(),
        'contactEmail': _email.text.trim(),
        'schedule': _horario.text.trim(),
        'logo': _logo,
        'socialLinks': {
          'instagram': _instagram.text.trim(),
          'facebook': _facebook.text.trim(),
          'tiktok': _tiktok.text.trim(),
          'whatsapp': whatsapp,
        },
      });
      if (!mounted) return;
      rtcToast(context, 'Perfil actualizado');
      setState(() {
        _guardando = false;
        // `reset({...values, whatsapp: normalize(...)})`
        _whatsapp.text = whatsapp;
        _logoGuardado = _logo;
        _sucio = false;
      });
      await _cargar(silencioso: true);
    } on RtcApiException catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      rtcToast(context, e.message, tipo: RtcToastTipo.error);
    }
  }

  /// `handleDiscard`.
  void _descartar() {
    final club = _club;
    if (club == null) return;
    setState(() {
      _volcar(club);
      _errores.clear();
    });
  }

  Future<void> _subirLogo() async {
    if (_subiendoLogo) return;
    final foto = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (foto == null || !mounted) return;
    setState(() => _subiendoLogo = true);
    try {
      final url = await subirACloudinary(
        await foto.readAsBytes(),
        foto.name,
        carpeta: 'clubs',
      );
      if (!mounted) return;
      setState(() {
        _logo = url;
        _subiendoLogo = false;
      });
      rtcToast(context, 'Logo subido — recuerda guardar');
    } catch (_) {
      if (!mounted) return;
      setState(() => _subiendoLogo = false);
      rtcToast(context, 'Error subiendo logo', tipo: RtcToastTipo.error);
    }
  }

  Future<void> _subirFotos() async {
    if (_subiendoFotos) return;
    final elegidas = (await ImagePicker().pickMultiImage()).take(10).toList();
    if (elegidas.isEmpty || !mounted) return;
    setState(() => _subiendoFotos = true);
    var subidas = 0;
    for (final foto in elegidas) {
      try {
        final url = await subirACloudinary(
          await foto.readAsBytes(),
          foto.name,
          carpeta: 'clubs',
        );
        await ownerApi.agregarFotoClub(url);
        subidas++;
      } catch (_) {
        if (!mounted) return;
        rtcToast(context, 'Error con ${foto.name}', tipo: RtcToastTipo.error);
      }
    }
    if (!mounted) return;
    setState(() => _subiendoFotos = false);
    if (subidas > 0) {
      rtcToast(
        context,
        '$subidas foto${subidas > 1 ? 's' : ''} '
        'subida${subidas > 1 ? 's' : ''}',
      );
    }
    await _cargar(silencioso: true);
  }

  Future<void> _eliminarFoto(String url) async {
    try {
      await ownerApi.eliminarFotoClub(url);
      await _cargar(silencioso: true);
    } on RtcApiException catch (e) {
      if (!mounted) return;
      rtcToast(context, e.message, tipo: RtcToastTipo.error);
    }
  }

  bool get _hayCambios => _sucio || _logo != _logoGuardado;

  // ── VISTA ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_cargando) return _esqueleto();
    if (_club == null) return _sinClub();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _encabezado(),
              const SizedBox(height: RtcSpace.s5),
              if ((_club!.slug ?? '').isNotEmpty) ...[
                _linkPublico(_club!.slug!),
                const SizedBox(height: RtcSpace.s5),
              ],
              RtcSettingsTabs(
                secciones: [
                  (
                    'info',
                    'Información',
                    'Nombre, slogan y descripción de tu club',
                    LucideIcons.building2,
                    _camposPorSeccion['info']!.any(_errores.containsKey),
                  ),
                  (
                    'ubicacion',
                    'Ubicación',
                    'Dónde te encuentran tus clientes',
                    LucideIcons.mapPin,
                    _camposPorSeccion['ubicacion']!.any(_errores.containsKey),
                  ),
                  (
                    'contacto',
                    'Contacto',
                    'Teléfono, email y horario de atención',
                    LucideIcons.phone,
                    _camposPorSeccion['contacto']!.any(_errores.containsKey),
                  ),
                  (
                    'logo',
                    'Logo',
                    'La imagen que identifica tu club',
                    LucideIcons.image,
                    false,
                  ),
                  (
                    'redes',
                    'Redes',
                    'Links a tus redes sociales',
                    LucideIcons.share2,
                    _camposPorSeccion['redes']!.any(_errores.containsKey),
                  ),
                  (
                    'fotos',
                    'Fotos',
                    'Galería de tus instalaciones',
                    LucideIcons.camera,
                    false,
                  ),
                ],
                activa: _seccion,
                onChange: (s) => setState(() => _seccion = s),
                child: _panel(),
              ),
              const SizedBox(height: RtcSpace.s5),
            ],
          ),
        ),
        // La barra no aparece en Fotos: ahi se guarda al instante.
        if (_seccion != 'fotos') _barraGuardado(),
      ],
    );
  }

  Widget _esqueleto() {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        RtcSkeletonPulse(
          child: Container(
            height: 32,
            width: 192, // w-48
            decoration: BoxDecoration(
              color: Gray.c200,
              borderRadius: RtcRadius.brXl,
            ),
          ),
        ),
        const SizedBox(height: RtcSpace.s5),
        RtcSkeletonPulse(
          child: Container(
            height: 288, // h-72
            decoration: BoxDecoration(
              color: Gray.c100,
              borderRadius: RtcRadius.brXxl,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sinClub() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 80),
      children: [
        Text(
          'SIN CLUB REGISTRADO',
          textAlign: TextAlign.center,
          style: RtcType.xl2.copyWith(
            fontWeight: FontWeight.w900,
            color: Gray.c300,
          ),
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
          'Mi club',
          style: RtcType.xl2.copyWith(
            letterSpacing: -0.4,
            fontWeight: FontWeight.w900,
            color: Gray.c900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Elige qué quieres editar — esto es lo que ven tus clientes',
          style: RtcType.sm.copyWith(color: Gray.c500),
        ),
      ],
    );
  }

  Widget _linkPublico(String slug) {
    const url = 'reservatucancha.site/club/';
    return Container(
      padding: const EdgeInsets.all(RtcSpace.s4),
      decoration: BoxDecoration(
        color: Gray.c900,
        borderRadius: RtcRadius.brXxl,
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.link2, size: 20, color: Lime.c400),
          const SizedBox(width: RtcSpace.s3),
          Expanded(
            child: Text(
              '$url$slug',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: RtcType.sm.copyWith(color: Gray.c300),
            ),
          ),
          const SizedBox(width: RtcSpace.s3),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: 'https://$url$slug'));
              if (!mounted) return;
              rtcToast(context, 'Link copiado');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: RtcSpace.s3,
                vertical: 6,
              ),
              decoration: const BoxDecoration(
                color: Lime.c400,
                borderRadius: RtcRadius.brFull,
              ),
              child: Text(
                'Copiar',
                style: RtcType.xs.copyWith(
                  fontWeight: RtcType.bold,
                  color: Gray.c900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── SECCIONES ────────────────────────────────────────────────────────

  Widget _panel() {
    switch (_seccion) {
      case 'ubicacion':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _campo('Dirección', _direccion, 'Ej: Calle 72 #45-23'),
            const SizedBox(height: RtcSpace.s4),
            _campo('Ciudad', _ciudad, 'Villavicencio'),
          ],
        );

      case 'contacto':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _campo('Teléfono', _telefono, '300 123 4567'),
            const SizedBox(height: RtcSpace.s4),
            _campo(
              'Email de contacto',
              _email,
              'contacto@tuclub.com',
              error: _errores['contactEmail'],
              teclado: TextInputType.emailAddress,
            ),
            const SizedBox(height: RtcSpace.s4),
            _campo(
              'Horario de atención',
              _horario,
              'Lunes a viernes 7am-10pm · Sábados y domingos 8am-8pm',
            ),
            const SizedBox(height: 6),
            Text(
              'Este texto se muestra tal cual en tu página pública.',
              style: RtcType.xs.copyWith(color: Gray.c400),
            ),
          ],
        );

      case 'logo':
        return _seccionLogo();

      case 'redes':
        return _seccionRedes();

      case 'fotos':
        return _seccionFotos();

      default:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _campo(
              'Nombre del club',
              _nombre,
              'Ej: Club Deportivo El Estadio',
              obligatorio: true,
              error: _errores['name'],
            ),
            const SizedBox(height: RtcSpace.s4),
            _campo(
              'Slogan',
              _slogan,
              'La mejor cancha sintética de Villavicencio',
              opcional: '(opcional)',
              error: _errores['slogan'],
            ),
            const SizedBox(height: RtcSpace.s4),
            _campo(
              'Descripción',
              _descripcion,
              'Describe tu club, qué ofreces, qué lo hace especial...',
              opcional: '(opcional)',
              error: _errores['description'],
              lineas: 5,
            ),
          ],
        );
    }
  }

  Widget _seccionLogo() {
    // `flex-col sm:flex-row`: en movil el cuadro va encima de los botones.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _subiendoLogo ? null : _subirLogo,
          child: Container(
            width: 112,
            height: 112,
            alignment: Alignment.center,
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              color: Gray.c100,
              shape: RtcBordePunteado(color: Gray.c300, radio: RtcRadius.xxl),
            ),
            child: _subiendoLogo
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF22C55E),
                    ),
                  )
                : _logo.isNotEmpty
                ? SizedBox.expand(
                    child: RemoteImage(url: _logo, fit: BoxFit.cover),
                  )
                : const Icon(LucideIcons.building2, size: 36, color: Gray.c300),
          ),
        ),
        const SizedBox(height: RtcSpace.s6),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _subiendoLogo ? null : _subirLogo,
          child: Opacity(
            opacity: _subiendoLogo ? 0.6 : 1,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: RtcSpace.s4,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: RtcRadius.brXl,
                border: Border.all(color: Gray.c200, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.upload, size: 16, color: Gray.c700),
                  const SizedBox(width: RtcSpace.s2),
                  Text(
                    _logo.isNotEmpty ? 'Cambiar logo' : 'Subir logo',
                    style: RtcType.sm.copyWith(
                      fontWeight: RtcType.bold,
                      color: Gray.c700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_logo.isNotEmpty) ...[
          const SizedBox(height: RtcSpace.s2),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _logo = ''),
            child: Text(
              'Quitar logo',
              style: RtcType.sm.copyWith(
                fontWeight: RtcType.semibold,
                color: Red.c500,
              ),
            ),
          ),
        ],
        const SizedBox(height: RtcSpace.s2),
        Text(
          'Recomendado: 200×200px, PNG o JPG',
          style: RtcType.xs.copyWith(color: Gray.c400),
        ),
      ],
    );
  }

  Widget _seccionRedes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Estos links aparecen en tu página pública. Deja vacío para no '
          'mostrar.',
          style: RtcType.xs.copyWith(color: Gray.c400),
        ),
        const SizedBox(height: RtcSpace.s4),
        _campo(
          'Instagram',
          _instagram,
          'https://instagram.com/tuclub',
          error: _errores['instagram'],
          icono: const BrandIcon(
            marca: RtcMarca.instagram,
            color: Color(0xFFEC4899), // pink-500
          ),
          teclado: TextInputType.url,
        ),
        const SizedBox(height: RtcSpace.s4),
        _campo(
          'Facebook',
          _facebook,
          'https://facebook.com/tuclub',
          error: _errores['facebook'],
          icono: const BrandIcon(
            marca: RtcMarca.facebook,
            color: Color(0xFF1877F2),
          ),
          teclado: TextInputType.url,
        ),
        const SizedBox(height: RtcSpace.s4),
        _campo(
          'TikTok',
          _tiktok,
          'https://tiktok.com/@tuclub',
          error: _errores['tiktok'],
          icono: const Icon(LucideIcons.music2, size: 16, color: Gray.c900),
          teclado: TextInputType.url,
        ),
        const SizedBox(height: RtcSpace.s4),
        _campo(
          'WhatsApp',
          _whatsapp,
          '300 123 4567',
          icono: const Icon(
            LucideIcons.messageCircle,
            size: 16,
            color: Color(0xFF25D366),
          ),
          teclado: TextInputType.phone,
        ),
        const SizedBox(height: 6),
        Text(
          'Número con indicativo o link wa.me',
          style: RtcType.xs.copyWith(color: Gray.c400),
        ),
      ],
    );
  }

  Widget _seccionFotos() {
    final fotos = _club?.fotos ?? const <String>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'Parqueadero, vestidores, cafetería, áreas comunes',
                style: RtcType.sm.copyWith(color: Gray.c500),
              ),
            ),
            const SizedBox(width: RtcSpace.s3),
            Text(
              '${fotos.length} foto${fotos.length != 1 ? 's' : ''}',
              style: RtcType.xs.copyWith(
                fontWeight: RtcType.bold,
                color: Gray.c400,
              ),
            ),
          ],
        ),
        const SizedBox(height: RtcSpace.s4),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _subiendoFotos ? null : _subirFotos,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: RtcSpace.s8),
            decoration: ShapeDecoration(
              shape: RtcBordePunteado(color: Gray.c200, radio: RtcRadius.xl),
            ),
            child: Column(
              children: [
                if (_subiendoFotos)
                  const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF22C55E),
                    ),
                  )
                else
                  const Icon(LucideIcons.camera, size: 24, color: Gray.c400),
                const SizedBox(height: RtcSpace.s2),
                Text(
                  _subiendoFotos
                      ? 'Subiendo...'
                      : 'Agregar fotos de instalaciones',
                  style: RtcType.sm.copyWith(
                    fontWeight: RtcType.bold,
                    color: Gray.c600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Hasta 10 fotos por vez',
                  style: RtcType.xs.copyWith(color: Gray.c400),
                ),
              ],
            ),
          ),
        ),
        if (fotos.isNotEmpty) ...[
          const SizedBox(height: RtcSpace.s4),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: fotos.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: RtcSpace.s3,
              mainAxisSpacing: RtcSpace.s3,
              // `h-32` mas la barra con el boton de borrar.
              mainAxisExtent: 128 + 40,
            ),
            itemBuilder: (context, i) => _tarjetaFoto(fotos[i]),
          ),
        ],
        const SizedBox(height: RtcSpace.s4),
        Text(
          'Las fotos se guardan al instante, no necesitas guardar cambios.',
          style: RtcType.xs.copyWith(color: Gray.c400),
        ),
      ],
    );
  }

  Widget _tarjetaFoto(String url) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: RtcRadius.brXl,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 128 - 2,
            child: RemoteImage(url: url, fit: BoxFit.cover),
          ),
          // En la web el boton vive en un velo con `group-hover`; en movil no
          // hay hover, asi que va en una barra fija.
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _eliminarFoto(url),
              child: Container(
                color: Red.c500,
                alignment: Alignment.center,
                child: const Icon(
                  LucideIcons.trash2,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── BARRA DE GUARDADO ────────────────────────────────────────────────

  Widget _barraGuardado() {
    return Container(
      // Sin padding horizontal: el armazon del panel ya pone el suyo, igual
      // que el `-mx-4 … px-4` de la web.
      padding: const EdgeInsets.only(top: RtcSpace.s6, bottom: RtcSpace.s4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Slate.c50.withValues(alpha: 0), Slate.c50, Slate.c50],
          stops: const [0, 0.45, 1],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _guardando || !_hayCambios ? null : _descartar,
                  child: Opacity(
                    opacity: _guardando || !_hayCambios ? 0.5 : 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: RtcSpace.s4,
                      ),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: RtcRadius.brXxl,
                        border: Border.all(color: Gray.c200, width: 2),
                      ),
                      child: Text(
                        'Descartar',
                        style: RtcType.base.copyWith(
                          fontWeight: RtcType.bold,
                          color: Gray.c700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: RtcSpace.s3),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _guardando ? null : _guardar,
                  child: Opacity(
                    opacity: _guardando ? 0.6 : 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: RtcSpace.s4,
                      ),
                      decoration: BoxDecoration(
                        color: Green.c600,
                        borderRadius: RtcRadius.brXxl,
                        boxShadow: [
                          cssShadow(
                            dy: 10,
                            blur: 15,
                            color: Green.c600.withValues(alpha: 0.20),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_guardando) ...[
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: RtcSpace.s2),
                            Text(
                              'Guardando...',
                              style: RtcType.base.copyWith(
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ] else ...[
                            const Icon(
                              LucideIcons.save,
                              size: 20,
                              color: Colors.white,
                            ),
                            const SizedBox(width: RtcSpace.s2),
                            Text(
                              'Guardar cambios',
                              style: RtcType.base.copyWith(
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_hayCambios) ...[
            const SizedBox(height: RtcSpace.s2),
            Text(
              'Tienes cambios sin guardar',
              style: RtcType.xs.copyWith(color: Gray.c400),
            ),
          ],
        ],
      ),
    );
  }

  // ── PIEZAS ───────────────────────────────────────────────────────────

  Widget _campo(
    String etiqueta,
    TextEditingController controller,
    String hint, {
    bool obligatorio = false,
    String? opcional,
    String? error,
    int lineas = 1,
    Widget? icono,
    TextInputType? teclado,
  }) {
    final mal = error != null;
    final borde = OutlineInputBorder(
      borderRadius: RtcRadius.brXl,
      borderSide: BorderSide(color: mal ? Red.c300 : Gray.c200),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // `lblIcon`: el icono acompaña la etiqueta en las redes.
            if (icono != null) ...[icono, const SizedBox(width: 6)],
            Flexible(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: etiqueta.toUpperCase()),
                    if (obligatorio)
                      const TextSpan(
                        text: ' *',
                        style: TextStyle(color: Red.c500),
                      ),
                    if (opcional != null)
                      TextSpan(
                        text: ' $opcional',
                        style: RtcType.xs.copyWith(
                          color: Gray.c400,
                          fontWeight: RtcType.medium,
                          letterSpacing: 0,
                        ),
                      ),
                  ],
                ),
                style: RtcType.xs.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Gray.c500,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: RtcSpace.s2),
        TextField(
          controller: controller,
          maxLines: lineas,
          keyboardType: teclado,
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
              borderSide: BorderSide(
                color: mal ? Red.c300 : Green.c400,
                width: 2,
              ),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(error, style: RtcType.xs.copyWith(color: Red.c500)),
          ),
      ],
    );
  }
}
