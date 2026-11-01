import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../api/owner_api.dart';
import '../../api/rtc_api.dart';
import '../../auth/session.dart';
import '../../theme/palette.dart';
import '../../theme/tokens.dart';
import '../../theme/typography.dart';
import '../../widgets/rtc_toast.dart';

/// Port de `Frontend/src/app/dashboard/propetario/equipo/page.tsx`: el dueño
/// da acceso al panel a quien le ayuda en el club.
class EquipoScreen extends StatefulWidget {
  const EquipoScreen({super.key});

  @override
  State<EquipoScreen> createState() => _EquipoScreenState();
}

class _EquipoScreenState extends State<EquipoScreen> {
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _telefono = TextEditingController();

  List<MiembroEquipo> _equipo = const [];
  bool _cargando = true;
  bool _enviando = false;

  bool get _esStaff => RtcSession.instance.user?.esStaff == true;

  @override
  void initState() {
    super.initState();
    if (!_esStaff) _cargar();
  }

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _telefono.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      final e = await ownerApi.equipo();
      if (!mounted) return;
      setState(() {
        _equipo = e;
        _cargando = false;
      });
    } on RtcApiException catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      rtcToast(context, e.message, tipo: RtcToastTipo.error);
    }
  }

  Future<void> _accion(Future<void> Function() f, String ok) async {
    try {
      await f();
      if (!mounted) return;
      rtcToast(context, ok);
      await _cargar();
    } on RtcApiException catch (e) {
      if (!mounted) return;
      rtcToast(context, e.message, tipo: RtcToastTipo.error);
    }
  }

  Future<void> _invitar() async {
    if (_nombre.text.trim().length < 2 || !_email.text.contains('@')) {
      rtcToast(context, 'Escribe el nombre y el correo', tipo: RtcToastTipo.error);
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _enviando = true);
    await _accion(
      () => ownerApi.invitarAlEquipo(nombre: _nombre.text, email: _email.text, telefono: _telefono.text),
      'Listo: le enviamos el acceso por correo',
    );
    if (!mounted) return;
    setState(() => _enviando = false);
    _nombre.clear();
    _email.clear();
    _telefono.clear();
  }

  Future<void> _quitar(MiembroEquipo p) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Quitar a ${p.nombre}?'),
        content: const Text('Ya no podrá entrar al panel del club.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Quitar')),
        ],
      ),
    );
    if (si == true) await _accion(() => ownerApi.quitarDelEquipo(p.id), 'Persona quitada del equipo');
  }

  InputDecoration _deco(String hint) => InputDecoration(
    hintText: hint,
    isDense: true,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: RtcRadius.brXl, borderSide: const BorderSide(color: Gray.c200)),
    enabledBorder: OutlineInputBorder(borderRadius: RtcRadius.brXl, borderSide: const BorderSide(color: Gray.c200)),
  );

  @override
  Widget build(BuildContext context) {
    if (_esStaff) {
      return Center(
        child: Text(
          'Solo el dueño del club gestiona el equipo',
          style: RtcType.sm.copyWith(color: Gray.c500, fontWeight: RtcType.bold),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      color: Green.c600,
      child: ListView(
        padding: const EdgeInsets.only(bottom: RtcSpace.s12),
        children: [
          Text('Panel propietario', style: RtcType.sm.copyWith(color: Green.c700, fontWeight: RtcType.semibold)),
          const SizedBox(height: 4),
          Text('Equipo', style: RtcType.xl3.copyWith(letterSpacing: -0.4, fontWeight: FontWeight.w900, color: Gray.c900)),
          const SizedBox(height: 4),
          Text(
            'Cada persona entra con su correo y puede ver y anotar reservas, bloquear '
            'horarios y escanear los QR. No ve tus pagos, no cambia tu cuenta de ePayco, '
            'no borra canchas ni toca el equipo.',
            style: RtcType.sm.copyWith(color: Gray.c500),
          ),
          const SizedBox(height: RtcSpace.s5),
          Container(
            padding: const EdgeInsets.all(RtcSpace.s4),
            decoration: BoxDecoration(color: Colors.white, borderRadius: RtcRadius.brXxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.userPlus, size: 18, color: Green.c600),
                    const SizedBox(width: RtcSpace.s2),
                    Text('DAR ACCESO', style: RtcType.sm.copyWith(fontWeight: FontWeight.w900, color: Gray.c900)),
                  ],
                ),
                const SizedBox(height: RtcSpace.s3),
                TextField(controller: _nombre, decoration: _deco('Nombre')),
                const SizedBox(height: RtcSpace.s2),
                TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: _deco('Correo')),
                const SizedBox(height: RtcSpace.s2),
                TextField(controller: _telefono, keyboardType: TextInputType.phone, decoration: _deco('Celular (opcional)')),
                const SizedBox(height: RtcSpace.s3),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Green.c600,
                    minimumSize: const Size.fromHeight(46),
                    shape: RoundedRectangleBorder(borderRadius: RtcRadius.brXl),
                  ),
                  onPressed: _enviando ? null : _invitar,
                  child: Text(_enviando ? 'Enviando…' : 'Enviar acceso'),
                ),
                const SizedBox(height: 6),
                Text(
                  'Le llega un correo con una clave temporal. Hasta 10 personas por club.',
                  style: RtcType.xs.copyWith(fontSize: 11, color: Gray.c400),
                ),
              ],
            ),
          ),
          const SizedBox(height: RtcSpace.s5),
          if (_cargando)
            Container(height: 80, decoration: BoxDecoration(color: Gray.c100, borderRadius: RtcRadius.brXxl))
          else if (_equipo.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: RtcSpace.s8),
              child: Text(
                'Todavía no hay nadie en tu equipo',
                textAlign: TextAlign.center,
                style: RtcType.xs.copyWith(fontWeight: FontWeight.w900, color: Gray.c400),
              ),
            )
          else
            for (final p in _equipo) _persona(p),
        ],
      ),
    );
  }

  Widget _persona(MiembroEquipo p) {
    final ingreso = p.ultimoIngreso;
    return Container(
      margin: const EdgeInsets.only(bottom: RtcSpace.s3),
      padding: const EdgeInsets.all(RtcSpace.s4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: RtcRadius.brXxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(p.nombre, style: RtcType.sm.copyWith(fontWeight: FontWeight.w900, color: Gray.c900)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: p.activo ? const Color(0xFFDCFCE7) : Gray.c100,
                  borderRadius: RtcRadius.brFull,
                ),
                child: Text(
                  p.activo ? 'Activo' : 'Pausado',
                  style: RtcType.xs.copyWith(fontSize: 10, fontWeight: RtcType.bold, color: p.activo ? Green.c700 : Gray.c500),
                ),
              ),
            ],
          ),
          Text('${p.email}${p.telefono != null ? ' · ${p.telefono}' : ''}', style: RtcType.xs.copyWith(color: Gray.c500)),
          Text(
            ingreso == null
                ? 'Aún no ha entrado'
                : 'Último ingreso: ${ingreso.day}/${ingreso.month}/${ingreso.year}',
            style: RtcType.xs.copyWith(fontSize: 11, color: Gray.c400),
          ),
          const SizedBox(height: RtcSpace.s3),
          Row(
            children: [
              _boton(p.activo ? 'Pausar' : 'Reactivar', p.activo ? LucideIcons.pause : LucideIcons.play, () {
                _accion(() => ownerApi.accesoEquipo(p.id, !p.activo), p.activo ? 'Acceso pausado' : 'Acceso reactivado');
              }),
              const SizedBox(width: RtcSpace.s2),
              _boton('Clave', LucideIcons.keyRound, () {
                _accion(() => ownerApi.nuevaClaveEquipo(p.id), 'Le enviamos una clave nueva por correo');
              }),
              const SizedBox(width: RtcSpace.s2),
              _boton('Quitar', LucideIcons.trash2, () => _quitar(p), peligro: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _boton(String texto, IconData icono, VoidCallback onTap, {bool peligro = false}) {
    final color = peligro ? Red.c600 : Gray.c700;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: RtcRadius.brXl,
            border: Border.all(color: peligro ? const Color(0xFFFECACA) : Gray.c200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 14, color: color),
              const SizedBox(width: 4),
              Text(texto, style: RtcType.xs.copyWith(fontWeight: RtcType.bold, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}
