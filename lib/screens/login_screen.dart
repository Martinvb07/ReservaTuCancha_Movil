import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../api/rtc_api.dart';
import '../app/routes.dart';
import '../auth/session.dart';
import '../data/google_login.dart';
import '../theme/motion.dart';
import '../theme/palette.dart';
import '../theme/shadows.dart';
import '../theme/tokens.dart';
import '../theme/typography.dart';
import '../widgets/motion/rtc_motion.dart';
import '../widgets/motion/rtc_pressable.dart';

/// Port de `Frontend/src/app/(public)/auth/login/page.tsx`, rama movil.
///
/// La web es una grilla de dos columnas donde la izquierda (la foto con los
/// beneficios) es `hidden lg:flex`: en telefono no existe. Queda la columna
/// derecha, que ahi ocupa el ancho completo.
///
/// La pagina es `fixed inset-0 z-50`, o sea que tapa el navbar. Por eso
/// `RtcLayout` esconde el header en esta ruta.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  /// `mode: 'onTouched'` del resolver de zod: el campo no se marca en rojo
  /// hasta que se sale de el una vez.
  bool _emailTouched = false;
  bool _passwordTouched = false;

  bool _showPass = false;
  bool _loading = false;
  String? _authError;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// `z.string().email()`.
  static bool _isEmail(String v) =>
      RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$').hasMatch(v);

  /// El mismo esquema de zod: email valido y minimo 6 caracteres.
  bool _validate() {
    setState(() {
      _emailError = _isEmail(_email.text.trim()) ? null : 'Email inválido';
      _passwordError = _password.text.length >= 6
          ? null
          : 'Mínimo 6 caracteres';
    });
    return _emailError == null && _passwordError == null;
  }

  bool _conGoogle = false;

  Future<void> _entrarConGoogle() async {
    if (_conGoogle || _loading) return;
    setState(() {
      _conGoogle = true;
      _authError = null;
    });
    try {
      final idToken = await GoogleLogin.idToken();
      if (idToken == null) {
        if (mounted) setState(() => _conGoogle = false);
        return;
      }
      await RtcSession.instance.loginConGoogle(idToken);
      if (!mounted) return;
      rtcAbrirPanel();
    } on RtcApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _authError = e.message;
        _conGoogle = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _authError =
            'No pudimos abrir Google. Intenta de nuevo o entra con tu correo.';
        _conGoogle = false;
      });
    }
  }

  Widget _botonGoogle() {
    return OutlinedButton.icon(
      onPressed: _conGoogle ? null : _entrarConGoogle,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        side: BorderSide(color: Gray.c200),
        foregroundColor: Gray.c900,
        shape: RoundedRectangleBorder(borderRadius: RtcRadius.brXxl),
      ),
      icon: const Text(
        'G',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w900,
          color: Blue.c600,
        ),
      ),
      label: Text(
        _conGoogle ? 'Abriendo Google…' : 'Entrar con Google',
        style: RtcType.sm.copyWith(fontWeight: RtcType.bold),
      ),
    );
  }

  Future<void> _submit() async {
    if (_loading) return;
    _emailTouched = true;
    _passwordTouched = true;
    if (!_validate()) return;

    setState(() {
      _loading = true;
      _authError = null;
    });

    try {
      await RtcSession.instance.login(_email.text.trim(), _password.text);
      if (!mounted) return;
      // Igual que la web: al entrar se abre el panel, no la home.
      rtcAbrirPanel();
    } on RtcApiException {
      if (!mounted) return;
      setState(() {
        _authError =
            'Email o contraseña incorrectos. Verifica tus datos e intenta de nuevo.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Superficie.tarjeta,
      child: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(child: _form()),
          ],
        ),
      ),
    );
  }

  // ── BARRA SUPERIOR ───────────────────────────────────────────────────
  // px-6 py-5 border-b border-gray-100
  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s6,
        vertical: RtcSpace.s5,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Gray.c100)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RtcPressable(
            behavior: HitTestBehavior.opaque,
            onTap: () => rtcNavigate('/'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Gray.c200),
                  ),
                  child: Icon(
                    LucideIcons.arrowLeft,
                    size: 16,
                    color: Gray.c500,
                  ),
                ),
                const SizedBox(width: RtcSpace.s2),
                Text(
                  'Volver al inicio',
                  style: RtcType.sm.copyWith(
                    fontWeight: RtcType.semibold,
                    color: Gray.c500,
                  ),
                ),
              ],
            ),
          ),
          // El logo de la web es `lg:hidden`: justamente el caso del telefono.
          RtcPressable(
            behavior: HitTestBehavior.opaque,
            onTap: () => rtcNavigate('/'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/logo.png', height: 36, width: 36),
                const SizedBox(width: RtcSpace.s2),
                Text.rich(
                  const TextSpan(
                    children: [
                      TextSpan(text: 'Reserva'),
                      TextSpan(
                        text: 'TuCancha',
                        style: TextStyle(color: Green.c600),
                      ),
                    ],
                  ),
                  style: RtcType.base.copyWith(
                    fontWeight: FontWeight.w900,
                    color: Gray.c900,
                    letterSpacing: -0.4, // tracking-tight
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── FORMULARIO ───────────────────────────────────────────────────────
  // px-6 py-10, max-w-md, space-y-7
  Widget _form() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s6,
        vertical: RtcSpace.s10,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448), // max-w-md
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              RtcFormFadeIn(
                delay: const Duration(milliseconds: 50),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INICIAR SESIÓN',
                      style: RtcType.xl3.copyWith(
                        fontWeight: FontWeight.w900,
                        color: Gray.c900,
                      ),
                    ),
                    const SizedBox(height: RtcSpace.s1),
                    Text(
                      'Accede a tu dashboard para gestionar tus canchas deportivas.',
                      style: RtcType.sm.copyWith(color: Gray.c500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: RtcSpace.s7),

              // El error de credenciales entra abriendo alto, como el
              // AnimatePresence con `height: auto`.
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: RtcCurves.framerExpo,
                alignment: Alignment.topCenter,
                child: _authError == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(bottom: RtcSpace.s7),
                        child: _errorBanner(_authError!),
                      ),
              ),

              RtcFormFadeIn(
                delay: const Duration(milliseconds: 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _field(
                      label: 'EMAIL',
                      controller: _email,
                      hint: 'propietario@email.com',
                      error: _emailError,
                      keyboard: TextInputType.emailAddress,
                      onFocus: () => _emailTouched = true,
                      onLeave: () {
                        if (_emailTouched && !_isEmail(_email.text.trim())) {
                          setState(() => _emailError = 'Email inválido');
                        }
                      },
                      onChanged: () {
                        if (_emailError != null) {
                          setState(() => _emailError = null);
                        }
                      },
                    ),
                    const SizedBox(height: RtcSpace.s5),
                    _field(
                      label: 'CONTRASEÑA',
                      controller: _password,
                      hint: '••••••••',
                      error: _passwordError,
                      obscure: !_showPass,
                      trailing: RtcPressable(
                        onTap: () => setState(() => _showPass = !_showPass),
                        child: Icon(
                          _showPass ? LucideIcons.eyeOff : LucideIcons.eye,
                          size: 16,
                          color: Gray.c500,
                        ),
                      ),
                      action: RtcPressable(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => rtcNavigate('/auth/olvide'),
                        child: Text(
                          '¿Olvidaste tu contraseña?',
                          style: RtcType.xs.copyWith(
                            fontWeight: RtcType.semibold,
                            color: Gray.c500,
                          ),
                        ),
                      ),
                      onFocus: () => _passwordTouched = true,
                      onLeave: () {
                        if (_passwordTouched && _password.text.length < 6) {
                          setState(
                            () => _passwordError = 'Mínimo 6 caracteres',
                          );
                        }
                      },
                      onChanged: () {
                        if (_passwordError != null) {
                          setState(() => _passwordError = null);
                        }
                      },
                    ),
                    const SizedBox(height: RtcSpace.s5),
                    _submitButton(),
                    if (GoogleLogin.disponible) ...[
                      const SizedBox(height: RtcSpace.s4),
                      _botonGoogle(),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: RtcSpace.s7),
              RtcFormFadeIn(
                delay: const Duration(milliseconds: 200),
                child: _footerLinks(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// `rounded-xl border-red-200 bg-red-50 px-4 py-3`
  Widget _errorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: RtcSpace.s4,
        vertical: RtcSpace.s3,
      ),
      decoration: BoxDecoration(
        color: Red.c50,
        borderRadius: RtcRadius.brXl,
        border: Border.all(color: Red.c200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.circleAlert, size: 16, color: Red.c500),
          ),
          const SizedBox(width: 10), // gap-2.5
          Expanded(
            child: Text(message, style: RtcType.sm.copyWith(color: Red.c700)),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    String? error,
    bool obscure = false,
    Widget? trailing,
    Widget? action,
    TextInputType? keyboard,
    VoidCallback? onFocus,
    VoidCallback? onLeave,
    VoidCallback? onChanged,
  }) {
    final bad = error != null;
    final border = OutlineInputBorder(
      borderRadius: RtcRadius.brXl,
      borderSide: BorderSide(color: bad ? Red.c300 : Gray.c200),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: RtcType.xs.copyWith(
                fontWeight: FontWeight.w900,
                color: Gray.c700,
                letterSpacing: 1.4, // tracking-widest
              ),
            ),
            ?action,
          ],
        ),
        const SizedBox(height: 6), // space-y-1.5
        Focus(
          onFocusChange: (has) => has ? onFocus?.call() : onLeave?.call(),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboard,
            enabled: !_loading,
            style: RtcType.sm.copyWith(color: Gray.c900),
            onChanged: (_) => onChanged?.call(),
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: RtcType.sm.copyWith(color: Gray.c500),
              filled: true,
              // `border-red-300 bg-red-50/40` cuando el campo esta mal.
              fillColor: bad
                  ? Red.c50.withValues(alpha: 0.40)
                  : Superficie.tarjeta,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: RtcSpace.s4,
                vertical: RtcSpace.s3,
              ),
              suffixIcon: trailing == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(right: RtcSpace.s3),
                      child: trailing,
                    ),
              suffixIconConstraints: const BoxConstraints(minWidth: 0),
              border: border,
              enabledBorder: border,
              disabledBorder: border,
              // focus:ring-2, verde o rojo segun el estado.
              focusedBorder: OutlineInputBorder(
                borderRadius: RtcRadius.brXl,
                borderSide: BorderSide(
                  color: bad ? Red.c300 : Green.c400,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topLeft,
          child: error == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    error,
                    style: RtcType.xs.copyWith(color: Red.c500),
                  ),
                ),
        ),
      ],
    );
  }

  /// `bg-green-600 text-white font-black text-base py-4 rounded-2xl
  /// shadow-lg shadow-green-600/20`
  Widget _submitButton() {
    return RtcPressable(
      behavior: HitTestBehavior.opaque,
      onTap: _submit,
      child: Opacity(
        opacity: _loading ? 0.6 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: RtcSpace.s4),
          decoration: BoxDecoration(
            color: Green.c600,
            borderRadius: RtcRadius.brXxl,
            // `shadow-lg` de Tailwind, tenida de green-600 al 20%.
            boxShadow: [
              cssShadow(
                dy: 10,
                blur: 15,
                spread: -3,
                color: Green.c600.withValues(alpha: 0.20),
              ),
              cssShadow(
                dy: 4,
                blur: 6,
                spread: -4,
                color: Green.c600.withValues(alpha: 0.20),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_loading) ...[
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
                  'Ingresando...',
                  style: RtcType.base.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ] else ...[
                Text(
                  'Ingresar al dashboard',
                  style: RtcType.base.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(width: RtcSpace.s2),
                const Icon(
                  LucideIcons.chevronRight,
                  size: 20,
                  color: Colors.white,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// `pt-5 border-t border-gray-100`
  Widget _footerLinks() {
    return Container(
      padding: const EdgeInsets.only(top: RtcSpace.s5),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Gray.c100)),
      ),
      child: Column(
        children: [
          RtcPressable(
            behavior: HitTestBehavior.opaque,
            onTap: () => rtcNavigate('/solicitar-acceso'),
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: '¿Aún no tienes acceso? '),
                  TextSpan(
                    text: 'Solicitar acceso →',
                    style: RtcType.sm.copyWith(
                      color: Green.c600,
                      fontWeight: RtcType.bold,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              style: RtcType.sm.copyWith(color: Gray.c500),
            ),
          ),
          const SizedBox(height: RtcSpace.s2),
          RtcPressable(
            behavior: HitTestBehavior.opaque,
            onTap: () => rtcNavigate('/empresas'),
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: '¿Solo quieres reservar? '),
                  TextSpan(
                    text: 'Buscar canchas',
                    style: RtcType.xs.copyWith(
                      color: Gray.c500,
                      fontWeight: RtcType.semibold,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
              style: RtcType.xs.copyWith(color: Gray.c500),
            ),
          ),
        ],
      ),
    );
  }
}
